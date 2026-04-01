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
}

#include "include/core/SkImage.h"
#include "include/core/SkColorSpace.h"
#include "include/gpu/ganesh/GrDirectContext.h"
#include "include/gpu/ganesh/SkImageGanesh.h"

#include "frame_pool.h"
#include "demuxer.h"

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
    const AVCodec* codec = avcodec_find_decoder(stream->codecpar->codec_id);
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

    // Convert to BGRA (Skia's preferred format on most platforms)
    // For simplicity, we read NV12/YUV420P as-is and use Skia's
    // SkImages::RasterFromData with conversion. In production, use
    // libyuv or a shader for GPU-side YUV→RGB.
    int dstWidth = swFrame->width;
    int dstHeight = swFrame->height;
    size_t rowBytes = dstWidth * 4;
    auto pixels = std::make_unique<uint8_t[]>(rowBytes * dstHeight);

    // Manual NV12/YUV420P → BGRA conversion (simplified)
    if (swFrame->format == AV_PIX_FMT_YUV420P || swFrame->format == AV_PIX_FMT_NV12) {
        const uint8_t* yPlane = swFrame->data[0];
        const uint8_t* uPlane = swFrame->data[1];
        const uint8_t* vPlane = (swFrame->format == AV_PIX_FMT_NV12)
                                 ? nullptr : swFrame->data[2];
        int yStride = swFrame->linesize[0];
        int uStride = swFrame->linesize[1];
        int vStride = (swFrame->format == AV_PIX_FMT_NV12) ? 0 : swFrame->linesize[2];

        for (int row = 0; row < dstHeight; row++) {
            for (int col = 0; col < dstWidth; col++) {
                int y = yPlane[row * yStride + col];
                int u, v;
                if (swFrame->format == AV_PIX_FMT_NV12) {
                    int uvIdx = (row / 2) * uStride + (col / 2) * 2;
                    u = uPlane[uvIdx] - 128;
                    v = uPlane[uvIdx + 1] - 128;
                } else {
                    u = uPlane[(row / 2) * uStride + (col / 2)] - 128;
                    v = vPlane[(row / 2) * vStride + (col / 2)] - 128;
                }

                int r = y + (int)(1.402 * v);
                int g = y - (int)(0.344 * u) - (int)(0.714 * v);
                int b = y + (int)(1.772 * u);

                auto clamp = [](int val) -> uint8_t {
                    return val < 0 ? 0 : (val > 255 ? 255 : (uint8_t)val);
                };

                size_t pixIdx = (row * dstWidth + col) * 4;
                pixels[pixIdx + 0] = clamp(b); // B
                pixels[pixIdx + 1] = clamp(g); // G
                pixels[pixIdx + 2] = clamp(r); // R
                pixels[pixIdx + 3] = 255;      // A
            }
        }
    }

    SkImageInfo imageInfo = SkImageInfo::Make(
        dstWidth, dstHeight, kBGRA_8888_SkColorType, kPremul_SkAlphaType);

    sk_sp<SkData> data = SkData::MakeWithCopy(pixels.get(), rowBytes * dstHeight);
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

    // Setup HW acceleration if requested
    if (accel == TENNOJI_HW_ACCEL_AUTO && decoder->videoStreamIdx >= 0) {
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

    return decoder;
}

TENNOJI_EXPORT void rina_decoder_close(TennojiDecoder* decoder) {
    if (!decoder) return;

    decoder->flush_audio_queue();
    delete decoder->framePool;

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

    decoder->lastSeekTs = timestamp_us;
    return 0;
}

TENNOJI_EXPORT TennojiCanvasImage* rina_decoder_get_texture(TennojiDecoder* decoder,
                                                int64_t timestamp_us) {
    if (!decoder || !decoder->videoCodecCtx || !decoder->engine) return nullptr;

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
        }
    }
    
    decoder->lastSeekTs = timestamp_us;

    // Decode frames until we reach or pass the target PTS
    AVPacket* pkt = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();
    bool found = false;

    while (!found) {
        int ret = av_read_frame(decoder->fmtCtx, pkt);
        if (ret < 0) break; // EOF or error

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
            return new TennojiCanvasImage{.image = std::move(image)};
        }
    }

    av_frame_free(&frame);
    av_packet_free(&pkt);

    return nullptr;
}

