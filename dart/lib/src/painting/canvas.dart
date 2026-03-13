import 'dart:ffi';

import '../engine/bindings.dart';
import '../engine/engine.dart';
import '../foundation/geometry.dart';
import 'paint.dart';

/// Wrapper around native canvas handle.
class Canvas {
  Canvas(this._nativePtr);
  final Pointer<TennojiCanvas> _nativePtr;

  Pointer<TennojiCanvas> get nativePtr => _nativePtr;

  void clear(int color) {
    bindings.canvas_clear(_nativePtr, color);
  }

  void drawRect(Rect rect, Paint paint) {
    bindings.canvas_draw_rect(
      _nativePtr,
      rect.left,
      rect.top,
      rect.width,
      rect.height,
      paint.color.value,
    );
  }

  void drawImage(int textureId, Offset offset, Paint paint) {
    bindings.canvas_draw_image(
      _nativePtr,
      textureId,
      offset.dx,
      offset.dy,
    );
  }

  void save() {
    bindings.canvas_save(_nativePtr);
  }

  void restore() {
    bindings.canvas_restore(_nativePtr);
  }

  void translate(double dx, double dy) {
    bindings.canvas_translate(_nativePtr, dx, dy);
  }

  void scale(double sx, double sy) {
    bindings.canvas_scale(_nativePtr, sx, sy);
  }

  void rotate(double degrees) {
    bindings.canvas_rotate(_nativePtr, degrees);
  }

  void clipRect(Rect rect) {
    bindings.canvas_clip_rect(
      _nativePtr,
      rect.left,
      rect.top,
      rect.width,
      rect.height,
    );
  }

  /// Saves a new layer with the given [alpha] (0~255).
  /// Everything painted until the matching [restore] will be
  /// composited with that opacity.
  void saveLayer(int alpha) {
    bindings.canvas_save_layer(_nativePtr, alpha);
  }
}
