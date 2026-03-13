#pragma once

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/hwcontext.h>
#include <libavutil/pixfmt.h>
}

#include <deque>
#include <mutex>

#include "frame_pool.h"

struct TennojiEngine;

struct TennojiDecoder {
    AVFormatContext* fmtCtx = nullptr;
    AVCodecContext* videoCodecCtx = nullptr;
    AVCodecContext* audioCodecCtx = nullptr;
    int videoStreamIdx = -1;
    int audioStreamIdx = -1;
    AVBufferRef* hwDeviceCtx = nullptr;
    enum AVPixelFormat hwPixFmt = AV_PIX_FMT_NONE;
    tennoji::FramePool* framePool = nullptr;
    TennojiEngine* engine = nullptr;
    int64_t lastSeekTs = INT64_MIN;

    // Audio packet queue: video decode stashes audio packets here
    // instead of discarding them, so they can be drained by the encoder.
    std::deque<AVPacket*> audioPacketQueue;
    std::mutex audioQueueMutex;

    void enqueue_audio_packet(AVPacket* pkt) {
        AVPacket* clone = av_packet_clone(pkt);
        if (clone) {
            std::lock_guard<std::mutex> lock(audioQueueMutex);
            audioPacketQueue.push_back(clone);
        }
    }

    void flush_audio_queue() {
        std::lock_guard<std::mutex> lock(audioQueueMutex);
        for (auto* p : audioPacketQueue) av_packet_free(&p);
        audioPacketQueue.clear();
    }
};
