import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../engine/bindings.dart';
import '../engine/engine.dart';
import '../foundation/geometry.dart';
import '../painting/paint.dart';
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
  int? _textureId;

  Pointer<TennojiDecoder>? get decoderPtr => _decoder;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    final uri = source.toNativeUtf8(allocator: calloc);
    _decoder = bindings.decoder_open(
      Engine.instance.nativePtr,
      uri.cast(),
      TennojiHWAccel.TENNOJI_HW_ACCEL_AUTO,
    );
    calloc.free(uri);
  }

  @override
  void detach() {
    if (_textureId != null) {
      bindings.texture_release(Engine.instance.nativePtr, _textureId!);
      _textureId = null;
    }
    if (_decoder != null) {
      bindings.decoder_close(_decoder!);
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
    if (_textureId != null) {
      bindings.texture_release(Engine.instance.nativePtr, _textureId!);
    }

    _textureId = bindings.decoder_get_texture(_decoder!, timeUs);

    if (_textureId != null && _textureId! >= 0) {
      context.canvas.drawImage(_textureId!, offset, Paint());
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
    _decoder = bindings.decoder_open(
      Engine.instance.nativePtr,
      uri.cast(),
      TennojiHWAccel.TENNOJI_HW_ACCEL_AUTO,
    );
    calloc.free(uri);
  }

  @override
  void detach() {
    if (_decoder != null) {
      bindings.decoder_close(_decoder!);
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
    // Audio is handled by the encoder via tennoji_encoder_write_audio,
    // not through the canvas paint path.
  }
}
