import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:barsource/src/scheduler/binding.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:barsource/src/dart_ui/dart_ui.dart';
import 'package:barsource/src/rendering/box.dart';

import '../engine/engine.dart';
import 'object.dart';

class RenderVideoClip extends RenderBox with AudioContributor {
  RenderVideoClip({
    required this.source,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.playbackSpeed = 1.0,
  }) {
    _ticker = Ticker(onTick);
  }

  final String source;
  final Duration trimStart;
  final Duration? trimEnd;
  final double playbackSpeed;
  late final Ticker _ticker;
  double? _overrideDuration;
  int? _sourceDurationUs;
  bool _sourceDurationResolved = false;

  Pointer<TennojiDecoder>? _decoder;
  Pointer<TennojiCanvasImage>? _texture;
  int? _textureTimestamp;
  Pointer<Float>? _audioSampleBuffer;
  int _audioSampleBufferCapacity = 0;
  Float32List? _audioOutputBuffer;

  Pointer<TennojiDecoder>? get decoderPtr => _decoder;

  int? _resolveSourceDurationUs() {
    if (_sourceDurationResolved) {
      return _sourceDurationUs;
    }

    final decoder = _decoder;
    if (decoder != null) {
      final durationUs = rina_decoder_duration(decoder);
      if (durationUs > 0) {
        _sourceDurationUs = durationUs;
        _sourceDurationResolved = true;
        return durationUs;
      }
    }

    final uri = source.toNativeUtf8(allocator: calloc);
    final durationUs = rina_media_source_duration(
      Engine.instance.nativePtr,
      uri.cast(),
    );
    calloc.free(uri);
    _sourceDurationResolved = true;
    if (durationUs <= 0) {
      return null;
    }
    _sourceDurationUs = durationUs;
    return durationUs;
  }

  @override
  double get duration {
    final overrideDuration = _overrideDuration;
    if (overrideDuration != null) {
      return overrideDuration;
    }
    final sourceDurationUs = _resolveSourceDurationUs();
    if (sourceDurationUs == null) {
      return double.infinity;
    }
    final startUs = trimStart.inMicroseconds;
    if (startUs >= sourceDurationUs) {
      return 0;
    }
    final endUs = trimEnd?.inMicroseconds ?? sourceDurationUs;
    final boundedEndUs = endUs < sourceDurationUs ? endUs : sourceDurationUs;
    final trimmedUs = boundedEndUs - startUs;
    if (trimmedUs <= 0) {
      return 0;
    }
    return trimmedUs / playbackSpeed / Duration.microsecondsPerSecond;
  }

  @override
  set duration(double value) {
    assert(value >= 0, 'duration must be >= 0');
    if (_overrideDuration == value) return;
    _overrideDuration = value;
    parent?.markNeedsLayout();
  }

  Duration _position = Duration.zero;
  final _log = Logger('RenderVideoClip');

  @override
  // so videos can be repainted independently
  bool get isRepaintBoundary => true;

  void onTick(Duration elapsed) {
    _position = elapsed;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    final uri = source.toNativeUtf8(allocator: calloc);
    _decoder ??= rina_decoder_open(
      Engine.instance.nativePtr,
      uri.cast(),
      TennojiHWAccel.TENNOJI_HW_ACCEL_AUTO,
    );
    calloc.free(uri);
    if (!_sourceDurationResolved && _decoder != null) {
      final durationUs = rina_decoder_duration(_decoder!);
      if (durationUs > 0) {
        _sourceDurationUs = durationUs;
        _sourceDurationResolved = true;
      }
    }
    if (!_ticker.isTicking) {
      _ticker.start();
    }
  }

  @override
  void detach() {
    if (_texture != null) {
      // ask the lib to call delete
      rina_texture_destroy(_texture!);
      _texture = null;
    }
    super.detach();
  }

