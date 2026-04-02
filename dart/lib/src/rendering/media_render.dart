import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:tennoji/src/dart_ui/dart_ui.dart';
import 'package:tennoji/src/rendering/box.dart';

import '../engine/engine.dart';
import 'object.dart';
import 'pipeline_owner.dart';

class RenderVideoClip extends RenderBox implements AudioContributor {
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

  Pointer<TennojiDecoder>? _decoder;
  Pointer<TennojiCanvasImage>? _texture;
  int? _textureTimestamp;

  Pointer<TennojiDecoder>? get decoderPtr => _decoder;

  Duration _position = Duration.zero;
  final _log = Logger('RenderVideoClip');

  void onTick(Duration elapsed) {
    _position = elapsed;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    Engine.instance.registerAudioContributor(this);
    final uri = source.toNativeUtf8(allocator: calloc);
    _decoder ??= rina_decoder_open(
      Engine.instance.nativePtr,
      uri.cast(),
      TennojiHWAccel.TENNOJI_HW_ACCEL_AUTO,
    );
    calloc.free(uri);
    // Audio is now handled via AudioContributor interface
    print(!_ticker.isTicking);
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
    Engine.instance.unregisterAudioContributor(this);
    super.detach();
    // TODO: we could also let user specify if playback is stopped if the object is detached
  }

  @override
  void dispose() {
    if (_decoder != null) {
      rina_decoder_close(_decoder!);
      _decoder = null;
    }
    _ticker.stop();
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

    _texture = rina_decoder_get_texture(_decoder!, timeUs);
    _textureTimestamp = timeUs;

    if (_texture != nullptr) {
      context.canvas.drawImageNative(_texture!, offset, Paint());
    } else {
      _texture = null;
    }
  }

  @override
  Float32List? getAudioForFrame(Duration frameTime, int sampleCount, int sampleRate) {
    if (_decoder == null) return null;

    final clipTime = frameTime - trimStart;
    
    // Check if we're within the clip bounds
    if (clipTime < Duration.zero) return null;
    if (trimEnd != null && clipTime > trimEnd!) return null;

    // Apply playback speed by adjusting sample count, not timestamp
    // For 2x speed, we need to read 2x samples; for 0.5x speed, 0.5x samples
    final adjustedSampleCount = (sampleCount * playbackSpeed).round();
    final timeUs = clipTime.inMicroseconds;

    // Allocate buffer for interleaved stereo samples
    final sampleBufferSize = adjustedSampleCount * 2; // stereo
    final sampleBuffer = calloc<Float>(sampleBufferSize);

    try {
      final samplesRead = rina_decoder_read_audio_samples(
        _decoder!,
        timeUs,
        sampleBuffer,
        adjustedSampleCount,
        sampleRate,
      );

      if (samplesRead <= 0) {
        // No audio available - return null (silence will be filled by engine)
        return null;
      }

      // Copy to Float32List (only the samples that were actually read)
      final result = Float32List(samplesRead * 2);
      for (int i = 0; i < samplesRead * 2; i++) {
        result[i] = sampleBuffer[i];
      }

      return result;
    } finally {
      calloc.free(sampleBuffer);
    }
  }
}

class RenderAudioClip extends RenderBox implements AudioContributor {
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

  Pointer<TennojiDecoder>? _decoder;

  Pointer<TennojiDecoder>? get decoderPtr => _decoder;

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
    // Audio is now handled via AudioContributor interface
  }

  @override
  void detach() {
    if (_decoder != null) {
      rina_decoder_close(_decoder!);
      _decoder = null;
    }
    super.detach();
  }

  @override
  void performLayout() {
    size = Size.zero;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Audio is handled by the encoder via getAudioForFrame,
    // not through the canvas paint path.
  }

  @override
  Float32List? getAudioForFrame(Duration frameTime, int sampleCount, int sampleRate) {
    if (_decoder == null) return null;

    final clipTime = frameTime - trimStart;
    
    // Check if we're within the clip bounds
    if (clipTime < Duration.zero) return null;
    if (trimEnd != null && clipTime > trimEnd!) return null;

    final timeUs = clipTime.inMicroseconds;

    // Allocate buffer for interleaved stereo samples
    final sampleBufferSize = sampleCount * 2; // stereo
    final sampleBuffer = calloc<Float>(sampleBufferSize);

    try {
      final samplesRead = rina_decoder_read_audio_samples(
        _decoder!,
        timeUs,
        sampleBuffer,
        sampleCount,
        sampleRate,
      );

      if (samplesRead <= 0) {
        return null;
      }

      // Copy to Float32List and apply volume
      final result = Float32List(samplesRead * 2);
      for (int i = 0; i < samplesRead * 2; i++) {
        result[i] = sampleBuffer[i] * volume;
      }

      return result;
    } finally {
      calloc.free(sampleBuffer);
    }
  }
}
