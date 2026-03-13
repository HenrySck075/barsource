import '../foundation/geometry.dart';
import 'box.dart';
import 'object.dart';
import 'time_box.dart';

class RenderStack extends RenderBox with ContainerRenderObjectMixin {
  @override
  void performLayout() {
    final parentConstraints = constraints;
    double maxWidth = 0;
    double maxHeight = 0;
    for (final child in children) {
      if (parentConstraints is TimeBoxConstraints) {
        child.layout(TimeBoxConstraints(
          currentTime: parentConstraints.currentTime,
          minWidth: 0,
          maxWidth: parentConstraints.maxWidth,
          minHeight: 0,
          maxHeight: parentConstraints.maxHeight,
        ));
      } else {
        child.layout(BoxConstraints(
          minWidth: 0,
          maxWidth: parentConstraints.maxWidth,
          minHeight: 0,
          maxHeight: parentConstraints.maxHeight,
        ));
      }
      if (child.size.width > maxWidth) maxWidth = child.size.width;
      if (child.size.height > maxHeight) maxHeight = child.size.height;
    }
    size = Size(
      maxWidth.isFinite ? maxWidth : parentConstraints.maxWidth,
      maxHeight.isFinite ? maxHeight : parentConstraints.maxHeight,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(child, offset);
    }
  }
}
