import 'package:barsource/src/painting/alignment.dart';
import 'package:barsource/src/painting/basic_types.dart';
import 'box.dart';
import 'object.dart';

export '../painting/alignment.dart';

class RenderAlign extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
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
    final parentConstraints = constraints;
    final bool shrinkWrapWidth =
        widthFactor != null || parentConstraints.maxWidth == double.infinity;
    final bool shrinkWrapHeight =
        heightFactor != null || parentConstraints.maxHeight == double.infinity;
    final bool hasChild = child != null;

    if (hasChild) {
      final child = this.child!;

      // Lay out the child with loose constraints.
      BoxConstraints childConstraints = parentConstraints.loosen();

      child.layout(childConstraints, parentUsesSize: true);

      // Size ourselves.
      size = parentConstraints.constrain(Size(
        shrinkWrapWidth
            ? child.size.width * (widthFactor ?? 1.0)
            : double.infinity,
        shrinkWrapHeight
            ? child.size.height * (heightFactor ?? 1.0)
            : double.infinity,
      ));

      // Position the child.
      _childOffset = resolvedAlignment.alongSize(size) - resolvedAlignment.alongSize(child.size);
    } else {
      size = parentConstraints.constrain(Size(
        shrinkWrapWidth ? 0 : double.infinity,
        shrinkWrapHeight ? 0 : double.infinity,
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

class RenderFractionallySizedBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  RenderFractionallySizedBox({
    AlignmentGeometry alignment = Alignment.center,
    double? widthFactor,
    double? heightFactor,
    TextDirection? textDirection,
  }) : _alignment = alignment,
       _widthFactor = widthFactor,
       _heightFactor = heightFactor,
       _textDirection = textDirection {
    assert(_widthFactor == null || _widthFactor! >= 0.0);
    assert(_heightFactor == null || _heightFactor! >= 0.0);
  }

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
    assert(value == null || value >= 0.0);
    if (_widthFactor == value) return;
    _widthFactor = value;
    markNeedsLayout();
  }

  double? get heightFactor => _heightFactor;
  double? _heightFactor;
  set heightFactor(double? value) {
    assert(value == null || value >= 0.0);
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

  BoxConstraints _getInnerConstraints(BoxConstraints constraints) {
    double minWidth = constraints.minWidth;
    double maxWidth = constraints.maxWidth;
    if (_widthFactor != null) {
      final double width = maxWidth * _widthFactor!;
      minWidth = width;
      maxWidth = width;
    }
    double minHeight = constraints.minHeight;
    double maxHeight = constraints.maxHeight;
    if (_heightFactor != null) {
      final double height = maxHeight * _heightFactor!;
      minHeight = height;
      maxHeight = height;
    }
    return BoxConstraints(
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight,
    );
  }

  @override
  void performLayout() {
    final Alignment resolvedAlignment = alignment.resolve(textDirection);
    if (child != null) {
      final BoxConstraints innerConstraints = _getInnerConstraints(constraints);
      child!.layout(innerConstraints, parentUsesSize: true);
      size = constraints.constrain(child!.size);
      _childOffset = resolvedAlignment.alongSize(size) - resolvedAlignment.alongSize(child!.size);
    } else {
      size = constraints.constrain(Size.zero);
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
