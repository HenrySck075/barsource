import 'package:tennoji/src/rendering/box.dart';

import '../foundation/geometry.dart';
import 'object.dart';
import 'timeline_parent_data.dart';

class RenderSequence extends RenderBox with ContainerRenderObjectMixin {
  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! TimelineParentData) {
      child.parentData = TimelineParentData();
    }
  }

  RenderBox? activeChild;

  @override
  void performLayout() {
    visitChildren((child) {
      child.layout(BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
        minHeight: constraints.minHeight,
        maxHeight: constraints.maxHeight,
      ));
    });
    size = Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Find active child at currentTime, paint only that one
    context.paintChild(activeChild!, offset);
  }
}
