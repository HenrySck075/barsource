import 'package:barsource/src/painting/basic_types.dart';
import 'package:meta/meta.dart';

import 'object.dart';

bool debugDoPaintSize = bool.fromEnvironment("barsource.debugPaintSize");

enum _IntrinsicDimension {
  minWidth, maxWidth,
  minHeight, maxHeight
}

abstract class RenderBox extends RenderObject {
  @override
  BoxConstraints get constraints => super.constraints as BoxConstraints;

  Size? _size;
  Size get size => _size??(throw StateError("RenderBox $runtimeType was not laid out"));
  set size(Size value) => _size = value;
  @override
  Rect get paintBounds => Offset.zero & size;

  @visibleForOverriding
  @protected
  double computeMinIntrinsicWidth(double height) => 0.0;

  @visibleForOverriding
  @protected
  double computeMaxIntrinsicWidth(double height) => 0.0;

  @visibleForOverriding
  @protected
  double computeMinIntrinsicHeight(double width) => 0.0;

  @visibleForOverriding
  @protected
  double computeMaxIntrinsicHeight(double width) => 0.0;

  double _larpIntrinsics(_IntrinsicDimension dimension, double value, double Function(double) computer) {
    assert(() {
      if (value < 0.0) {
        //throw FlutterError.fromParts(<DiagnosticsNode>[
          //ErrorSummary('The height argument to getMaxIntrinsicWidth was negative.'),
          //ErrorDescription('The argument to getMaxIntrinsicWidth must not be negative or null.'),
          //ErrorHint(
            //'If you perform computations on another height before passing it to '
            //'getMaxIntrinsicWidth, consider using math.max() or double.clamp() '
            //'to force the value into the valid range.',
          //),
        //]);
        // this assumes no idiot changes the order of the _IntrinsicDimension enum for no reason.
        final crossAxis = dimension.index < 2 ? "height" : "width";
        // sorry guys
        final getMinMaxIntrinsicAxis = "get${dimension.index%2==0?'Min':'Max'}Intrinsic${dimension.index<2?'Width':'Height'}";

        throw StateError("The $crossAxis argument to $getMinMaxIntrinsicAxis must not be negative.\n\nIf you perform computations on another $crossAxis before passing it to $getMinMaxIntrinsicAxis, consider using math.max() or double.clamp() to force the value into the valid range.");
      }
      return true;
    }());
    return computer(value);
  }

  @mustCallSuper
  double getMinIntrinsicHeight(double width) {
    return _larpIntrinsics(_IntrinsicDimension.minHeight, width, computeMinIntrinsicHeight);
  }

  @mustCallSuper
  double getMaxIntrinsicHeight(double width) {
    return _larpIntrinsics(_IntrinsicDimension.maxHeight, width, computeMaxIntrinsicHeight);
  }

  @mustCallSuper
  double getMinIntrinsicWidth(double height) {
    return _larpIntrinsics(_IntrinsicDimension.minWidth, height, computeMinIntrinsicWidth);
  }

  @mustCallSuper
  double getMaxIntrinsicWidth(double height) {
    return _larpIntrinsics(_IntrinsicDimension.maxWidth, height, computeMaxIntrinsicWidth);
  }

  @override
  void layout(covariant BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    super.layout(constraints, parentUsesSize: parentUsesSize);
  }

  @override
  void debugPaint(PaintingContext context, Offset offset) {
    debugPaintSize(context, offset); // just in case we do have anything else other than this call
  }

  void debugPaintSize(PaintingContext context, Offset offset) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF00FFFF);
    context.canvas.drawRect((offset & size).deflate(0.5), paint);
  }
}

abstract class RenderProxyBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  @override
  void performLayout() {
    child?.layout(constraints);
    size = child?.size ?? Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void onChildDurationUpdated(RenderObject child) {
    super.duration = child.duration;
    print("I hereby report this $runtimeType has a super.duration of ${super.duration} and the main duration of $duration");
  }
}
