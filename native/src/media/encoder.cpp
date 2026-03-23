#include "../engine_internal.h"
#include <thread>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <vector>

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/hwcontext.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <libavutil/pixdesc.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
#include <libavutil/hwcontext_drm.h>
}

#if defined(__linux__) && !defined(__ANDROID__)
#include <libdrm/drm_fourcc.h>
#endif

#ifndef DRM_FORMAT_ARGB8888
#define DRM_FORMAT_ARGB8888 0x34325241
#endif

#include "include/core/SkSurface.h"
#include "include/core/SkImage.h"
#include "include/core/SkPicture.h"
#include "include/gpu/ganesh/GrDirectContext.h"

#include "../renderer/canvas_internal.h"
#include "../renderer/skia_surface.h"
#include "decoder_internal.h"
#include "muxer.h"
#include "audio_mixer.h"

struct RenderFrame {
    sk_sp<SkPicture> picture;
    int64_t pts;
};

struct EncodeFrame {
    std::vector<uint8_t> pixels;
    tennoji::ExportableSurface surface;
    int64_t pts;
};

struct TennojiEncoder {
    AVFormatContext* fmtCtx = nullptr;
    AVCodecContext* videoCodecCtx = nullptr;
    AVCodecContext* audioCodecCtx = nullptr;
    AVStream* videoStream = nullptr;
    AVStream* audioStream = nullptr;
    AVBufferRef* hwDeviceCtx = nullptr;
    AVBufferRef* hwFramesCtx = nullptr;
    SwsContext* swsCtx = nullptr;
    TennojiEngine* engine = nullptr;
    tennoji::AudioMixer* audioMixer = nullptr;
    int64_t videoPts = 0;
    int64_t audioPts = 0;
    int32_t width = 0;
    int32_t height = 0;
    int32_t fps = 0;

    // Pipeline
    std::thread renderThread;
    std::thread encodeThread;
    
    std::mutex renderMutex;
    std::condition_variable renderCv;
    std::queue<RenderFrame> renderQueue;

    std::mutex encodeMutex;
    std::condition_variable encodeCv;
    std::queue<EncodeFrame> encodeQueue;

    // Surface Pool
    std::vector<tennoji::ExportableSurface> allSurfaces;
    std::queue<tennoji::ExportableSurface> freeSurfaces;
    std::mutex poolMutex;

    std::atomic<bool> running{true};
    std::atomic<bool> renderFinished{false};
};

static void render_loop(TennojiEncoder* enc) {
    while (true) {
        RenderFrame frame;
        {
            std::unique_lock<std::mutex> lock(enc->renderMutex);
            enc->renderCv.wait(lock, [&] { return !enc->renderQueue.empty() || !enc->running; });
            if (enc->renderQueue.empty() && !enc->running) break;
            frame = std::move(enc->renderQueue.front());
            enc->renderQueue.pop();
        }

        tennoji::ExportableSurface exSurface;
        {
            std::lock_guard<std::mutex> lock(enc->poolMutex);
            if (!enc->freeSurfaces.empty()) {
                exSurface = enc->freeSurfaces.front();
                enc->freeSurfaces.pop();
            }
        }

        if (!exSurface.isValid()) {
            if (enc->hwFramesCtx) {
                exSurface = tennoji::create_exportable_gpu_surface(enc->engine->gpuCtx, enc->width, enc->height);
            }
            if (!exSurface.isValid()) {
                exSurface.skSurface = tennoji::create_gpu_surface(enc->engine->grContext, enc->width, enc->height);
                exSurface.fd = -1;
            }
            if (exSurface.skSurface) {
                std::lock_guard<std::mutex> lock(enc->poolMutex);
                enc->allSurfaces.push_back(exSurface);
            }
        }

        if (exSurface.skSurface) {
             exSurface.skSurface->getCanvas()->clear(SK_ColorTRANSPARENT);
             exSurface.skSurface->getCanvas()->drawPicture(frame.picture);
             
             if (auto* grCtx = exSurface.skSurface->recordingContext()) {
                 static_cast<GrDirectContext*>(grCtx)->flushAndSubmit();
             }

             if (exSurface.fd != -1) {
                 // Zero copy path
                 {
                     std::lock_guard<std::mutex> lock(enc->encodeMutex);
                     enc->encodeQueue.push({std::vector<uint8_t>(), exSurface, frame.pts});
                 }
                 enc->encodeCv.notify_one();
             } else {
                 // Read pixels (GPU -> CPU copy)
                 SkImageInfo readInfo = SkImageInfo::Make(
                    enc->width, enc->height,
                    kBGRA_8888_SkColorType, kPremul_SkAlphaType);

                 std::vector<uint8_t> pixels(enc->width * enc->height * 4);
                 if (exSurface.skSurface->readPixels(readInfo, pixels.data(), enc->width * 4, 0, 0)) {
                     {
                         std::lock_guard<std::mutex> lock(enc->encodeMutex);
                         enc->encodeQueue.push({std::move(pixels), exSurface, frame.pts});
                     }
                     enc->encodeCv.notify_one();
                 } else {
                     // Readback failed, return surface
                     std::lock_guard<std::mutex> lock(enc->poolMutex);
                     enc->freeSurfaces.push(exSurface);
                 }
             }
        }
    }
    
    enc->renderFinished = true;
    enc->encodeCv.notify_one();
}

