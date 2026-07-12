import 'package:barsource/foundation.dart';
import 'package:barsource/src/painting/basic_types.dart';

abstract class CustomClipper<T> extends Listenable {
  const CustomClipper({
    this._reclip,
  });

  final Listenable? _reclip;

  @override
  void addListener(VoidCallback listener) {
    _reclip?.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _reclip?.removeListener(listener);
  }


  /// Returns a description of the clip given that the render object being
  /// clipped is of the given size.
  T getClip(Size size);

  /// Returns an approximation of the clip returned by [getClip], as
  /// an axis-aligned Rect. This is used by the semantics layer to
  /// determine whether widgets should be excluded.
  ///
  /// By default, this returns a rectangle that is the same size as
  /// the RenderObject. If getClip returns a shape that is roughly the
  /// same size as the RenderObject (e.g. it's a rounded rectangle
  /// with very small arcs in the corners), then this may be adequate.
  Rect getApproximateClipRect(Size size) => Offset.zero & size;

  /// Called whenever a new instance of the custom clipper delegate class is
  /// provided to the clip object, or any time that a new clip object is created
  /// with a new instance of the custom clipper delegate class (which amounts to
  /// the same thing, because the latter is implemented in terms of the former).
  ///
  /// If the new instance represents different information than the old
  /// instance, then the method should return true, otherwise it should return
  /// false.
  ///
  /// If the method returns false, then the [getClip] call might be optimized
  /// away.
  ///
  /// It's possible that the [getClip] method will get called even if
  /// [shouldReclip] returns false or if the [shouldReclip] method is never
  /// called at all (e.g. if the box changes size).
  bool shouldReclip(covariant CustomClipper<T> oldClipper);

  @override
  String toString() => objectRuntimeType(this, 'CustomClipper');
}
