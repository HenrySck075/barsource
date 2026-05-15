#include "../engine_internal.h"
#include "../dart_ui/image_internal.h"
#include "decoder_internal.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/hwcontext.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <libavutil/pixdesc.h>
#include <libavutil/time.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
}

#include "include/core/SkImage.h"
#include "include/core/SkColorSpace.h"
#include "include/gpu/ganesh/GrDirectContext.h"
#include "include/gpu/ganesh/SkImageGanesh.h"

#include "frame_pool.h"
#include "demuxer.h"
#include <cstring>
#include <cstdlib>
#include <cerrno>

// HW pixel format callback for hw-accel decoding
static enum AVPixelFormat get_hw_format(AVCodecContext* ctx,
                                         const enum AVPixelFormat* pix_fmts) {
    auto* decoder = static_cast<TennojiDecoder*>(ctx->opaque);
    for (const auto* p = pix_fmts; *p != AV_PIX_FMT_NONE; p++) {
        if (*p == decoder->hwPixFmt) return *p;
    }
    // Fallback to software format
    return pix_fmts[0];
}

static AVCodecContext* open_codec(AVFormatContext* fmtCtx, int streamIdx,
                                   AVBufferRef* hwDeviceCtx,
                                   enum AVPixelFormat hwPixFmt,
                                   TennojiDecoder* decoder) {
    AVStream* stream = fmtCtx->streams[streamIdx];
    const AVCodec* codec = nullptr;
    
    // For H.264 video, prefer hardware decoder if available
    if (stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO && 
        stream->codecpar->codec_id == AV_CODEC_ID_H264 && hwDeviceCtx) {
#if defined(__linux__) && !defined(__ANDROID__)
        codec = avcodec_find_decoder_by_name("h264_vaapi");
#elif defined(__APPLE__)
        codec = avcodec_find_decoder_by_name("h264_videotoolbox");
#elif defined(_WIN32)
        codec = avcodec_find_decoder_by_name("h264_d3d11va");
#endif
    }
    
    // Fallback to standard decoder
    if (!codec) {
        codec = avcodec_find_decoder(stream->codecpar->codec_id);
    }
    if (!codec) return nullptr;

    AVCodecContext* codecCtx = avcodec_alloc_context3(codec);
    if (!codecCtx) return nullptr;

    int ret = avcodec_parameters_to_context(codecCtx, stream->codecpar);
    if (ret < 0) {
        avcodec_free_context(&codecCtx);
        return nullptr;
    }

    codecCtx->pkt_timebase = stream->time_base;

    // Attach hw device context for video decoding if available
    if (hwDeviceCtx && stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
        codecCtx->hw_device_ctx = av_buffer_ref(hwDeviceCtx);
        codecCtx->opaque = decoder;
        codecCtx->get_format = get_hw_format;
    }

    ret = avcodec_open2(codecCtx, codec, nullptr);
    if (ret < 0) {
        avcodec_free_context(&codecCtx);
        return nullptr;
    }

    return codecCtx;
}

static int64_t resolve_media_duration_us(
    AVFormatContext* fmtCtx,
    int videoStreamIdx,
    int audioStreamIdx) {
    if (!fmtCtx) return 0;

    if (fmtCtx->duration != AV_NOPTS_VALUE) {
        return av_rescale_q(fmtCtx->duration,
                           AV_TIME_BASE_Q,
                           AVRational{1, 1000000});
    }

    const int idx = videoStreamIdx >= 0 ? videoStreamIdx : audioStreamIdx;
    if (idx >= 0) {
        AVStream* stream = fmtCtx->streams[idx];
        if (stream->duration != AV_NOPTS_VALUE) {
            return av_rescale_q(stream->duration,
                               stream->time_base,
                               AVRational{1, 1000000});
        }
    }

    return 0;
}

