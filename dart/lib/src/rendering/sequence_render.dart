import '../foundation/geometry.dart';
import 'object.dart';
import 'time_box.dart';

class RenderSequence extends RenderTimeBox with ContainerRenderObjectMixin {
  @override
  void performLayout() {
    Duration elapsed = Duration.zero;
    for (final child in children) {
      if (child is RenderTimeBox) {
        child.layout(TimeBoxConstraints(
          currentTime: constraints.currentTime - elapsed,
          minWidth: constraints.minWidth,
          maxWidth: constraints.maxWidth,
          minHeight: constraints.minHeight,
          maxHeight: constraints.maxHeight,
        ));
        // elapsed += child.duration; // children would expose duration
      }
    }
    size = Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Find active child at currentTime, paint only that one
    for (final child in children) {
      context.paintChild(child, offset);
    }
  }
}
