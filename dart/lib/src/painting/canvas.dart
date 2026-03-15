import 'dart:ffi';

import 'package:tennoji/src/dart_ui/dart_ui.dart';

import 'package:tennoji/src/engine/bindings.dart';
import 'package:tennoji/src/engine/engine.dart';
//import 'package:tennoji/src/foundation/geometry.dart';

/// Wrapper around native canvas handle.
class Canvas {
  Canvas(this._nativePtr);
  final Pointer<TennojiCanvas> _nativePtr;

  Pointer<TennojiCanvas> get nativePtr => _nativePtr;

  void clear(int color) {
    tennoji_canvas_clear(_nativePtr, color);
  }

  void drawRect(Rect rect, Paint paint) {
    tennoji_canvas_draw_rect(
      _nativePtr,
      rect.left,
      rect.top,
      rect.width,
      rect.height,
      paint.color.toARGB32(),
    );
  }

  void drawImage(Pointer<TennojiCanvasImage> texture, Offset offset, Paint paint) {
    tennoji_canvas_draw_image(
      _nativePtr,
      texture,
      offset.dx,
      offset.dy,
    );
  }

  void save() {
    tennoji_canvas_save(_nativePtr);
  }

  void restore() {
    tennoji_canvas_restore(_nativePtr);
  }

  void translate(double dx, double dy) {
    tennoji_canvas_translate(_nativePtr, dx, dy);
  }

  void scale(double sx, double sy) {
    tennoji_canvas_scale(_nativePtr, sx, sy);
  }

  void rotate(double degrees) {
    tennoji_canvas_rotate(_nativePtr, degrees);
  }

  void clipRect(Rect rect) {
    tennoji_canvas_clip_rect(
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
    tennoji_canvas_save_layer(_nativePtr, alpha);
  }
}
