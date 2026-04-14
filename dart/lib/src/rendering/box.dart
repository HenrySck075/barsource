import 'package:barsource/src/painting/basic_types.dart';

import 'object.dart';

bool debugDoPaintSize = bool.fromEnvironment("barsource.debugPaintSize");

abstract class RenderBox extends RenderObject {
  @override
  BoxConstraints get constraints => super.constraints as BoxConstraints;

  Size? _size;
  Size get size => _size??(throw StateError("RenderBox $runtimeType was not laid out"));
  set size(Size value) => _size = value;
  @override
  Rect get paintBounds => Offset.zero & size;
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
}