static void encode_loop(TennojiEncoder* encoder) {
    while (true) {
        EncodeFrame frameData;
        {
            std::unique_lock<std::mutex> lock(encoder->encodeMutex);
            encoder->encodeCv.wait(lock, [&] { 
                return !encoder->encodeQueue.empty() || (encoder->renderFinished && !encoder->running); 
            });
            
            if (encoder->encodeQueue.empty() && encoder->renderFinished && !encoder->running) break;
            if (encoder->encodeQueue.empty()) continue;

            frameData = std::move(encoder->encodeQueue.front());
            encoder->encodeQueue.pop();
        }

        AVFrame* encode_frame = nullptr;
        AVFrame* sw_frame = nullptr;
        AVFrame* hw_frame = nullptr;

        if (frameData.surface.isValid() && frameData.surface.fd != -1 && frameData.pixels.empty()) {
            // Zero-copy path
            sw_frame = av_frame_alloc();
            sw_frame->format = AV_PIX_FMT_DRM_PRIME;
            sw_frame->width = encoder->width;
            sw_frame->height = encoder->height;
            sw_frame->pts = frameData.pts;

            AVDRMFrameDescriptor* desc = (AVDRMFrameDescriptor*)av_mallocz(sizeof(AVDRMFrameDescriptor));
            desc->nb_objects = 1;
            desc->objects[0].fd = frameData.surface.fd;
            desc->objects[0].size = encoder->width * encoder->height * 4; // Approx for B8G8R8A8
            desc->objects[0].format_modifier = DRM_FORMAT_MOD_INVALID;

            desc->nb_layers = 1;
            desc->layers[0].format = DRM_FORMAT_ARGB8888;
            desc->layers[0].nb_planes = 1;
            desc->layers[0].planes[0].object_index = 0;
            desc->layers[0].planes[0].offset = 0;
            desc->layers[0].planes[0].pitch = encoder->width * 4;

            sw_frame->buf[0] = av_buffer_create((uint8_t*)desc, sizeof(AVDRMFrameDescriptor),
                                                av_buffer_default_free, nullptr, 0);
            sw_frame->data[0] = (uint8_t*)desc;

            // Import to HW frame
            hw_frame = av_frame_alloc();
            if (av_hwframe_get_buffer(encoder->hwFramesCtx, hw_frame, 0) < 0) {
                av_frame_free(&sw_frame);
                av_frame_free(&hw_frame);
                // Should return surface to pool!
                {
                    std::lock_guard<std::mutex> lock(encoder->poolMutex);
                    encoder->freeSurfaces.push(frameData.surface);
                }
                continue;
            }
            hw_frame->pts = sw_frame->pts;

            if (av_hwframe_transfer_data(hw_frame, sw_frame, 0) < 0) {
                av_frame_free(&sw_frame);
                av_frame_free(&hw_frame);
                 {
                    std::lock_guard<std::mutex> lock(encoder->poolMutex);
                    encoder->freeSurfaces.push(frameData.surface);
                }
                continue;
            }
            encode_frame = hw_frame;
        } else {
            // SW Path
            sw_frame = av_frame_alloc();
            sw_frame->format = encoder->hwFramesCtx ? AV_PIX_FMT_NV12 : encoder->videoCodecCtx->pix_fmt;
            sw_frame->width = encoder->width;
            sw_frame->height = encoder->height;
            sw_frame->pts = frameData.pts;
            
            if (av_frame_get_buffer(sw_frame, 32) < 0) {
                av_frame_free(&sw_frame);
                if (frameData.surface.isValid()) {
                    std::lock_guard<std::mutex> lock(encoder->poolMutex);
                    encoder->freeSurfaces.push(frameData.surface);
                }
                continue;
            }

            const uint8_t* srcSlice[] = { frameData.pixels.data() };
            const int srcStride[] = { encoder->width * 4 };
            
            sws_scale(encoder->swsCtx, srcSlice, srcStride, 0, encoder->height,
                      sw_frame->data, sw_frame->linesize);

            encode_frame = sw_frame;

            if (encoder->hwFramesCtx) {
                hw_frame = av_frame_alloc();
                if (av_hwframe_get_buffer(encoder->hwFramesCtx, hw_frame, 0) < 0) {
                    av_frame_free(&sw_frame);
                    av_frame_free(&hw_frame);
                    if (frameData.surface.isValid()) {
                        std::lock_guard<std::mutex> lock(encoder->poolMutex);
                        encoder->freeSurfaces.push(frameData.surface);
                    }
                    continue;
                }
                hw_frame->pts = sw_frame->pts;
                
                if (av_hwframe_transfer_data(hw_frame, sw_frame, 0) < 0) {
                    av_frame_free(&sw_frame);
                    av_frame_free(&hw_frame);
                    if (frameData.surface.isValid()) {
                        std::lock_guard<std::mutex> lock(encoder->poolMutex);
                        encoder->freeSurfaces.push(frameData.surface);
                    }
                    continue;
                }
                encode_frame = hw_frame;
            }
        }

        // Return surface to pool immediately after use/copy
        if (frameData.surface.isValid()) {
             std::lock_guard<std::mutex> lock(encoder->poolMutex);
             encoder->freeSurfaces.push(frameData.surface);
        }

        // Encode the frame
        int ret = avcodec_send_frame(encoder->videoCodecCtx, encode_frame);
        
        if (hw_frame) av_frame_free(&hw_frame);
        if (sw_frame) av_frame_free(&sw_frame);
        
        if (ret < 0) continue;

        AVPacket* pkt = av_packet_alloc();
        while (true) {
            ret = avcodec_receive_packet(encoder->videoCodecCtx, pkt);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
            if (ret < 0) { av_packet_free(&pkt); break; }

            av_packet_rescale_ts(pkt, encoder->videoCodecCtx->time_base,
                                 encoder->videoStream->time_base);
            pkt->stream_index = encoder->videoStream->index;

            av_interleaved_write_frame(encoder->fmtCtx, pkt);
        }
        av_packet_free(&pkt);
    }
}

