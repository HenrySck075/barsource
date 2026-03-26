import 'package:tennoji/src/painting/basic_types.dart';

import 'package:tennoji/src/painting/alignment.dart';
import 'box.dart';
import 'object.dart';

export '../painting/alignment.dart';

class RenderAlign extends RenderBox with RenderObjectWithChildMixin {
  RenderAlign({
    AlignmentGeometry alignment = Alignment.center,
    double? widthFactor,
    double? heightFactor,
    TextDirection? textDirection,
  }) : _alignment = alignment,
       _widthFactor = widthFactor,
       _heightFactor = heightFactor,
       _textDirection = textDirection;

  AlignmentGeometry get alignment => _alignment;
  AlignmentGeometry _alignment;
  set alignment(AlignmentGeometry value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsLayout();
  }

  double? get widthFactor => _widthFactor;
  double? _widthFactor;
  set widthFactor(double? value) {
    if (_widthFactor == value) return;
    _widthFactor = value;
    markNeedsLayout();
  }

  double? get heightFactor => _heightFactor;
  double? _heightFactor;
  set heightFactor(double? value) {
    if (_heightFactor == value) return;
    _heightFactor = value;
    markNeedsLayout();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  Offset _childOffset = Offset.zero;

  @override
  void performLayout() {
    final Alignment resolvedAlignment = alignment.resolve(textDirection);
    final bool hasChild = child != null;

    if (hasChild) {
      final child = this.child!;

      // Lay out the child with loose constraints.
      final parentConstraints = constraints;
      BoxConstraints childConstraints = parentConstraints.loosen();

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
      _childOffset = resolvedAlignment.alongOffset(size, child.size);
    } else {
      size = constraints.constrain(Size(
        widthFactor != null ? 0 : double.infinity,
        heightFactor != null ? 0 : double.infinity,
      ));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, Offset(
        offset.dx + _childOffset.dx,
        offset.dy + _childOffset.dy,
      ));
    }
  }
}