// Map a decoded AVFrame to an SkImage for zero-copy GPU pipeline
static sk_sp<SkImage> avframe_to_skimage(TennojiDecoder* decoder, AVFrame* frame) {
    if (!decoder || !frame || !decoder->engine) return nullptr;

    GrDirectContext* grContext = decoder->engine->grContext;
    int width = frame->width;
    int height = frame->height;

    // If we have a GPU-backed frame (HW decode), attempt zero-copy texture import
    if (frame->format != AV_PIX_FMT_NONE && grContext) {
        // TODO: Platform-specific zero-copy texture import
        // For CUDA/VAAPI/VideoToolbox frames, wrap the GPU memory directly
        // as a GrBackendTexture and call SkImages::BorrowTextureFrom()
    }

    // CPU fallback: convert frame to RGBA and create raster SkImage
    AVFrame* swFrame = frame;
    AVFrame* tmpFrame = nullptr;

    // If HW frame, transfer to CPU
    if (frame->hw_frames_ctx) {
        tmpFrame = av_frame_alloc();
        if (av_hwframe_transfer_data(tmpFrame, frame, 0) < 0) {
            av_frame_free(&tmpFrame);
            return nullptr;
        }
        swFrame = tmpFrame;
    }

    const int dstWidth = swFrame->width;
    const int dstHeight = swFrame->height;
    const size_t rowBytes = static_cast<size_t>(dstWidth) * 4;
    const size_t frameBytes = rowBytes * static_cast<size_t>(dstHeight);
    uint8_t* rgbaData = static_cast<uint8_t*>(malloc(frameBytes));
    if (!rgbaData) {
        if (tmpFrame) av_frame_free(&tmpFrame);
        return nullptr;
    }

    const AVPixelFormat srcFmt = static_cast<AVPixelFormat>(swFrame->format);
    if (srcFmt == AV_PIX_FMT_BGRA && swFrame->linesize[0] == static_cast<int>(rowBytes)) {
        memcpy(rgbaData, swFrame->data[0], frameBytes);
    } else {
        decoder->videoSwsCtx = sws_getCachedContext(
            decoder->videoSwsCtx,
            swFrame->width, swFrame->height, srcFmt,
            dstWidth, dstHeight, AV_PIX_FMT_BGRA,
            SWS_FAST_BILINEAR, nullptr, nullptr, nullptr);
        if (!decoder->videoSwsCtx) {
            free(rgbaData);
            if (tmpFrame) av_frame_free(&tmpFrame);
            return nullptr;
        }

        uint8_t* dstData[4] = { rgbaData, nullptr, nullptr, nullptr };
        int dstLinesize[4] = { static_cast<int>(rowBytes), 0, 0, 0 };
        if (sws_scale(decoder->videoSwsCtx,
                      swFrame->data,
                      swFrame->linesize,
                      0,
                      swFrame->height,
                      dstData,
                      dstLinesize) <= 0) {
            free(rgbaData);
            if (tmpFrame) av_frame_free(&tmpFrame);
            return nullptr;
        }
    }

    SkImageInfo imageInfo = SkImageInfo::Make(
        dstWidth, dstHeight, kBGRA_8888_SkColorType, kPremul_SkAlphaType);

    sk_sp<SkData> data = SkData::MakeWithProc(
        rgbaData,
        frameBytes,
        [](const void* ptr, void*) {
            free(const_cast<void*>(ptr));
        },
        nullptr);
    if (!data) {
        free(rgbaData);
        if (tmpFrame) av_frame_free(&tmpFrame);
        return nullptr;
    }
    sk_sp<SkImage> image = SkImages::RasterFromData(imageInfo, data, rowBytes);

    // Upload to GPU if context available
    if (grContext && image) {
        image = SkImages::TextureFromImage(grContext, image.get());
    }

    if (tmpFrame) av_frame_free(&tmpFrame);

    return image;
}