  @override
  void dispose() {
    if (_audioSampleBuffer != null) {
      calloc.free(_audioSampleBuffer!);
      _audioSampleBuffer = null;
      _audioSampleBufferCapacity = 0;
      _audioOutputBuffer = null;
    }
    if (_decoder != null) {
      rina_decoder_close(_decoder!);
      _decoder = null;
    }
    _ticker.stop();
  }

  void _ensureAudioBuffers({
    required int nativeBufferFloats,
    required int outputBufferFloats,
  }) {
    if (_audioSampleBufferCapacity < nativeBufferFloats) {
      if (_audioSampleBuffer != null) {
        calloc.free(_audioSampleBuffer!);
      }
      _audioSampleBuffer = calloc<Float>(nativeBufferFloats);
      _audioSampleBufferCapacity = nativeBufferFloats;
    }
    final outputBuffer = _audioOutputBuffer;
    if (outputBuffer == null || outputBuffer.length != outputBufferFloats) {
      _audioOutputBuffer = Float32List(outputBufferFloats);
    }
  }

  @override
  void performLayout() {
    size = Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_decoder == null) return;
    final clipTime = _position - trimStart;

    final timeUs = (clipTime.inMicroseconds * playbackSpeed).toInt();

    // Release previous texture before acquiring a new one
    if (_texture != null && timeUs != _textureTimestamp) {
      rina_texture_destroy(_texture!);
    }

    if (timeUs != _textureTimestamp) {
      _texture = rina_decoder_get_texture(_decoder!, timeUs);
      _textureTimestamp = timeUs;
    }

    if (_texture != nullptr) {
      context.canvas.drawImageNative(_texture!, offset, Paint());
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) markNeedsPaint();
    });
  }

  @override
  Float32List? getOwnAudioForFrame(
    Duration frameTime,
    int sampleCount,
    int sampleRate,
  ) {
    if (_decoder == null) return null;

    final clipTime = frameTime - trimStart;

    // Check if we're within the clip bounds
    if (clipTime < Duration.zero) return null;
    if (trimEnd != null && clipTime > trimEnd!) return null;

    // Apply playback speed by adjusting sample count, not timestamp
    // For 2x speed, we need to read 2x samples; for 0.5x speed, 0.5x samples
    final adjustedSampleCount = (sampleCount * playbackSpeed).round();
    final timeUs = clipTime.inMicroseconds;
    final outputBufferSize = sampleCount * 2;
    final nativeBufferSize = adjustedSampleCount * 2;
    _ensureAudioBuffers(
      nativeBufferFloats: nativeBufferSize,
      outputBufferFloats: outputBufferSize,
    );

    final samplesRead = rina_decoder_read_audio_samples(
      _decoder!,
      timeUs,
      _audioSampleBuffer!,
      adjustedSampleCount,
      sampleRate,
    );

    if (samplesRead <= 0) {
      return null;
    }

    final output = _audioOutputBuffer!;
    final copiedFloats = math.min(samplesRead * 2, outputBufferSize);
    output.setRange(
      0,
      copiedFloats,
      _audioSampleBuffer!.asTypedList(copiedFloats),
    );
    if (copiedFloats < outputBufferSize) {
      output.fillRange(copiedFloats, outputBufferSize, 0.0);
    }
    return output;
  }
}

class RenderAudioClip extends RenderProxyBox with AudioContributor {
  RenderAudioClip({
    required this.source,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.volume = 1.0,
  });

  final String source;
  final Duration trimStart;
  final Duration? trimEnd;
  final double volume;
  double? _overrideDuration;
  int? _sourceDurationUs;
  bool _sourceDurationResolved = false;

  Pointer<TennojiDecoder>? _decoder;
  Pointer<Float>? _audioSampleBuffer;
  int _audioSampleBufferCapacity = 0;
  Float32List? _audioOutputBuffer;

  Pointer<TennojiDecoder>? get decoderPtr => _decoder;

