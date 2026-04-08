import 'package:barsource/src/painting/basic_types.dart';

import 'object.dart';

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
    performLayout();
    clearNeedsLayout();
  }

  void performLayout();
}

abstract class RenderProxyBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  @override
  void performLayout() {
    child?.layout(constraints);
    size = child?.size ?? Size(constraints.maxWidth, constraints.maxHeight);
  }
}
