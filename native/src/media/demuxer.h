#pragma once

extern "C" {
#include <libavformat/avformat.h>
}

namespace tennoji {

struct Demuxer {
    AVFormatContext* fmtCtx = nullptr;
    int videoStreamIdx = -1;
    int audioStreamIdx = -1;
};

Demuxer* demuxer_open(const char* uri);
void demuxer_close(Demuxer* demux);
int demuxer_read_packet(Demuxer* demux, AVPacket* pkt);
int demuxer_seek(Demuxer* demux, int stream_index, int64_t timestamp, int flags);

} // namespace tennoji
