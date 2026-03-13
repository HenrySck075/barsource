#pragma once

extern "C" {
#include <libswresample/swresample.h>
#include <libavutil/frame.h>
#include <libavutil/channel_layout.h>
#include <libavutil/samplefmt.h>
}

namespace tennoji {

struct AudioMixer {
    SwrContext* swrCtx = nullptr;
    int out_sample_rate = 0;
    int out_channels = 0;
    AVSampleFormat out_sample_fmt = AV_SAMPLE_FMT_FLTP;
    AVChannelLayout out_ch_layout = {};
};

AudioMixer* audio_mixer_create(int out_sample_rate, int out_channels, AVSampleFormat out_fmt);
void audio_mixer_destroy(AudioMixer* mixer);

// Configure the resampler for a specific input format.
int audio_mixer_configure(AudioMixer* mixer,
                          int in_sample_rate,
                          int in_channels,
                          AVSampleFormat in_fmt,
                          const AVChannelLayout* in_ch_layout);

// Resample/convert a frame. Caller owns the returned frame.
AVFrame* audio_mixer_convert(AudioMixer* mixer, const AVFrame* input);

} // namespace tennoji
