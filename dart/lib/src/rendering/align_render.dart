import '../foundation/geometry.dart';
import 'box.dart';
import 'object.dart';
import 'time_box.dart';

/// An alignment along both axes, where (0, 0) is center,
/// (-1, -1) is top-left, and (1, 1) is bottom-right.
class Alignment {
  const Alignment(this.x, this.y);
  final double x;
  final double y;

  static const Alignment topLeft = Alignment(-1, -1);
  static const Alignment topCenter = Alignment(0, -1);
  static const Alignment topRight = Alignment(1, -1);
  static const Alignment centerLeft = Alignment(-1, 0);
  static const Alignment center = Alignment(0, 0);
  static const Alignment centerRight = Alignment(1, 0);
  static const Alignment bottomLeft = Alignment(-1, 1);
  static const Alignment bottomCenter = Alignment(0, 1);
  static const Alignment bottomRight = Alignment(1, 1);

  /// Computes the offset for a child of [childSize] within a container
  /// of [containerSize].
  Offset alongOffset(Size containerSize, Size childSize) {
    final double dx =
        (containerSize.width - childSize.width) * ((x + 1) / 2);
    final double dy =
        (containerSize.height - childSize.height) * ((y + 1) / 2);
    return Offset(dx, dy);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Alignment && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Alignment($x, $y)';
}

class RenderAlign extends RenderBox with ContainerRenderObjectMixin {
  RenderAlign({
    this.alignment = Alignment.center,
    this.widthFactor,
    this.heightFactor,
  });

  final Alignment alignment;
  final double? widthFactor;
  final double? heightFactor;

  Offset _childOffset = Offset.zero;

  @override
  void performLayout() {
    final bool hasChild = children.isNotEmpty;

    if (hasChild) {
      final child = children.first;

      // Lay out the child with loose constraints.
      final parentConstraints = constraints;
      BoxConstraints childConstraints;

      if (parentConstraints is TimeBoxConstraints) {
        childConstraints = TimeBoxConstraints(
          currentTime: parentConstraints.currentTime,
          maxWidth: parentConstraints.maxWidth,
          maxHeight: parentConstraints.maxHeight,
        );
      } else {
        childConstraints = parentConstraints.loosen();
      }

      child.layout(childConstraints, parentUsesSize: true);

      // Size ourselves.
      size = constraints.constrain(Size(
        widthFactor != null
            ? child.size.width * widthFactor!
            : double.infinity,
        heightFactor != null
            ? child.size.height * heightFactor!
            : double.infinity,
      ));

      // Position the child.
      _childOffset = alignment.alongOffset(size, child.size);
    } else {
      size = constraints.constrain(Size(
        widthFactor != null ? 0 : double.infinity,
        heightFactor != null ? 0 : double.infinity,
      ));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (children.isNotEmpty) {
      context.paintChild(children.first, Offset(
        offset.dx + _childOffset.dx,
        offset.dy + _childOffset.dy,
      ));
    }
  }
}
