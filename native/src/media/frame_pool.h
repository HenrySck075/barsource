#pragma once

extern "C" {
#include <libavutil/frame.h>
}

#include <vector>
#include <mutex>
#include <atomic>

namespace tennoji {

class FramePool {
public:
    explicit FramePool(size_t capacity = 8);
    ~FramePool();

    FramePool(const FramePool&) = delete;
    FramePool& operator=(const FramePool&) = delete;

    // Push a decoded frame into the ring buffer.
    // Returns false if the buffer is full (oldest frame is overwritten).
    bool push(AVFrame* frame);

    // Get the frame closest to the given timestamp (in stream timebase).
    AVFrame* get_frame(int64_t pts);

    // Flush all frames from the pool.
    void flush();

    size_t size() const;

private:
    std::vector<AVFrame*> frames_;
    size_t capacity_;
    size_t head_ = 0;
    size_t count_ = 0;
    mutable std::mutex mutex_;
};

} // namespace tennoji
