#pragma once

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
}

namespace tennoji {

struct Muxer {
    AVFormatContext* fmtCtx = nullptr;
    AVStream* videoStream = nullptr;
    AVStream* audioStream = nullptr;
};

Muxer* muxer_create(const char* output_path, const char* format_name);
AVStream* muxer_add_video_stream(Muxer* mux, AVCodecContext* codecCtx);
AVStream* muxer_add_audio_stream(Muxer* mux, AVCodecContext* codecCtx);
int muxer_write_header(Muxer* mux);
int muxer_write_packet(Muxer* mux, AVPacket* pkt);
int muxer_write_trailer(Muxer* mux);
void muxer_close(Muxer* mux);

} // namespace tennoji
