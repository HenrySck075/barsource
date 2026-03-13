#include "audio_mixer.h"

extern "C" {
#include <libswresample/swresample.h>
#include <libavutil/frame.h>
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
#include <libavutil/mem.h>
}

namespace tennoji {

AudioMixer* audio_mixer_create(int out_sample_rate, int out_channels, AVSampleFormat out_fmt) {
    auto* mixer = new AudioMixer();
    mixer->out_sample_rate = out_sample_rate;
    mixer->out_channels = out_channels;
    mixer->out_sample_fmt = out_fmt;

    av_channel_layout_default(&mixer->out_ch_layout, out_channels);

    return mixer;
}

void audio_mixer_destroy(AudioMixer* mixer) {
    if (!mixer) return;
    if (mixer->swrCtx) {
        swr_free(&mixer->swrCtx);
    }
    av_channel_layout_uninit(&mixer->out_ch_layout);
    delete mixer;
}

int audio_mixer_configure(AudioMixer* mixer,
                          int in_sample_rate,
                          int in_channels,
                          AVSampleFormat in_fmt,
                          const AVChannelLayout* in_ch_layout) {
    if (!mixer) return -1;

    // Free existing context if reconfiguring
    if (mixer->swrCtx) {
        swr_free(&mixer->swrCtx);
    }

    int ret = swr_alloc_set_opts2(
        &mixer->swrCtx,
        &mixer->out_ch_layout,
        mixer->out_sample_fmt,
        mixer->out_sample_rate,
        in_ch_layout,
        in_fmt,
        in_sample_rate,
        0, nullptr
    );
    if (ret < 0) return ret;

    ret = swr_init(mixer->swrCtx);
    if (ret < 0) {
        swr_free(&mixer->swrCtx);
        return ret;
    }

    return 0;
}

AVFrame* audio_mixer_convert(AudioMixer* mixer, const AVFrame* input) {
    if (!mixer || !mixer->swrCtx || !input) return nullptr;

    AVFrame* output = av_frame_alloc();
    if (!output) return nullptr;

    output->format = mixer->out_sample_fmt;
    av_channel_layout_copy(&output->ch_layout, &mixer->out_ch_layout);
    output->sample_rate = mixer->out_sample_rate;

    // Calculate output sample count
    int64_t delay = swr_get_delay(mixer->swrCtx, input->sample_rate);
    output->nb_samples = (int)av_rescale_rnd(
        delay + input->nb_samples,
        mixer->out_sample_rate,
        input->sample_rate,
        AV_ROUND_UP
    );

    int ret = av_frame_get_buffer(output, 0);
    if (ret < 0) {
        av_frame_free(&output);
        return nullptr;
    }

    ret = swr_convert(
        mixer->swrCtx,
        output->data, output->nb_samples,
        (const uint8_t**)input->data, input->nb_samples
    );
    if (ret < 0) {
        av_frame_free(&output);
        return nullptr;
    }

    output->nb_samples = ret;
    output->pts = input->pts;

    return output;
}

} // namespace tennoji
