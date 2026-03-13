#include "frame_pool.h"

extern "C" {
#include <libavutil/frame.h>
}

#include <cstdlib>

namespace tennoji {

FramePool::FramePool(size_t capacity)
    : capacity_(capacity > 0 ? capacity : 8) {
    frames_.resize(capacity_, nullptr);
}

FramePool::~FramePool() {
    flush();
}

bool FramePool::push(AVFrame* frame) {
    if (!frame) return false;

    std::lock_guard<std::mutex> lock(mutex_);

    size_t write_idx = (head_ + count_) % capacity_;

    if (count_ == capacity_) {
        // Ring buffer full — overwrite oldest
        av_frame_free(&frames_[write_idx]);
        head_ = (head_ + 1) % capacity_;
    } else {
        count_++;
    }

    frames_[write_idx] = av_frame_clone(frame);
    return true;
}

AVFrame* FramePool::get_frame(int64_t pts) {
    std::lock_guard<std::mutex> lock(mutex_);

    if (count_ == 0) return nullptr;

    // Find the frame with the closest PTS <= requested pts
    AVFrame* best = nullptr;
    int64_t best_diff = INT64_MAX;

    for (size_t i = 0; i < count_; i++) {
        size_t idx = (head_ + i) % capacity_;
        AVFrame* f = frames_[idx];
        if (!f) continue;

        int64_t diff = pts - f->pts;
        if (diff >= 0 && diff < best_diff) {
            best_diff = diff;
            best = f;
        }
    }

    // If no frame before pts, return the earliest frame
    if (!best && count_ > 0) {
        best = frames_[head_];
    }

    return best; // Caller does NOT own this pointer
}

void FramePool::flush() {
    std::lock_guard<std::mutex> lock(mutex_);
    for (size_t i = 0; i < capacity_; i++) {
        if (frames_[i]) {
            av_frame_free(&frames_[i]);
        }
    }
    head_ = 0;
    count_ = 0;
}

size_t FramePool::size() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return count_;
}

} // namespace tennoji
