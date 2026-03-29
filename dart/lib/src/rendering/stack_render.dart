import '../foundation/geometry.dart';
import 'box.dart';
import 'object.dart';

// todo: positioned parent data
class RenderStack extends RenderBox with ContainerRenderObjectMixin<RenderBox,ContainerParentDataMixin<RenderBox>> {
  @override
  void performLayout() {
    final parentConstraints = constraints;
    double maxWidth = 0;
    double maxHeight = 0;
    visitChildren((child) {
      child.layout(BoxConstraints(
        minWidth: 0,
        maxWidth: parentConstraints.maxWidth,
        minHeight: 0,
        maxHeight: parentConstraints.maxHeight,
      ));
      if (child.size.width > maxWidth) maxWidth = child.size.width;
      if (child.size.height > maxHeight) maxHeight = child.size.height;
    });
    size = Size(
      maxWidth.isFinite ? maxWidth : parentConstraints.maxWidth,
      maxHeight.isFinite ? maxHeight : parentConstraints.maxHeight,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    visitChildren((child) {
      context.paintChild(child, offset);
    });
  }
}
