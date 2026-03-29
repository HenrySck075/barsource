import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:tennoji/src/dart_ui/dart_ui.dart';
import 'package:tennoji/src/rendering/box.dart';

import '../engine/engine.dart';
import 'object.dart';
import 'pipeline_owner.dart';

class RenderVideoClip extends RenderBox {
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

  Pointer<TennojiDecoder>? get decoderPtr => _decoder;

  Duration _position = Duration.zero;

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
    if (_decoder != null) {
      Engine.instance.registerAudioDecoder(_decoder!);
    }
    if (!_ticker.isTicking) _ticker.start();
  }

  @override
  void detach() {
    if (_texture != null) {
      // ask the lib to call delete
      rina_texture_destroy(_texture!);
      _texture = null;
    }
    super.detach();
    // TODO: we could also let user specify if playback is stopped if the object is detached
  }

  @override
  void dispose() {
    if (_decoder != null) {
      Engine.instance.unregisterAudioDecoder(_decoder!);
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
    if (_texture != null) {
      rina_texture_destroy(_texture!);
    }

    _texture = rina_decoder_get_texture(_decoder!, timeUs);

    if (_texture != nullptr) {
      context.canvas.drawImage(_texture!, offset, Paint());
    } else {
      _texture = null;
    }
  }
}

class RenderAudioClip extends RenderBox {
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
    if (_decoder != null) {
      Engine.instance.registerAudioDecoder(_decoder!, needsManualRead: true);
    }
  }

  @override
  void detach() {
    if (_decoder != null) {
      Engine.instance.unregisterAudioDecoder(_decoder!);
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
    // Audio is handled by the encoder via rina_encoder_write_audio,
    // not through the canvas paint path.
  }
}