static const AVCodec* find_encoder(const char* codec_name, bool try_hw) {
    const AVCodec* codec = nullptr;

    if (try_hw) {
        if (strcmp(codec_name, "h264") == 0) {
#if defined(__linux__) && !defined(__ANDROID__)
            codec = avcodec_find_encoder_by_name("h264_vaapi");
#elif defined(__ANDROID__)
            codec = avcodec_find_encoder_by_name("h264_mediacodec");
#elif defined(__APPLE__)
            codec = avcodec_find_encoder_by_name("h264_videotoolbox");
#elif defined(_WIN32)
            codec = avcodec_find_encoder_by_name("h264_nvenc");
            if (!codec) codec = avcodec_find_encoder_by_name("h264_amf");
#endif
        } else if (strcmp(codec_name, "h265") == 0 || strcmp(codec_name, "hevc") == 0) {
#if defined(__linux__) && !defined(__ANDROID__)
            codec = avcodec_find_encoder_by_name("hevc_vaapi");
#elif defined(__ANDROID__)
            codec = avcodec_find_encoder_by_name("hevc_mediacodec");
#elif defined(__APPLE__)
            codec = avcodec_find_encoder_by_name("hevc_videotoolbox");
#elif defined(_WIN32)
            codec = avcodec_find_encoder_by_name("hevc_nvenc");
            if (!codec) codec = avcodec_find_encoder_by_name("hevc_amf");
#endif
        }
    }

    if (!codec) {
        if (strcmp(codec_name, "h264") == 0) {
            codec = avcodec_find_encoder(AV_CODEC_ID_H264);
        } else if (strcmp(codec_name, "h265") == 0 || strcmp(codec_name, "hevc") == 0) {
            codec = avcodec_find_encoder(AV_CODEC_ID_HEVC);
        }
    }

    return codec;
}

