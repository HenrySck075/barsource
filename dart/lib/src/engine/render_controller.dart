import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../foundation/geometry.dart';
import '../painting/canvas.dart';
import '../rendering/media_render.dart';
import '../rendering/object.dart';
import '../rendering/pipeline_owner.dart';
import '../rendering/time_box.dart';
import '../widgets/framework.dart';
import 'bindings.dart';
import 'engine.dart';

class RenderConfig {
  const RenderConfig({
    required this.output,
    required this.duration,
    required this.fps,
    required this.resolution,
    this.codec = const VideoCodec.h264(),
    this.audioCodec = const AudioCodec.aac(),
  });
  final String output;
  final Duration duration;
  final int fps;
  final Size resolution;
  final VideoCodec codec;
  final AudioCodec audioCodec;
}

class VideoCodec {
  const VideoCodec.h264() : name = 'h264';
  const VideoCodec.h265() : name = 'h265';
  final String name;
}

class AudioCodec {
  const AudioCodec.aac() : name = 'aac';
  const AudioCodec.opus() : name = 'opus';
  final String name;
}

void render(Widget root, RenderConfig config) {
  Engine.init(
    width: config.resolution.width.toInt(),
    height: config.resolution.height.toInt(),
    fps: config.fps,
  );
  final enginePtr = Engine.instance.nativePtr;

  // Build the tree
  final rootElement = root.createElement();
  rootElement.mount(null, null);

  final pipelineOwner = PipelineOwner();
  final renderRoot = rootElement.renderObject!;
  renderRoot.attach(pipelineOwner);

  // Create encoder
  final encConfig = calloc<TennojiEncoderConfig>();
  final outputPathUtf8 = config.output.toNativeUtf8(allocator: calloc);
  final videoCodecUtf8 = config.codec.name.toNativeUtf8(allocator: calloc);
  final audioCodecUtf8 = config.audioCodec.name.toNativeUtf8(allocator: calloc);
  encConfig.ref
    ..output_path = outputPathUtf8.cast()
    ..width = config.resolution.width.toInt()
    ..height = config.resolution.height.toInt()
    ..fps = config.fps
    ..video_codec = videoCodecUtf8.cast()
    ..audio_codec = audioCodecUtf8.cast()
    ..audio_sample_rate = 44100
    ..audio_channels = 2;

  final encoder = tennoji_encoder_create(enginePtr, encConfig);

  // Create canvas
  final nativeCanvas = tennoji_canvas_create(
    enginePtr,
    config.resolution.width.toInt(),
    config.resolution.height.toInt(),
  );

  final frameDuration = Duration(microseconds: 1000000 ~/ config.fps);
  Duration currentTime = Duration.zero;

  // Collect decoders up front. Video clip decoders auto-queue audio
  // during decoder_get_texture; audio-only clip decoders need explicit
  // decoder_read_audio calls.
  final videoClipDecoders = <Pointer<TennojiDecoder>>[];
  for (final clip in _collectVideoClips(renderRoot)) {
    if (clip.decoderPtr != null) videoClipDecoders.add(clip.decoderPtr!);
  }
  final audioOnlyDecoders = <Pointer<TennojiDecoder>>[];
  for (final clip in _collectAudioClips(renderRoot)) {
    if (clip.decoderPtr != null) audioOnlyDecoders.add(clip.decoderPtr!);
  }
  final allAudioDecoders = [...videoClipDecoders, ...audioOnlyDecoders];

  while (currentTime < config.duration) {
    // Layout
    final constraints = TimeBoxConstraints(
      currentTime: currentTime,
      minWidth: config.resolution.width,
      maxWidth: config.resolution.width,
      minHeight: config.resolution.height,
      maxHeight: config.resolution.height,
    );
    renderRoot.layout(constraints);

    // Paint (this calls decoder_get_texture on video clips, which
    // auto-queues audio packets from the same demuxer stream)
    tennoji_canvas_clear(nativeCanvas, 0xFF000000);
    final canvas = Canvas(nativeCanvas);
    final paintingContext = PaintingContext(canvas);
    pipelineOwner.flushLayout();
    pipelineOwner.flushPaint(canvas);
    renderRoot.paint(paintingContext, Offset.zero);

    // Encode video frame
    tennoji_encoder_write_frame(encoder, nativeCanvas);

    // For audio-only clips, explicitly read audio up to current time
    final timeUs = currentTime.inMicroseconds;
    for (final decoder in audioOnlyDecoders) {
      tennoji_decoder_read_audio(decoder, timeUs);
    }

    // Drain all buffered audio packets into the encoder
    for (final decoder in allAudioDecoders) {
      tennoji_encoder_drain_audio_queue(encoder, decoder);
    }

    currentTime += frameDuration;
  }

  // Final drain: pick up any remaining buffered audio packets
  for (final decoder in allAudioDecoders) {
    tennoji_encoder_drain_audio_queue(encoder, decoder);
  }

  tennoji_encoder_finalize(encoder);
  tennoji_encoder_destroy(encoder);
  tennoji_canvas_destroy(nativeCanvas);

  calloc.free(outputPathUtf8);
  calloc.free(videoCodecUtf8);
  calloc.free(audioCodecUtf8);
  calloc.free(encConfig);

  rootElement.unmount();
  Engine.instance.shutdown();
}

List<RenderAudioClip> _collectAudioClips(RenderObject node) {
  final result = <RenderAudioClip>[];
  if (node is RenderAudioClip) result.add(node);
  if (node is ContainerRenderObjectMixin) {
    for (final child in node.children) {
      result.addAll(_collectAudioClips(child));
    }
  }
  return result;
}

List<RenderVideoClip> _collectVideoClips(RenderObject node) {
  final result = <RenderVideoClip>[];
  if (node is RenderVideoClip) result.add(node);
  if (node is ContainerRenderObjectMixin) {
    for (final child in node.children) {
      result.addAll(_collectVideoClips(child));
    }
  }
  return result;
}