TENNOJI_EXPORT int64_t rina_decoder_duration(TennojiDecoder* decoder) {
    if (!decoder || !decoder->fmtCtx) return 0;

    // Return duration in microseconds
    if (decoder->fmtCtx->duration != AV_NOPTS_VALUE) {
        return av_rescale_q(decoder->fmtCtx->duration,
                           AV_TIME_BASE_Q,
                           AVRational{1, 1000000});
    }

    // Try stream-level duration
    int idx = decoder->videoStreamIdx >= 0
                  ? decoder->videoStreamIdx
                  : decoder->audioStreamIdx;
    if (idx >= 0) {
        AVStream* stream = decoder->fmtCtx->streams[idx];
        if (stream->duration != AV_NOPTS_VALUE) {
            return av_rescale_q(stream->duration,
                               stream->time_base,
                               AVRational{1, 1000000});
        }
    }

    return 0;
}

TENNOJI_EXPORT int rina_decoder_read_audio(TennojiDecoder* decoder,
                                               int64_t timestamp_us) {
    if (!decoder || !decoder->fmtCtx || decoder->audioStreamIdx < 0) return -1;

    AVRational tb = decoder->fmtCtx->streams[decoder->audioStreamIdx]->time_base;
    int64_t target_pts = av_rescale_q(timestamp_us,
                                       AVRational{1, 1000000},
                                       tb);

    AVPacket* pkt = av_packet_alloc();
    while (true) {
        int ret = av_read_frame(decoder->fmtCtx, pkt);
        if (ret < 0) break; // EOF or error

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
}

TENNOJI_EXPORT int rina_decoder_read_audio_samples(TennojiDecoder* decoder,
                                                       int64_t timestamp_us,
                                                       float* samples_out,
                                                       int sample_count,
                                                       int sample_rate) {
    if (!decoder || !decoder->audioCodecCtx || decoder->audioStreamIdx < 0) return -1;
    if (!samples_out || sample_count <= 0) return -1;

    // Initialize output buffer to zero (silence) in case we don't decode enough samples
    int out_channels = 2;
    memset(samples_out, 0, sample_count * out_channels * sizeof(float));

    // For video files with audio: decode from packets that were already queued
    // by rina_decoder_get_texture (which stashes audio packets while seeking for video)
    // This prevents seeking conflicts between video and audio reading.

    AVFrame* frame = av_frame_alloc();
    
    // SwrContext for converting to stereo float32
    SwrContext* swr = nullptr;
    AVChannelLayout out_ch_layout = AV_CHANNEL_LAYOUT_STEREO;
    
    int samples_written = 0;

    // Decode from ONE queued audio packet only (not the whole queue)
    // This prevents cramming all audio into the first frame
    AVPacket* pkt = nullptr;
    
    // Try to get a packet from the queue
    {
        std::lock_guard<std::mutex> lock(decoder->audioQueueMutex);
        if (!decoder->audioPacketQueue.empty()) {
            pkt = decoder->audioPacketQueue.front();
            decoder->audioPacketQueue.pop_front();
        }
    }
    
    if (pkt) {
        // Decode the packet
        int ret = avcodec_send_packet(decoder->audioCodecCtx, pkt);
        av_packet_free(&pkt);
        
        if (ret >= 0) {
            while (avcodec_receive_frame(decoder->audioCodecCtx, frame) == 0) {
                // Initialize resampler if needed
                if (!swr) {
                    ret = swr_alloc_set_opts2(&swr,
                        &out_ch_layout, AV_SAMPLE_FMT_FLT, sample_rate,
                        &frame->ch_layout, (AVSampleFormat)frame->format, frame->sample_rate,
                        0, nullptr);
                    if (ret < 0 || !swr) {
                        av_frame_unref(frame);
                        goto cleanup;
                    }
                    swr_init(swr);
                }

                // Convert samples to stereo float32
                uint8_t* out_buf[1] = { reinterpret_cast<uint8_t*>(samples_out + samples_written * out_channels) };
                int remaining = sample_count - samples_written;
                int converted = swr_convert(swr, out_buf, remaining,
                                            (const uint8_t**)frame->data, frame->nb_samples);
                
                if (converted > 0) {
                    samples_written += converted;
                }

                av_frame_unref(frame);

                if (samples_written >= sample_count) break;
            }
        }
    }

cleanup:
    if (swr) swr_free(&swr);
    av_frame_free(&frame);

    return samples_written;
}

} // extern "C"
