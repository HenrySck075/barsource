#include "muxer.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/error.h>
}

namespace tennoji {

Muxer* muxer_create(const char* output_path, const char* format_name) {
    if (!output_path) return nullptr;

    auto* mux = new Muxer();

    int ret = avformat_alloc_output_context2(
        &mux->fmtCtx, nullptr, format_name, output_path);
    if (ret < 0 || !mux->fmtCtx) {
        delete mux;
        return nullptr;
    }

    // Open output file if needed
    if (!(mux->fmtCtx->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&mux->fmtCtx->pb, output_path, AVIO_FLAG_WRITE);
        if (ret < 0) {
            avformat_free_context(mux->fmtCtx);
            delete mux;
            return nullptr;
        }
    }

    return mux;
}

AVStream* muxer_add_video_stream(Muxer* mux, AVCodecContext* codecCtx) {
    if (!mux || !mux->fmtCtx || !codecCtx) return nullptr;

    AVStream* stream = avformat_new_stream(mux->fmtCtx, nullptr);
    if (!stream) return nullptr;

    avcodec_parameters_from_context(stream->codecpar, codecCtx);
    stream->time_base = codecCtx->time_base;
    mux->videoStream = stream;

    return stream;
}

AVStream* muxer_add_audio_stream(Muxer* mux, AVCodecContext* codecCtx) {
    if (!mux || !mux->fmtCtx || !codecCtx) return nullptr;

    AVStream* stream = avformat_new_stream(mux->fmtCtx, nullptr);
    if (!stream) return nullptr;

    avcodec_parameters_from_context(stream->codecpar, codecCtx);
    stream->time_base = codecCtx->time_base;
    mux->audioStream = stream;

    return stream;
}

int muxer_write_header(Muxer* mux) {
    if (!mux || !mux->fmtCtx) return -1;
    return avformat_write_header(mux->fmtCtx, nullptr);
}

int muxer_write_packet(Muxer* mux, AVPacket* pkt) {
    if (!mux || !mux->fmtCtx || !pkt) return -1;
    return av_interleaved_write_frame(mux->fmtCtx, pkt);
}

int muxer_write_trailer(Muxer* mux) {
    if (!mux || !mux->fmtCtx) return -1;
    return av_write_trailer(mux->fmtCtx);
}

void muxer_close(Muxer* mux) {
    if (!mux) return;
    if (mux->fmtCtx) {
        if (mux->fmtCtx->pb && !(mux->fmtCtx->oformat->flags & AVFMT_NOFILE)) {
            avio_closep(&mux->fmtCtx->pb);
        }
        avformat_free_context(mux->fmtCtx);
    }
    delete mux;
}

} // namespace tennoji