static const AVCodec* find_audio_encoder(const char* codec_name) {
    if (strcmp(codec_name, "aac") == 0) {
        return avcodec_find_encoder(AV_CODEC_ID_AAC);
    } else if (strcmp(codec_name, "opus") == 0) {
        return avcodec_find_encoder(AV_CODEC_ID_OPUS);
    }
    return nullptr;
}

extern "C" {

TENNOJI_EXPORT TennojiEncoder* rina_encoder_create(TennojiEngine* engine,
                                                       const TennojiEncoderConfig* config) {
    if (!engine || !config || !config->output_path) return nullptr;

    auto* enc = new TennojiEncoder();
    enc->engine = engine;
    enc->width = config->width;
    enc->height = config->height;
    enc->fps = config->fps;

    int ret = avformat_alloc_output_context2(
        &enc->fmtCtx, nullptr, nullptr, config->output_path);
    if (ret < 0 || !enc->fmtCtx) {
        delete enc;
        return nullptr;
    }

    const char* vcodec_name = config->video_codec ? config->video_codec : "h264";
    const AVCodec* vcodec = find_encoder(vcodec_name, true);
    if (!vcodec) {
        avformat_free_context(enc->fmtCtx);
        delete enc;
        return nullptr;
    }

    enc->videoCodecCtx = avcodec_alloc_context3(vcodec);
    enc->videoCodecCtx->width = config->width;
    enc->videoCodecCtx->height = config->height;
    enc->videoCodecCtx->time_base = AVRational{1, config->fps};
    enc->videoCodecCtx->framerate = AVRational{config->fps, 1};
    enc->videoCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P;
    enc->videoCodecCtx->gop_size = 12;
    enc->videoCodecCtx->max_b_frames = 2;

    AVPixelFormat sw_format = AV_PIX_FMT_YUV420P;

    if (strstr(vcodec->name, "vaapi") || strstr(vcodec->name, "nvenc") || strstr(vcodec->name, "videotoolbox") || strstr(vcodec->name, "mediacodec")) {
        AVHWDeviceType type = AV_HWDEVICE_TYPE_NONE;
        if (strstr(vcodec->name, "vaapi")) type = AV_HWDEVICE_TYPE_VAAPI;
        else if (strstr(vcodec->name, "nvenc")) type = AV_HWDEVICE_TYPE_CUDA;
        else if (strstr(vcodec->name, "videotoolbox")) type = AV_HWDEVICE_TYPE_VIDEOTOOLBOX;
        else if (strstr(vcodec->name, "mediacodec")) type = AV_HWDEVICE_TYPE_MEDIACODEC;
        
        if (type != AV_HWDEVICE_TYPE_NONE) {
            int err = av_hwdevice_ctx_create(&enc->hwDeviceCtx, type, nullptr, nullptr, 0);
            if (err == 0) {
                 enc->videoCodecCtx->hw_device_ctx = av_buffer_ref(enc->hwDeviceCtx);
                 
                 if (type == AV_HWDEVICE_TYPE_VAAPI) enc->videoCodecCtx->pix_fmt = AV_PIX_FMT_VAAPI;
                 else if (type == AV_HWDEVICE_TYPE_CUDA) enc->videoCodecCtx->pix_fmt = AV_PIX_FMT_CUDA;
                 else if (type == AV_HWDEVICE_TYPE_VIDEOTOOLBOX) enc->videoCodecCtx->pix_fmt = AV_PIX_FMT_VIDEOTOOLBOX;
                 else if (type == AV_HWDEVICE_TYPE_MEDIACODEC) enc->videoCodecCtx->pix_fmt = AV_PIX_FMT_MEDIACODEC;
                 
                 enc->hwFramesCtx = av_hwframe_ctx_alloc(enc->hwDeviceCtx);
                 if (enc->hwFramesCtx) {
                     AVHWFramesContext* frames_ctx = (AVHWFramesContext*)enc->hwFramesCtx->data;
                     frames_ctx->format = enc->videoCodecCtx->pix_fmt;
                     frames_ctx->sw_format = AV_PIX_FMT_NV12; 
                     frames_ctx->width = enc->width;
                     frames_ctx->height = enc->height;
                     frames_ctx->initial_pool_size = 20;
                     if (av_hwframe_ctx_init(enc->hwFramesCtx) >= 0) {
                        enc->videoCodecCtx->hw_frames_ctx = av_buffer_ref(enc->hwFramesCtx);
                        sw_format = AV_PIX_FMT_NV12;
                     } else {
                         av_buffer_unref(&enc->hwFramesCtx);
                     }
                 }
            }
        }
    }

    if (enc->fmtCtx->oformat->flags & AVFMT_GLOBALHEADER) {
        enc->videoCodecCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    av_opt_set(enc->videoCodecCtx->priv_data, "preset", "medium", 0);

    ret = avcodec_open2(enc->videoCodecCtx, vcodec, nullptr);
    if (ret < 0) {
        avcodec_free_context(&enc->videoCodecCtx);
        avformat_free_context(enc->fmtCtx);
        delete enc;
        return nullptr;
    }

    enc->videoStream = avformat_new_stream(enc->fmtCtx, nullptr);
    avcodec_parameters_from_context(enc->videoStream->codecpar, enc->videoCodecCtx);
    enc->videoStream->time_base = enc->videoCodecCtx->time_base;

    if (config->audio_codec) {
        const AVCodec* acodec = find_audio_encoder(config->audio_codec);
        if (acodec) {
            enc->audioCodecCtx = avcodec_alloc_context3(acodec);
            enc->audioCodecCtx->sample_rate = config->audio_sample_rate > 0
                                                  ? config->audio_sample_rate : 44100;
            enc->audioCodecCtx->sample_fmt = acodec->sample_fmts
                                                 ? acodec->sample_fmts[0]
                                                 : AV_SAMPLE_FMT_FLTP;
            av_channel_layout_default(&enc->audioCodecCtx->ch_layout,
                                      config->audio_channels > 0 ? config->audio_channels : 2);
            enc->audioCodecCtx->time_base = AVRational{1, enc->audioCodecCtx->sample_rate};
            enc->audioCodecCtx->bit_rate = 128000;

            if (enc->fmtCtx->oformat->flags & AVFMT_GLOBALHEADER) {
                enc->audioCodecCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
            }

            ret = avcodec_open2(enc->audioCodecCtx, acodec, nullptr);
            if (ret >= 0) {
                enc->audioStream = avformat_new_stream(enc->fmtCtx, nullptr);
                avcodec_parameters_from_context(enc->audioStream->codecpar, enc->audioCodecCtx);
                enc->audioStream->time_base = enc->audioCodecCtx->time_base;

                enc->audioMixer = tennoji::audio_mixer_create(
                    enc->audioCodecCtx->sample_rate,
                    enc->audioCodecCtx->ch_layout.nb_channels,
                    enc->audioCodecCtx->sample_fmt
                );
            } else {
                avcodec_free_context(&enc->audioCodecCtx);
            }
        }
    }

    enc->swsCtx = sws_getContext(
        config->width, config->height, AV_PIX_FMT_BGRA,
        config->width, config->height, sw_format,
        SWS_BILINEAR, nullptr, nullptr, nullptr
    );
    if (!enc->swsCtx) {
        rina_encoder_destroy(enc);
        return nullptr;
    }

    if (!(enc->fmtCtx->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&enc->fmtCtx->pb, config->output_path, AVIO_FLAG_WRITE);
        if (ret < 0) {
            rina_encoder_destroy(enc);
            return nullptr;
        }
    }

    ret = avformat_write_header(enc->fmtCtx, nullptr);
    if (ret < 0) {
        rina_encoder_destroy(enc);
        return nullptr;
    }

    enc->running = true;
    enc->renderThread = std::thread(render_loop, enc);
    enc->encodeThread = std::thread(encode_loop, enc);

    return enc;
}

TENNOJI_EXPORT int rina_encoder_write_frame(TennojiEncoder* encoder,
                                                TennojiCanvas* canvas) {
    if (!encoder || !canvas || !canvas->recorder) return -1;

    sk_sp<SkPicture> pic = canvas->recorder->finishRecordingAsPicture();
    
    canvas->canvas = canvas->recorder->beginRecording(canvas->width, canvas->height);

    if (!pic) return -1;

    {
        std::lock_guard<std::mutex> lock(encoder->renderMutex);
        encoder->renderQueue.push({std::move(pic), encoder->videoPts++});
    }
    encoder->renderCv.notify_one();

    return 0;
}

TENNOJI_EXPORT int rina_encoder_write_audio(TennojiEncoder* encoder,
                                                TennojiDecoder* audio_decoder,
                                                int64_t duration_us) {
    if (!encoder || !encoder->audioCodecCtx || !audio_decoder) return -1;

    if (!audio_decoder->audioCodecCtx || audio_decoder->audioStreamIdx < 0) return -1;

    if (encoder->audioMixer) {
        tennoji::audio_mixer_configure(
            encoder->audioMixer,
            audio_decoder->audioCodecCtx->sample_rate,
            audio_decoder->audioCodecCtx->ch_layout.nb_channels,
            audio_decoder->audioCodecCtx->sample_fmt,
            &audio_decoder->audioCodecCtx->ch_layout
        );
    }

    int64_t target_samples = av_rescale(duration_us,
                                         encoder->audioCodecCtx->sample_rate,
                                         1000000);
    int64_t samples_written = 0;

    AVPacket* pkt = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();

    while (samples_written < target_samples) {
        int ret = av_read_frame(audio_decoder->fmtCtx, pkt);
        if (ret < 0) break;

        if (pkt->stream_index != audio_decoder->audioStreamIdx) {
            av_packet_unref(pkt);
            continue;
        }

        ret = avcodec_send_packet(audio_decoder->audioCodecCtx, pkt);
        av_packet_unref(pkt);
        if (ret < 0) break;

        while (samples_written < target_samples) {
            ret = avcodec_receive_frame(audio_decoder->audioCodecCtx, frame);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
            if (ret < 0) goto done;

            AVFrame* outFrame = frame;
            AVFrame* convertedFrame = nullptr;
            if (encoder->audioMixer) {
                convertedFrame = tennoji::audio_mixer_convert(encoder->audioMixer, frame);
                if (convertedFrame) outFrame = convertedFrame;
            }

            outFrame->pts = encoder->audioPts;
            encoder->audioPts += outFrame->nb_samples;
            samples_written += outFrame->nb_samples;

            ret = avcodec_send_frame(encoder->audioCodecCtx, outFrame);
            if (convertedFrame) av_frame_free(&convertedFrame);
            av_frame_unref(frame);
            if (ret < 0) goto done;

            AVPacket* outPkt = av_packet_alloc();
            while (true) {
                ret = avcodec_receive_packet(encoder->audioCodecCtx, outPkt);
                if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
                if (ret < 0) { av_packet_free(&outPkt); goto done; }

                av_packet_rescale_ts(outPkt, encoder->audioCodecCtx->time_base,
                                     encoder->audioStream->time_base);
                outPkt->stream_index = encoder->audioStream->index;

                av_interleaved_write_frame(encoder->fmtCtx, outPkt);
            }
            av_packet_free(&outPkt);
        }
    }

done:
    av_frame_free(&frame);
    av_packet_free(&pkt);
    return 0;
}

TENNOJI_EXPORT int rina_encoder_drain_audio_queue(TennojiEncoder* encoder,
                                                      TennojiDecoder* decoder) {
    if (!encoder || !encoder->audioCodecCtx || !decoder) return -1;
    if (!decoder->audioCodecCtx || decoder->audioStreamIdx < 0) return 0;

    if (encoder->audioMixer) {
        tennoji::audio_mixer_configure(
            encoder->audioMixer,
            decoder->audioCodecCtx->sample_rate,
            decoder->audioCodecCtx->ch_layout.nb_channels,
            decoder->audioCodecCtx->sample_fmt,
            &decoder->audioCodecCtx->ch_layout
        );
    }

    std::deque<AVPacket*> packets;
    {
        std::lock_guard<std::mutex> lock(decoder->audioQueueMutex);
        packets.swap(decoder->audioPacketQueue);
    }

    AVFrame* frame = av_frame_alloc();

    for (auto* pkt : packets) {
        int ret = avcodec_send_packet(decoder->audioCodecCtx, pkt);
        av_packet_free(&pkt);
        if (ret < 0) continue;

        while (true) {
            ret = avcodec_receive_frame(decoder->audioCodecCtx, frame);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
            if (ret < 0) break;

            AVFrame* outFrame = frame;
            AVFrame* convertedFrame = nullptr;
            if (encoder->audioMixer) {
                convertedFrame = tennoji::audio_mixer_convert(encoder->audioMixer, frame);
                if (convertedFrame) outFrame = convertedFrame;
            }

            outFrame->pts = encoder->audioPts;
            encoder->audioPts += outFrame->nb_samples;

            ret = avcodec_send_frame(encoder->audioCodecCtx, outFrame);
            if (convertedFrame) av_frame_free(&convertedFrame);
            av_frame_unref(frame);
            if (ret < 0) break;

            AVPacket* outPkt = av_packet_alloc();
            while (true) {
                ret = avcodec_receive_packet(encoder->audioCodecCtx, outPkt);
                if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
                if (ret < 0) { av_packet_free(&outPkt); goto frame_done; }

                av_packet_rescale_ts(outPkt, encoder->audioCodecCtx->time_base,
                                     encoder->audioStream->time_base);
                outPkt->stream_index = encoder->audioStream->index;

                av_interleaved_write_frame(encoder->fmtCtx, outPkt);
            }
            av_packet_free(&outPkt);
        }
        frame_done:;
    }

    av_frame_free(&frame);
    return 0;
}

TENNOJI_EXPORT int rina_encoder_finalize(TennojiEncoder* encoder) {
    if (!encoder || !encoder->fmtCtx) return -1;

    encoder->running = false;
    encoder->renderCv.notify_all();
    
    if (encoder->renderThread.joinable()) encoder->renderThread.join();
    if (encoder->encodeThread.joinable()) encoder->encodeThread.join();

    if (encoder->videoCodecCtx) {
        avcodec_send_frame(encoder->videoCodecCtx, nullptr);
        AVPacket* pkt = av_packet_alloc();
        while (true) {
            int ret = avcodec_receive_packet(encoder->videoCodecCtx, pkt);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
            if (ret < 0) break;

            av_packet_rescale_ts(pkt, encoder->videoCodecCtx->time_base,
                                 encoder->videoStream->time_base);
            pkt->stream_index = encoder->videoStream->index;
            av_interleaved_write_frame(encoder->fmtCtx, pkt);
        }
        av_packet_free(&pkt);
    }

    if (encoder->audioCodecCtx) {
        avcodec_send_frame(encoder->audioCodecCtx, nullptr);
        AVPacket* pkt = av_packet_alloc();
        while (true) {
            int ret = avcodec_receive_packet(encoder->audioCodecCtx, pkt);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
            if (ret < 0) break;

            av_packet_rescale_ts(pkt, encoder->audioCodecCtx->time_base,
                                 encoder->audioStream->time_base);
            pkt->stream_index = encoder->audioStream->index;
            av_interleaved_write_frame(encoder->fmtCtx, pkt);
        }
        av_packet_free(&pkt);
    }

    return av_write_trailer(encoder->fmtCtx);
}

TENNOJI_EXPORT void rina_encoder_destroy(TennojiEncoder* encoder) {
    if (!encoder) return;

    encoder->running = false;
    encoder->renderCv.notify_all();
    encoder->encodeCv.notify_all();
    
    if (encoder->renderThread.joinable()) encoder->renderThread.join();
    if (encoder->encodeThread.joinable()) encoder->encodeThread.join();

    {
        std::lock_guard<std::mutex> lock(encoder->poolMutex);
        for (auto& surface : encoder->allSurfaces) {
            surface.release(encoder->engine->gpuCtx);
        }
        encoder->allSurfaces.clear();
    }

    if (encoder->audioMixer) {
        tennoji::audio_mixer_destroy(encoder->audioMixer);
    }

    if (encoder->swsCtx) sws_freeContext(encoder->swsCtx);

    if (encoder->videoCodecCtx) avcodec_free_context(&encoder->videoCodecCtx);
    if (encoder->audioCodecCtx) avcodec_free_context(&encoder->audioCodecCtx);
    if (encoder->hwFramesCtx) av_buffer_unref(&encoder->hwFramesCtx);
    if (encoder->hwDeviceCtx) av_buffer_unref(&encoder->hwDeviceCtx);

    if (encoder->fmtCtx) {
        if (encoder->fmtCtx->pb && !(encoder->fmtCtx->oformat->flags & AVFMT_NOFILE)) {
            avio_closep(&encoder->fmtCtx->pb);
        }
        avformat_free_context(encoder->fmtCtx);
    }

    delete encoder;
}

} // extern "C"
