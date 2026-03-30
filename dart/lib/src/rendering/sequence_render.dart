import 'package:tennoji/src/rendering/box.dart';

import '../foundation/geometry.dart';
import 'object.dart';
import 'timeline_parent_data.dart';

class RenderSequence extends RenderBox with ContainerRenderObjectMixin<RenderBox, TimelineParentData> {
  
  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! TimelineParentData) {
      child.parentData = TimelineParentData();
    }
  }

  RenderBox? activeChild;
  // if true, [performLayout] wont attempt to set activeChild when its null
  bool _sequenceCompleted = false;

  @override
  void performLayout() {
    visitChildren((child) {
      // this assigns the active child to the first object
      if (!_sequenceCompleted) activeChild ??= child;
      child.layout(BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
        minHeight: constraints.minHeight,
        maxHeight: constraints.maxHeight,
      ));
    });
    _stealActiveChildLayout();
  }

  void nextObject() {
    activeChild = childAfter(activeChild!);
    _sequenceCompleted = activeChild == null;
    markNeedsLayout();
    //markNeedsPaint();
  }

  void _stealActiveChildLayout() {
    // steal the active child layout, so that it can be used for the parent
    if (activeChild != null) {
      size = Size(activeChild!.size.width, activeChild!.size.height);
    } else {
      size = Size.zero;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Find active child at currentTime, paint only that one
    context.paintChild(activeChild!, offset);
  }
}
