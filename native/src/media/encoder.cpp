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
}

#include "include/core/SkSurface.h"
#include "include/core/SkImage.h"
#include "include/core/SkPicture.h"
#include "include/gpu/ganesh/GrDirectContext.h"

#include "../renderer/canvas_internal.h"
#include "decoder_internal.h"
#include "muxer.h"
#include "audio_mixer.h"

struct RenderFrame {
    sk_sp<SkPicture> picture;
    int64_t pts;
};

struct EncodeFrame {
    std::vector<uint8_t> pixels;
    int64_t pts;
};

struct TennojiEncoder {
    AVFormatContext* fmtCtx = nullptr;
    AVCodecContext* videoCodecCtx = nullptr;
    AVCodecContext* audioCodecCtx = nullptr;
    AVStream* videoStream = nullptr;
    AVStream* audioStream = nullptr;
    AVBufferRef* hwDeviceCtx = nullptr;
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

    std::atomic<bool> running{true};
    std::atomic<bool> renderFinished{false};
};

static void render_loop(TennojiEncoder* enc) {
    // Create a dedicated surface for this thread to render into
    // Reusing the surface avoids re-allocation
    sk_sp<SkSurface> surface;
    
    while (true) {
        RenderFrame frame;
        {
            std::unique_lock<std::mutex> lock(enc->renderMutex);
            enc->renderCv.wait(lock, [&] { return !enc->renderQueue.empty() || !enc->running; });
            if (enc->renderQueue.empty() && !enc->running) break;
            frame = std::move(enc->renderQueue.front());
            enc->renderQueue.pop();
        }

        if (!surface) {
             surface = tennoji::create_gpu_surface(enc->engine->grContext, enc->width, enc->height);
        }

        if (surface) {
             surface->getCanvas()->clear(SK_ColorTRANSPARENT);
             surface->getCanvas()->drawPicture(frame.picture);
             
             if (auto* grCtx = surface->recordingContext()) {
                 static_cast<GrDirectContext*>(grCtx)->flushAndSubmit();
             }

             // Read pixels (GPU -> CPU copy)
             // This happens on render thread so GrContext is safe
             SkImageInfo readInfo = SkImageInfo::Make(
                enc->width, enc->height,
                kBGRA_8888_SkColorType, kPremul_SkAlphaType);

             std::vector<uint8_t> pixels(enc->width * enc->height * 4);
             if (surface->readPixels(readInfo, pixels.data(), enc->width * 4, 0, 0)) {
                 {
                     std::lock_guard<std::mutex> lock(enc->encodeMutex);
                     enc->encodeQueue.push({std::move(pixels), frame.pts});
                 }
                 enc->encodeCv.notify_one();
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

        // Create AVFrame (YUV420P) from BGRA pixels
        AVFrame* frame = av_frame_alloc();
        frame->format = encoder->videoCodecCtx->pix_fmt;
        frame->width = encoder->width;
        frame->height = encoder->height;
        frame->pts = frameData.pts;
        av_frame_get_buffer(frame, 0);

        // BGRA -> YUV420P conversion using libswscale
        const uint8_t* srcSlice[] = { frameData.pixels.data() };
        const int srcStride[] = { encoder->width * 4 };
        
        int h = sws_scale(encoder->swsCtx, srcSlice, srcStride, 0, encoder->height,
                          frame->data, frame->linesize);
        if (h != encoder->height) {
            av_frame_free(&frame);
            continue;
        }

        // Encode the frame
        int ret = avcodec_send_frame(encoder->videoCodecCtx, frame);
        av_frame_free(&frame);
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
        // Try HW-accelerated encoders first
        if (strcmp(codec_name, "h264") == 0) {
#if defined(__linux__) && !defined(__ANDROID__)
            codec = avcodec_find_encoder_by_name("h264_vaapi");
#elif defined(__APPLE__)
            codec = avcodec_find_encoder_by_name("h264_videotoolbox");
#elif defined(_WIN32)
            codec = avcodec_find_encoder_by_name("h264_nvenc");
            if (!codec) codec = avcodec_find_encoder_by_name("h264_amf");
#endif
        } else if (strcmp(codec_name, "h265") == 0 || strcmp(codec_name, "hevc") == 0) {
#if defined(__linux__) && !defined(__ANDROID__)
            codec = avcodec_find_encoder_by_name("hevc_vaapi");
#elif defined(__APPLE__)
            codec = avcodec_find_encoder_by_name("hevc_videotoolbox");
#elif defined(_WIN32)
            codec = avcodec_find_encoder_by_name("hevc_nvenc");
            if (!codec) codec = avcodec_find_encoder_by_name("hevc_amf");
#endif
        }
    }

    // Fallback to software encoder
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

    // Allocate output context
    int ret = avformat_alloc_output_context2(
        &enc->fmtCtx, nullptr, nullptr, config->output_path);
    if (ret < 0 || !enc->fmtCtx) {
        delete enc;
        return nullptr;
    }

    // ---- Video stream setup ----
    const char* vcodec_name = config->video_codec ? config->video_codec : "h264";
    const AVCodec* vcodec = find_encoder(vcodec_name, false);
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

    if (enc->fmtCtx->oformat->flags & AVFMT_GLOBALHEADER) {
        enc->videoCodecCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    // Set quality preset
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

    // ---- Audio stream setup ----
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

                // Create audio mixer for resampling
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

    // Create SwsContext for color conversion
    enc->swsCtx = sws_getContext(
        config->width, config->height, AV_PIX_FMT_BGRA,
        config->width, config->height, enc->videoCodecCtx->pix_fmt,
        SWS_BILINEAR, nullptr, nullptr, nullptr
    );
    if (!enc->swsCtx) {
        rina_encoder_destroy(enc);
        return nullptr;
    }

    // Open output file
    if (!(enc->fmtCtx->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&enc->fmtCtx->pb, config->output_path, AVIO_FLAG_WRITE);
        if (ret < 0) {
            rina_encoder_destroy(enc);
            return nullptr;
        }
    }

    // Write file header
    ret = avformat_write_header(enc->fmtCtx, nullptr);
    if (ret < 0) {
        rina_encoder_destroy(enc);
        return nullptr;
    }

    // Start pipeline threads
    enc->running = true;
    enc->renderThread = std::thread(render_loop, enc);
    enc->encodeThread = std::thread(encode_loop, enc);

    return enc;
}

TENNOJI_EXPORT int rina_encoder_write_frame(TennojiEncoder* encoder,
                                                TennojiCanvas* canvas) {
    if (!encoder || !canvas || !canvas->recorder) return -1;

    // Finish recording the current frame
    sk_sp<SkPicture> pic = canvas->recorder->finishRecordingAsPicture();
    
    // Begin recording the next frame immediately
    // This assumes the canvas dimensions don't change
    // Since rina_canvas_create initializes it with specific width/height, we should reuse those.
    // TennojiCanvas stores width/height now.
    canvas->canvas = canvas->recorder->beginRecording(canvas->width, canvas->height);

    if (!pic) return -1;

    // Push to render queue
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

    // Configure audio mixer if not already done
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

            // Resample frame if needed
            AVFrame* outFrame = frame;
            AVFrame* convertedFrame = nullptr;
            if (encoder->audioMixer) {
                convertedFrame = tennoji::audio_mixer_convert(encoder->audioMixer, frame);
                if (convertedFrame) outFrame = convertedFrame;
            }

            outFrame->pts = encoder->audioPts;
            encoder->audioPts += outFrame->nb_samples;
            samples_written += outFrame->nb_samples;

            // Encode
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

    // Configure audio mixer for this decoder's format (idempotent-ish)
    if (encoder->audioMixer) {
        tennoji::audio_mixer_configure(
            encoder->audioMixer,
            decoder->audioCodecCtx->sample_rate,
            decoder->audioCodecCtx->ch_layout.nb_channels,
            decoder->audioCodecCtx->sample_fmt,
            &decoder->audioCodecCtx->ch_layout
        );
    }

    // Drain all buffered audio packets from the decoder's queue
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

            // Resample if needed
            AVFrame* outFrame = frame;
            AVFrame* convertedFrame = nullptr;
            if (encoder->audioMixer) {
                convertedFrame = tennoji::audio_mixer_convert(encoder->audioMixer, frame);
                if (convertedFrame) outFrame = convertedFrame;
            }

            outFrame->pts = encoder->audioPts;
            encoder->audioPts += outFrame->nb_samples;

            // Encode
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

    // Signal threads to stop and wait
    encoder->running = false;
    encoder->renderCv.notify_all();
    
    if (encoder->renderThread.joinable()) encoder->renderThread.join();
    if (encoder->encodeThread.joinable()) encoder->encodeThread.join();

    // Flush video encoder
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

    // Flush audio encoder
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

    if (encoder->audioMixer) {
        tennoji::audio_mixer_destroy(encoder->audioMixer);
    }

    if (encoder->swsCtx) sws_freeContext(encoder->swsCtx);

    if (encoder->videoCodecCtx) avcodec_free_context(&encoder->videoCodecCtx);
    if (encoder->audioCodecCtx) avcodec_free_context(&encoder->audioCodecCtx);
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