  int? _resolveSourceDurationUs() {
    if (_sourceDurationResolved) {
      return _sourceDurationUs;
    }

    final decoder = _decoder;
    if (decoder != null) {
      final durationUs = rina_decoder_duration(decoder);
      if (durationUs > 0) {
        _sourceDurationUs = durationUs;
        _sourceDurationResolved = true;
        return durationUs;
      }
    }

    final uri = source.toNativeUtf8(allocator: calloc);
    final durationUs = rina_media_source_duration(
      Engine.instance.nativePtr,
      uri.cast(),
    );
    calloc.free(uri);
    _sourceDurationResolved = true;
    if (durationUs <= 0) {
      return null;
    }
    _sourceDurationUs = durationUs;
    return durationUs;
  }

  @override
  double get duration {
    final overrideDuration = _overrideDuration;
    if (overrideDuration != null) {
      return overrideDuration;
    }
    final sourceDurationUs = _resolveSourceDurationUs();
    if (sourceDurationUs == null) {
      return double.infinity;
    }
    final startUs = trimStart.inMicroseconds;
    if (startUs >= sourceDurationUs) {
      return 0;
    }
    final endUs = trimEnd?.inMicroseconds ?? sourceDurationUs;
    final boundedEndUs = endUs < sourceDurationUs ? endUs : sourceDurationUs;
    final trimmedUs = boundedEndUs - startUs;
    if (trimmedUs <= 0) {
      return 0;
    }
    return trimmedUs / Duration.microsecondsPerSecond;
  }

  @override
  set duration(double value) {
    assert(value >= 0, 'duration must be >= 0');
    if (_overrideDuration == value) return;
    _overrideDuration = value;
    parent?.onChildDurationUpdated(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    final uri = source.toNativeUtf8(allocator: calloc);
    _decoder = rina_decoder_open(
      Engine.instance.nativePtr,
      uri.cast(),
      TennojiHWAccel.TENNOJI_HW_ACCEL_AUTO,
    );
    calloc.free(uri);
    if (!_sourceDurationResolved && _decoder != null) {
      final durationUs = rina_decoder_duration(_decoder!);
      if (durationUs > 0) {
        _sourceDurationUs = durationUs;
        _sourceDurationResolved = true;
      }
    }

    print("Audio duration of $source set to $duration");
    parent?.onChildDurationUpdated(this);
  }

  @override
  void dispose() {
    if (_audioSampleBuffer != null) {
      calloc.free(_audioSampleBuffer!);
      _audioSampleBuffer = null;
      _audioSampleBufferCapacity = 0;
      _audioOutputBuffer = null;
    }
    if (_decoder != null) {
      rina_decoder_close(_decoder!);
      _decoder = null;
    }
    super.dispose();
  }

  void _ensureAudioBuffers(int sampleBufferFloats) {
    if (_audioSampleBufferCapacity < sampleBufferFloats) {
      if (_audioSampleBuffer != null) {
        calloc.free(_audioSampleBuffer!);
      }
      _audioSampleBuffer = calloc<Float>(sampleBufferFloats);
      _audioSampleBufferCapacity = sampleBufferFloats;
    }
    final outputBuffer = _audioOutputBuffer;
    if (outputBuffer == null || outputBuffer.length != sampleBufferFloats) {
      _audioOutputBuffer = Float32List(sampleBufferFloats);
    }
  }

  @override
  Float32List? getOwnAudioForFrame(
    Duration frameTime,
    int sampleCount,
    int sampleRate,
  ) {
    if (_decoder == null) return null;

    final clipTime = frameTime - trimStart;

    // Check if we're within the clip bounds
    if (clipTime < Duration.zero) return null;
    if (trimEnd != null && clipTime > trimEnd!) return null;

    final timeUs = clipTime.inMicroseconds;

    final sampleBufferSize = sampleCount * 2; // stereo
    _ensureAudioBuffers(sampleBufferSize);
    final samplesRead = rina_decoder_read_audio_samples(
      _decoder!,
      timeUs,
      _audioSampleBuffer!,
      sampleCount,
      sampleRate,
    );
    if (samplesRead <= 0) {
      return null;
    }

    final output = _audioOutputBuffer!;
    final copiedFloats = math.min(samplesRead * 2, sampleBufferSize);
    final inputView = _audioSampleBuffer!.asTypedList(copiedFloats);
    for (int i = 0; i < copiedFloats; i++) {
      output[i] = inputView[i] * volume;
    }
    if (copiedFloats < sampleBufferSize) {
      output.fillRange(copiedFloats, sampleBufferSize, 0.0);
    }
    return output;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) context.paintChild(child!, offset);
  }
}