extern "C" {

TENNOJI_EXPORT TennojiDecoder* rina_decoder_open(TennojiEngine* engine,
                                                     const char* uri,
                                                     TennojiHWAccel accel) {
    if (!engine || !uri) return nullptr;

    auto* decoder = new TennojiDecoder();
    decoder->engine = engine;

    // Open input via demuxer
    int ret = avformat_open_input(&decoder->fmtCtx, uri, nullptr, nullptr);
    if (ret < 0) {
        delete decoder;
        return nullptr;
    }

    ret = avformat_find_stream_info(decoder->fmtCtx, nullptr);
    if (ret < 0) {
        avformat_close_input(&decoder->fmtCtx);
        delete decoder;
        return nullptr;
    }

    // Find video and audio streams
    decoder->videoStreamIdx = av_find_best_stream(
        decoder->fmtCtx, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    decoder->audioStreamIdx = av_find_best_stream(
        decoder->fmtCtx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);

    // Setup HW acceleration if requested - only for H.264
    if (accel == TENNOJI_HW_ACCEL_AUTO && decoder->videoStreamIdx >= 0) {
        AVStream* videoStream = decoder->fmtCtx->streams[decoder->videoStreamIdx];
        
        // Lock GPU decoding to H.264 only
        if (videoStream->codecpar->codec_id == AV_CODEC_ID_H264) {
            enum AVHWDeviceType hwType = AV_HWDEVICE_TYPE_NONE;
#if defined(__linux__) && !defined(__ANDROID__)
            hwType = AV_HWDEVICE_TYPE_VAAPI;
            decoder->hwPixFmt = AV_PIX_FMT_VAAPI;
#elif defined(__APPLE__)
            hwType = AV_HWDEVICE_TYPE_VIDEOTOOLBOX;
            decoder->hwPixFmt = AV_PIX_FMT_VIDEOTOOLBOX;
#elif defined(_WIN32)
            hwType = AV_HWDEVICE_TYPE_D3D11VA;
            decoder->hwPixFmt = AV_PIX_FMT_D3D11;
#endif
            if (hwType != AV_HWDEVICE_TYPE_NONE) {
                ret = av_hwdevice_ctx_create(&decoder->hwDeviceCtx, hwType, nullptr, nullptr, 0);
                if (ret < 0) {
                    decoder->hwDeviceCtx = nullptr; // Fall back to SW
                }
            }
        }
    }

    // Open video codec
    if (decoder->videoStreamIdx >= 0) {
        decoder->videoCodecCtx = open_codec(
            decoder->fmtCtx, decoder->videoStreamIdx,
            decoder->hwDeviceCtx, decoder->hwPixFmt, decoder);
        if (!decoder->videoCodecCtx) {
            // Try without HW accel
            decoder->videoCodecCtx = open_codec(
                decoder->fmtCtx, decoder->videoStreamIdx,
                nullptr, AV_PIX_FMT_NONE, decoder);
        }
    }

    // Open audio codec (always software)
    if (decoder->audioStreamIdx >= 0) {
        decoder->audioCodecCtx = open_codec(
            decoder->fmtCtx, decoder->audioStreamIdx,
            nullptr, AV_PIX_FMT_NONE, decoder);
    }

    // Create frame pool for decoded video frames
    decoder->framePool = new tennoji::FramePool(8);
    decoder->decodePacket = av_packet_alloc();
    decoder->decodeFrame = av_frame_alloc();
    decoder->audioDecodeFrame = av_frame_alloc();
    if (!decoder->decodePacket || !decoder->decodeFrame || !decoder->audioDecodeFrame) {
        if (decoder->decodePacket) av_packet_free(&decoder->decodePacket);
        if (decoder->decodeFrame) av_frame_free(&decoder->decodeFrame);
        if (decoder->audioDecodeFrame) av_frame_free(&decoder->audioDecodeFrame);
        delete decoder->framePool;
        if (decoder->videoCodecCtx) avcodec_free_context(&decoder->videoCodecCtx);
        if (decoder->audioCodecCtx) avcodec_free_context(&decoder->audioCodecCtx);
        if (decoder->hwDeviceCtx) av_buffer_unref(&decoder->hwDeviceCtx);
        if (decoder->fmtCtx) avformat_close_input(&decoder->fmtCtx);
        delete decoder;
        return nullptr;
    }

    return decoder;
}

TENNOJI_EXPORT void rina_decoder_close(TennojiDecoder* decoder) {
    if (!decoder) return;

    decoder->flush_audio_queue();
    decoder->flush_video_queue();
    delete decoder->framePool;
    av_packet_free(&decoder->decodePacket);
    av_frame_free(&decoder->decodeFrame);
    av_frame_free(&decoder->audioDecodeFrame);
    delete decoder->cachedTexture;
    if (decoder->audioFifo) av_audio_fifo_free(decoder->audioFifo);
    if (decoder->swrCtx) swr_free(&decoder->swrCtx);
    if (decoder->videoSwsCtx) sws_freeContext(decoder->videoSwsCtx);

    if (decoder->videoCodecCtx) avcodec_free_context(&decoder->videoCodecCtx);
    if (decoder->audioCodecCtx) avcodec_free_context(&decoder->audioCodecCtx);
    if (decoder->hwDeviceCtx) av_buffer_unref(&decoder->hwDeviceCtx);
    if (decoder->fmtCtx) avformat_close_input(&decoder->fmtCtx);

    delete decoder;
}

TENNOJI_EXPORT int rina_decoder_seek(TennojiDecoder* decoder, int64_t timestamp_us) {
    if (!decoder || !decoder->fmtCtx) return -1;

    // Convert microseconds to stream timebase
    int streamIdx = decoder->videoStreamIdx >= 0
                        ? decoder->videoStreamIdx
                        : decoder->audioStreamIdx;
    if (streamIdx < 0) return -1;

    AVRational tb = decoder->fmtCtx->streams[streamIdx]->time_base;
    int64_t pts = av_rescale_q(timestamp_us,
                               AVRational{1, 1000000},
                               tb);

    int ret = av_seek_frame(decoder->fmtCtx, streamIdx, pts,
                            AVSEEK_FLAG_BACKWARD);
    if (ret < 0) return ret;

    // Flush codec buffers after seeking
    if (decoder->videoCodecCtx) avcodec_flush_buffers(decoder->videoCodecCtx);
    if (decoder->audioCodecCtx) avcodec_flush_buffers(decoder->audioCodecCtx);

    // Flush frame pool
    if (decoder->framePool) decoder->framePool->flush();

    // Flush buffered audio packets (they're from before the seek point)
    decoder->flush_audio_queue();
    decoder->flush_video_queue();
    if (decoder->audioFifo) av_audio_fifo_reset(decoder->audioFifo);
    if (decoder->swrCtx) {
        swr_free(&decoder->swrCtx);
        decoder->swrOutSampleRate = 0;
    }

    decoder->lastSeekTs = timestamp_us;
    decoder->lastAudioReadTs = timestamp_us;
    return 0;
}

TENNOJI_EXPORT TennojiCanvasImage* rina_decoder_get_texture(TennojiDecoder* decoder,
                                                int64_t timestamp_us) {
    if (!decoder || !decoder->videoCodecCtx || !decoder->engine) return nullptr;
    if (decoder->cachedTexture && decoder->cachedTextureTsUs == timestamp_us) {
        return decoder->cachedTexture;
    }

    AVRational tb = decoder->fmtCtx->streams[decoder->videoStreamIdx]->time_base;
    int64_t target_pts = av_rescale_q(timestamp_us,
                                       AVRational{1, 1000000},
                                       tb);
    
    // Check if we need to seek backwards or to the same position
    // NOTE: Assuming H.264 codec - for other codecs, GOP structure may differ
    if (decoder->lastSeekTs > timestamp_us || decoder->lastSeekTs == timestamp_us) {
        // Seek back to the nearest keyframe before target timestamp
        int ret = av_seek_frame(decoder->fmtCtx, decoder->videoStreamIdx, target_pts,
                                AVSEEK_FLAG_BACKWARD);
        if (ret >= 0) {
            if (decoder->videoCodecCtx) avcodec_flush_buffers(decoder->videoCodecCtx);
            if (decoder->audioCodecCtx) avcodec_flush_buffers(decoder->audioCodecCtx);
            if (decoder->framePool) decoder->framePool->flush();
            decoder->flush_audio_queue();
            decoder->flush_video_queue();
        }
    }
    
    decoder->lastSeekTs = timestamp_us;

    // Decode frames until we reach or pass the target PTS
    AVPacket* pkt = decoder->decodePacket;
    AVFrame* frame = decoder->decodeFrame;
    if (!pkt || !frame) return nullptr;
    av_packet_unref(pkt);
    av_frame_unref(frame);
    bool found = false;

    while (!found) {
        int ret = 0;
        bool fromVideoQueue = false;
        {
            std::lock_guard<std::mutex> lock(decoder->videoQueueMutex);
            if (!decoder->videoPacketQueue.empty()) {
                AVPacket* queuedPkt = decoder->videoPacketQueue.front();
                decoder->videoPacketQueue.pop_front();
                av_packet_move_ref(pkt, queuedPkt);
                av_packet_free(&queuedPkt);
                fromVideoQueue = true;
            }
        }
        if (!fromVideoQueue) {
            ret = av_read_frame(decoder->fmtCtx, pkt);
            if (ret < 0) break; // EOF or error
        }

        if (pkt->stream_index == decoder->audioStreamIdx) {
            // Stash audio packets for later draining by the encoder
            decoder->enqueue_audio_packet(pkt);
            av_packet_unref(pkt);
            continue;
        }

        if (pkt->stream_index != decoder->videoStreamIdx) {
            av_packet_unref(pkt);
            continue;
        }

        ret = avcodec_send_packet(decoder->videoCodecCtx, pkt);
        av_packet_unref(pkt);
        if (ret < 0) break;

        while (true) {
            ret = avcodec_receive_frame(decoder->videoCodecCtx, frame);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
            if (ret < 0) { found = true; break; }

            decoder->framePool->push(frame);

            if (frame->pts >= target_pts) {
                found = true;
                break;
            }
            av_frame_unref(frame);
        }
    }

    // Get the best matching frame from pool
    AVFrame* bestFrame = decoder->framePool->get_frame(target_pts);

    if (bestFrame) {
        sk_sp<SkImage> image = avframe_to_skimage(decoder, bestFrame);
        if (image) {
            if (!decoder->cachedTexture) {
                decoder->cachedTexture = new TennojiCanvasImage{
                    .image = std::move(image),
                    .managedByDecoder = true,
                };
            } else {
                decoder->cachedTexture->image = std::move(image);
            }
            decoder->cachedTextureTsUs = timestamp_us;
            return decoder->cachedTexture;
        }
    }

    return nullptr;
}

TENNOJI_EXPORT int64_t rina_decoder_duration(TennojiDecoder* decoder) {
    if (!decoder || !decoder->fmtCtx) return 0;
    return resolve_media_duration_us(
        decoder->fmtCtx,
        decoder->videoStreamIdx,
        decoder->audioStreamIdx);
}

TENNOJI_EXPORT int64_t rina_media_source_duration(
    TennojiEngine* engine,
    const char* uri) {
    (void)engine;
    if (!uri) return 0;

    AVFormatContext* fmtCtx = nullptr;
    int ret = avformat_open_input(&fmtCtx, uri, nullptr, nullptr);
    if (ret < 0 || !fmtCtx) {
        if (fmtCtx) {
            avformat_close_input(&fmtCtx);
        }
        return 0;
    }

    ret = avformat_find_stream_info(fmtCtx, nullptr);
    if (ret < 0) {
        avformat_close_input(&fmtCtx);
        return 0;
    }

    const int videoStreamIdx = av_find_best_stream(
        fmtCtx, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    const int audioStreamIdx = av_find_best_stream(
        fmtCtx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);

    const int64_t durationUs = resolve_media_duration_us(
        fmtCtx, videoStreamIdx, audioStreamIdx);
    avformat_close_input(&fmtCtx);
    return durationUs;
}

TENNOJI_EXPORT int rina_decoder_read_audio(TennojiDecoder* decoder,
                                               int64_t timestamp_us) {
#if !TENNOJI_ENABLE_LEGACY_AUDIO_API
    (void)decoder;
    (void)timestamp_us;
    return AVERROR(ENOSYS);
#else
    if (!decoder || !decoder->fmtCtx || decoder->audioStreamIdx < 0) return -1;

    AVRational tb = decoder->fmtCtx->streams[decoder->audioStreamIdx]->time_base;
    int64_t target_pts = av_rescale_q(timestamp_us,
                                       AVRational{1, 1000000},
                                       tb);

    AVPacket* pkt = av_packet_alloc();
    while (true) {
        int ret = av_read_frame(decoder->fmtCtx, pkt);
        if (ret < 0) break; // EOF or error

        if (pkt->stream_index == decoder->videoStreamIdx) {
            decoder->enqueue_video_packet(pkt);
            av_packet_unref(pkt);
            continue;
        }

        if (pkt->stream_index != decoder->audioStreamIdx) {
            av_packet_unref(pkt);
            continue;
        }

        decoder->enqueue_audio_packet(pkt);

        // Stop once we've read past the target timestamp
        if (pkt->pts != AV_NOPTS_VALUE && pkt->pts >= target_pts) {
            av_packet_unref(pkt);
            break;
        }

        av_packet_unref(pkt);
    }

    av_packet_free(&pkt);
    return 0;
#endif
}

TENNOJI_EXPORT int rina_decoder_read_audio_samples(TennojiDecoder* decoder,
                                                    int64_t timestamp_us,
                                                    float* samples_out,
                                                    int sample_count,
                                                    int sample_rate) {
    if (!decoder || !decoder->audioCodecCtx) return -1;

    // Audio reads are typically sequential; if timeline moves backwards
    // (e.g. loop/repeat), seek and clear buffered state first.
    if (decoder->lastAudioReadTs != INT64_MIN &&
        timestamp_us < decoder->lastAudioReadTs) {
        const int seek_ret = rina_decoder_seek(decoder, timestamp_us);
        if (seek_ret < 0) return seek_ret;
    } else {
        decoder->lastAudioReadTs = timestamp_us;
    }

    int out_channels = 2;
    // Initialize FIFO if it doesn't exist
    if (!decoder->audioFifo) {
        decoder->audioFifo = av_audio_fifo_alloc(AV_SAMPLE_FMT_FLT, out_channels, sample_rate);
        if (!decoder->audioFifo) return -1;
    }

    AVFrame* frame = decoder->audioDecodeFrame;
    if (!frame) return AVERROR(ENOMEM);
    av_frame_unref(frame);
    
    // 1. Keep decoding packets until we have enough samples in the FIFO
    while (av_audio_fifo_size(decoder->audioFifo) < sample_count) {
        AVPacket* pkt = nullptr;
        {
            std::lock_guard<std::mutex> lock(decoder->audioQueueMutex);
            if (!decoder->audioPacketQueue.empty()) {
                pkt = decoder->audioPacketQueue.front();
                decoder->audioPacketQueue.pop_front();
            }
        }
        
        // If queue is empty, read directly from file
        if (!pkt) {
            pkt = av_packet_alloc();
            int ret = av_read_frame(decoder->fmtCtx, pkt);
            if (ret < 0) {
                av_packet_free(&pkt);
                break; // EOF or error
            }
            
            // Skip non-audio packets
            if (pkt->stream_index != decoder->audioStreamIdx) {
                if (pkt->stream_index == decoder->videoStreamIdx) {
                    decoder->enqueue_video_packet(pkt);
                }
                av_packet_unref(pkt);
                av_packet_free(&pkt);
                continue;
            }
        }

        if (pkt && avcodec_send_packet(decoder->audioCodecCtx, pkt) >= 0) {
            while (avcodec_receive_frame(decoder->audioCodecCtx, frame) == 0) {
                // Initialize/Update Resampler
                if (!decoder->swrCtx || decoder->swrOutSampleRate != sample_rate) {
                    if (decoder->swrCtx) swr_free(&decoder->swrCtx);
                    AVChannelLayout out_ch_layout = AV_CHANNEL_LAYOUT_STEREO;
                    swr_alloc_set_opts2(&decoder->swrCtx,
                        &out_ch_layout, AV_SAMPLE_FMT_FLT, sample_rate,
                        &frame->ch_layout, (AVSampleFormat)frame->format, frame->sample_rate,
                        0, nullptr);
                    if (!decoder->swrCtx || swr_init(decoder->swrCtx) < 0) {
                        av_frame_unref(frame);
                        return -1;
                    }
                    decoder->swrOutSampleRate = sample_rate;
                }

                const int out_samples = av_rescale_rnd(
                    swr_get_delay(decoder->swrCtx, frame->sample_rate) + frame->nb_samples,
                    sample_rate,
                    frame->sample_rate,
                    AV_ROUND_UP);
                if (out_samples <= 0) {
                    av_frame_unref(frame);
                    continue;
                }

                decoder->audioScratch.resize(static_cast<size_t>(out_samples) * out_channels);
                uint8_t* out_data[1] = {
                    reinterpret_cast<uint8_t*>(decoder->audioScratch.data())
                };
                int converted = swr_convert(decoder->swrCtx,
                                            out_data,
                                            out_samples,
                                            (const uint8_t**)frame->extended_data,
                                            frame->nb_samples);
                
                // Push converted samples into FIFO
                if (converted > 0) {
                    const int available_space = av_audio_fifo_space(decoder->audioFifo);
                    if (available_space < converted) {
                        const int current_size = av_audio_fifo_size(decoder->audioFifo);
                        int new_capacity = current_size + converted;
                        const int reserve = sample_count * 2;
                        if (new_capacity < current_size + reserve) {
                            new_capacity = current_size + reserve;
                        }
                        if (av_audio_fifo_realloc(decoder->audioFifo, new_capacity) < 0) {
                            av_frame_unref(frame);
                            return -1;
                        }
                    }
                    void* fifo_data[1] = { decoder->audioScratch.data() };
                    const int written = av_audio_fifo_write(decoder->audioFifo, fifo_data, converted);
                    if (written < converted) {
                        av_frame_unref(frame);
                        return -1;
                    }
                }
                av_frame_unref(frame);
            }
        }
        if (pkt) {
            av_packet_free(&pkt);
        }
    }

    // 2. Pull the exact requested amount from FIFO
    int available = av_audio_fifo_size(decoder->audioFifo);
    int to_read = std::min(available, sample_count);
    
    if (to_read > 0) {
        av_audio_fifo_read(decoder->audioFifo, (void**)&samples_out, to_read);
    }

    av_frame_unref(frame);
    return to_read; // Return actual samples written to avoid "glitches"
}


} // extern "C"
