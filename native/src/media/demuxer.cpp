#include "demuxer.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavutil/error.h>
}

namespace tennoji {

Demuxer* demuxer_open(const char* uri) {
    if (!uri) return nullptr;

    auto* demux = new Demuxer();

    // Open input file
    int ret = avformat_open_input(&demux->fmtCtx, uri, nullptr, nullptr);
    if (ret < 0) {
        delete demux;
        return nullptr;
    }

    // Find stream info
    ret = avformat_find_stream_info(demux->fmtCtx, nullptr);
    if (ret < 0) {
        avformat_close_input(&demux->fmtCtx);
        delete demux;
        return nullptr;
    }

    // Find best video and audio streams
    demux->videoStreamIdx = av_find_best_stream(
        demux->fmtCtx, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    demux->audioStreamIdx = av_find_best_stream(
        demux->fmtCtx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);

    // At least one stream must be present
    if (demux->videoStreamIdx < 0 && demux->audioStreamIdx < 0) {
        avformat_close_input(&demux->fmtCtx);
        delete demux;
        return nullptr;
    }

    return demux;
}

void demuxer_close(Demuxer* demux) {
    if (!demux) return;
    if (demux->fmtCtx) {
        avformat_close_input(&demux->fmtCtx);
    }
    delete demux;
}

int demuxer_read_packet(Demuxer* demux, AVPacket* pkt) {
    if (!demux || !demux->fmtCtx || !pkt) return -1;
    return av_read_frame(demux->fmtCtx, pkt);
}

int demuxer_seek(Demuxer* demux, int stream_index, int64_t timestamp, int flags) {
    if (!demux || !demux->fmtCtx) return -1;
    return av_seek_frame(demux->fmtCtx, stream_index, timestamp, flags);
}

} // namespace tennoji