// super.duration is the child's duration
class RenderRepeatAudio extends RenderProxyBox with AudioContributor {
  RenderRepeatAudio({int? repeatCount})
    : assert(repeatCount == null || repeatCount > 0),
      _repeatCount = repeatCount;

  double? _overrideDuration;

  int? _repeatCount;
  int? get repeatCount => _repeatCount;
  set repeatCount(int? value) {
    assert(value == null || value > 0);
    if (_repeatCount == value) return;
    _repeatCount = value;
    markNeedsLayout();
    parent?.markNeedsLayout();
  }

  @override
  double get duration {
    final overrideDuration = _overrideDuration;
    if (overrideDuration != null) {
      return overrideDuration;
    }
    final repeatCount = _repeatCount;
    if (repeatCount == null) {
      return double.infinity;
    }
    return super.duration * repeatCount;
  }

  @override
  set duration(double value) {
    assert(value >= 0, 'duration must be >= 0');
    if (_overrideDuration == value) return;
    _overrideDuration = value;
  }

  Duration? _attachedAt;

  Duration _resolveAttachTime(Duration frameTime) {
    final attachedAt = _attachedAt;
    if (attachedAt != null) {
      return attachedAt;
    }
    _attachedAt = frameTime;
    return frameTime;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _attachedAt = Engine.instance.currentTime;
  }

  @override
  void detach() {
    _attachedAt = null;
    super.detach();
  }

  @override
  Float32List? getAudioForFrame(
    Duration frameTime,
    int sampleCount,
    int sampleRate,
  ) {
    final attachedAt = _resolveAttachTime(frameTime);
    final elapsed = frameTime - attachedAt;
    if (elapsed < Duration.zero) {
      return null;
    }

    final activeDuration = duration;
    if (activeDuration.isFinite) {
      final activeDurationUs = (activeDuration * Duration.microsecondsPerSecond)
          .round();
      if (elapsed.inMicroseconds >= activeDurationUs) {
        return null;
      }
    }

    final loopedTimeUs =
        elapsed.inMicroseconds % (super.duration * 1000000).toInt();
    final loopedFrameTime = attachedAt + Duration(microseconds: loopedTimeUs);
    // print the loopedFrameTime and move cursor to beginning of this line
    final mixedSamples = collectSubtreeMixedAudioForFrame(
      loopedFrameTime,
      sampleCount,
      sampleRate,
    );
    if (mixedSamples == null) {
      return null;
    }
    return processMixedAudioForFrame(
      frameTime,
      sampleCount,
      sampleRate,
      mixedSamples,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) context.paintChild(child!, offset);
  }
}

class RenderVolumeAudio extends RenderProxyBox with AudioContributor {
  RenderVolumeAudio({double volume = 1.0})
    : assert(volume >= 0.0 && volume <= 1.0),
      _volume = volume;

  double _volume;
  double get volume => _volume;
  set volume(double value) {
    assert(value >= 0.0 && value <= 1.0);
    if (_volume == value) return;
    _volume = value;
    markNeedsLayout();
  }

  @override
  Float32List processMixedAudioForFrame(
    Duration frameTime,
    int sampleCount,
    int sampleRate,
    Float32List mixedSamples,
  ) {
    final volume = _volume;
    if (volume >= 1.0) {
      return mixedSamples;
    }
    if (volume <= 0.0) {
      mixedSamples.fillRange(0, mixedSamples.length, 0.0);
      return mixedSamples;
    }
    for (int i = 0; i < mixedSamples.length; i++) {
      mixedSamples[i] *= volume;
    }
    return mixedSamples;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) context.paintChild(child!, offset);
  }
}
