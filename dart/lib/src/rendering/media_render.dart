import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:tennoji/src/dart_ui/dart_ui.dart';

import '../engine/engine.dart';
import 'object.dart';
import 'pipeline_owner.dart';
import 'time_box.dart';

class RenderVideoClip extends RenderTimeBox {
  RenderVideoClip({
    required this.source,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.playbackSpeed = 1.0,
  });

  final String source;
  final Duration trimStart;
  final Duration? trimEnd;
  final double playbackSpeed;

  Pointer<TennojiDecoder>? _decoder;
  Pointer<TennojiCanvasImage>? _texture;

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
      Engine.instance.registerAudioDecoder(_decoder!);
    }
  }

  @override
  void detach() {
    if (_texture != null) {
      // ask the lib to call delete
      rina_texture_destroy(_texture!);
      _texture = null;
    }
    if (_decoder != null) {
      Engine.instance.unregisterAudioDecoder(_decoder!);
      rina_decoder_close(_decoder!);
      _decoder = null;
    }
    super.detach();
  }

  @override
  void performLayout() {
    size = Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_decoder == null) return;
    final clipTime = constraints.currentTime - trimStart;
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

class RenderAudioClip extends RenderTimeBox {
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
