#pragma once

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/hwcontext.h>
#include <libavutil/pixfmt.h>
#include <libavutil/audio_fifo.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
}

#include <deque>
#include <mutex>
#include <vector>
#include <cstddef>

#include "frame_pool.h"

struct TennojiEngine;
struct TennojiCanvasImage;

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
    AVAudioFifo* audioFifo = nullptr;
    SwrContext* swrCtx = nullptr;
    SwsContext* videoSwsCtx = nullptr;
    int64_t lastSeekTs = INT64_MIN;
    int64_t lastAudioReadTs = INT64_MIN;
    int swrOutSampleRate = 0;
    std::vector<float> audioScratch;
    std::vector<uint8_t> rgbaScratch;
    AVPacket* decodePacket = nullptr;
    AVFrame* decodeFrame = nullptr;
    AVFrame* audioDecodeFrame = nullptr;
    TennojiCanvasImage* cachedTexture = nullptr;
    int64_t cachedTextureTsUs = INT64_MIN;

    // Audio packet queue: video decode stashes audio packets here
    // instead of discarding them, so they can be drained by the encoder.
    std::deque<AVPacket*> audioPacketQueue;
    std::mutex audioQueueMutex;
    std::deque<AVPacket*> videoPacketQueue;
    std::mutex videoQueueMutex;
    size_t audioQueueBytes = 0;
    size_t videoQueueBytes = 0;
    static constexpr size_t kMaxAudioQueueBytes = 32 * 1024 * 1024;
    static constexpr size_t kMaxVideoQueueBytes = 128 * 1024 * 1024;
    static constexpr size_t kMaxAudioQueuePackets = 2048;
    static constexpr size_t kMaxVideoQueuePackets = 2048;

    static size_t packet_size(const AVPacket* pkt) {
        return (pkt && pkt->size > 0) ? static_cast<size_t>(pkt->size) : 0;
    }

    void trim_audio_queue_locked() {
        while ((audioQueueBytes > kMaxAudioQueueBytes ||
                audioPacketQueue.size() > kMaxAudioQueuePackets) &&
               !audioPacketQueue.empty()) {
            auto* pkt = audioPacketQueue.front();
            audioPacketQueue.pop_front();
            audioQueueBytes -= packet_size(pkt);
            av_packet_free(&pkt);
        }
    }

    void trim_video_queue_locked() {
        while ((videoQueueBytes > kMaxVideoQueueBytes ||
                videoPacketQueue.size() > kMaxVideoQueuePackets) &&
               !videoPacketQueue.empty()) {
            auto* pkt = videoPacketQueue.front();
            videoPacketQueue.pop_front();
            videoQueueBytes -= packet_size(pkt);
            av_packet_free(&pkt);
        }
    }

    void enqueue_audio_packet(AVPacket* pkt) {
        AVPacket* clone = av_packet_clone(pkt);
        if (clone) {
            std::lock_guard<std::mutex> lock(audioQueueMutex);
            audioPacketQueue.push_back(clone);
            audioQueueBytes += packet_size(clone);
            trim_audio_queue_locked();
        }
    }

    void flush_audio_queue() {
        std::lock_guard<std::mutex> lock(audioQueueMutex);
        for (auto* p : audioPacketQueue) av_packet_free(&p);
        audioPacketQueue.clear();
        audioQueueBytes = 0;
    }

    void enqueue_video_packet(AVPacket* pkt) {
        AVPacket* clone = av_packet_clone(pkt);
        if (clone) {
            std::lock_guard<std::mutex> lock(videoQueueMutex);
            videoPacketQueue.push_back(clone);
            videoQueueBytes += packet_size(clone);
            trim_video_queue_locked();
        }
    }

    void flush_video_queue() {
        std::lock_guard<std::mutex> lock(videoQueueMutex);
        for (auto* p : videoPacketQueue) av_packet_free(&p);
        videoPacketQueue.clear();
        videoQueueBytes = 0;
    }
};
