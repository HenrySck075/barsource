import 'package:meta/meta.dart';
import 'package:barsource/src/dart_ui/dart_ui.dart';
import 'package:barsource/src/foundation/debug.dart';
import 'package:barsource/src/painting/alignment.dart';

import 'box.dart';
import 'object.dart';
import 'dart:math' as math;

@immutable
class RelativeRect {
  const RelativeRect.fromLTRB(this.left, this.top, this.right, this.bottom);

  RelativeRect.fromSize(Rect rect, Size container)
    : left = rect.left,
      top = rect.top,
      right = container.width - rect.right,
      bottom = container.height - rect.bottom;

  RelativeRect.fromRect(Rect rect, Rect container)
    : left = rect.left - container.left,
      top = rect.top - container.top,
      right = container.right - rect.right,
      bottom = container.bottom - rect.bottom;

  factory RelativeRect.fromDirectional({
    required TextDirection textDirection,
    required double start,
    required double top,
    required double end,
    required double bottom,
  }) {
    final (double left, double right) = switch (textDirection) {
      TextDirection.rtl => (end, start),
      TextDirection.ltr => (start, end),
    };
    return RelativeRect.fromLTRB(left, top, right, bottom);
  }

  static const RelativeRect fill = RelativeRect.fromLTRB(0.0, 0.0, 0.0, 0.0);

  final double left;

  final double top;

  final double right;

  final double bottom;

  bool get hasInsets => left > 0.0 || top > 0.0 || right > 0.0 || bottom > 0.0;

  RelativeRect shift(Offset offset) {
    return RelativeRect.fromLTRB(
      left + offset.dx,
      top + offset.dy,
      right - offset.dx,
      bottom - offset.dy,
    );
  }

  RelativeRect inflate(double delta) {
    return RelativeRect.fromLTRB(
      left - delta,
      top - delta,
      right - delta,
      bottom - delta,
    );
  }

  RelativeRect deflate(double delta) {
    return inflate(-delta);
  }

  RelativeRect intersect(RelativeRect other) {
    return RelativeRect.fromLTRB(
      math.max(left, other.left),
      math.max(top, other.top),
      math.max(right, other.right),
      math.max(bottom, other.bottom),
    );
  }

  Rect toRect(Rect container) {
    return Rect.fromLTRB(
      left,
      top,
      container.width - right,
      container.height - bottom,
    );
  }

  Size toSize(Size container) {
    return Size(
      container.width - left - right,
      container.height - top - bottom,
    );
  }

  static RelativeRect? lerp(RelativeRect? a, RelativeRect? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return RelativeRect.fromLTRB(
        b!.left * t,
        b.top * t,
        b.right * t,
        b.bottom * t,
      );
    }
    if (b == null) {
      final double k = 1.0 - t;
      return RelativeRect.fromLTRB(
        b!.left * k,
        b.top * k,
        b.right * k,
        b.bottom * k,
      );
    }
    return RelativeRect.fromLTRB(
      lerpDouble(a.left, b.left, t)!,
      lerpDouble(a.top, b.top, t)!,
      lerpDouble(a.right, b.right, t)!,
      lerpDouble(a.bottom, b.bottom, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RelativeRect &&
        other.left == left &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() =>
      'RelativeRect.fromLTRB(${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, ${right.toStringAsFixed(1)}, ${bottom.toStringAsFixed(1)})';
}

class StackParentData extends ContainerBoxParentData<RenderBox> {
  double? top;

  double? right;

  double? bottom;

  double? left;

  double? width;

  double? height;

  RelativeRect get rect => RelativeRect.fromLTRB(left!, top!, right!, bottom!);
  set rect(RelativeRect value) {
    top = value.top;
    right = value.right;
    bottom = value.bottom;
    left = value.left;
  }

  bool get isPositioned =>
      top != null ||
      right != null ||
      bottom != null ||
      left != null ||
      width != null ||
      height != null;

  BoxConstraints positionedChildConstraints(Size stackSize) {
    assert(isPositioned);
    final double? width = switch ((left, right)) {
      (final double left?, final double right?) =>
        stackSize.width - right - left,
      (_, _) => this.width,
    };

    final double? height = switch ((top, bottom)) {
      (final double top?, final double bottom?) =>
        stackSize.height - bottom - top,
      (_, _) => this.height,
    };
    assert(height == null || !height.isNaN);
    assert(width == null || !width.isNaN);
    return BoxConstraints.tightFor(
      width: width == null ? null : math.max(0.0, width),
      height: height == null ? null : math.max(0.0, height),
    );
  }

  @override
  String toString() {
    final values = <String>[
      if (top != null) 'top=${debugFormatDouble(top)}',
      if (right != null) 'right=${debugFormatDouble(right)}',
      if (bottom != null) 'bottom=${debugFormatDouble(bottom)}',
      if (left != null) 'left=${debugFormatDouble(left)}',
      if (width != null) 'width=${debugFormatDouble(width)}',
      if (height != null) 'height=${debugFormatDouble(height)}',
    ];
    if (values.isEmpty) {
      values.add('not positioned');
    }
    values.add(super.toString());
    return values.join('; ');
  }
}

enum StackFit { loose, expand, passthrough }

class RenderStack extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, StackParentData> {
  RenderStack({
    AlignmentGeometry alignment = AlignmentDirectional.topStart,
    TextDirection? textDirection,
    StackFit fit = StackFit.loose,
    Clip clipBehavior = Clip.hardEdge,
  }) : _alignment = alignment,
       _textDirection = textDirection,
       _fit = fit,
       _clipBehavior = clipBehavior;

  AlignmentGeometry get alignment => _alignment;
  AlignmentGeometry _alignment;
  set alignment(AlignmentGeometry value) {
    if (_alignment == value) {
      return;
    }
    _alignment = value;
    markNeedsLayout();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  StackFit get fit => _fit;
  StackFit _fit;
  set fit(StackFit value) {
    if (_fit == value) {
      return;
    }
    _fit = value;
    markNeedsLayout();
  }

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    if (_clipBehavior == value) {
      return;
    }
    _clipBehavior = value;
    markNeedsPaint();
  }

  bool _hasVisualOverflow = false;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! StackParentData) {
      child.parentData = StackParentData();
    }
  }

  BoxConstraints _nonPositionedConstraints(BoxConstraints constraints) {
    return switch (fit) {
      StackFit.loose => constraints.loosen(),
      StackFit.expand => BoxConstraints.tight(constraints.biggest),
      StackFit.passthrough => constraints,
    };
  }

  Offset _resolvedOffset(Alignment resolvedAlignment, Size childSize) {
    return resolvedAlignment.alongOffset(
      Offset(size.width - childSize.width, size.height - childSize.height),
    );
  }

  void _setChildOffset(
    StackParentData parentData,
    RenderBox child,
    Alignment resolvedAlignment,
  ) {
    final x = switch ((parentData.left, parentData.right)) {
      (final double left?, _) => left,
      (_, final double right?) => size.width - right - child.size.width,
      _ => _resolvedOffset(resolvedAlignment, child.size).dx,
    };

    final y = switch ((parentData.top, parentData.bottom)) {
      (final double top?, _) => top,
      (_, final double bottom?) => size.height - bottom - child.size.height,
      _ => _resolvedOffset(resolvedAlignment, child.size).dy,
    };

    parentData.offset = Offset(x, y);
    _hasVisualOverflow =
        _hasVisualOverflow ||
        x < 0.0 ||
        y < 0.0 ||
        x + child.size.width > size.width ||
        y + child.size.height > size.height;
  }

  @override
  void performLayout() {
    final parentConstraints = constraints;
    final nonPositionedConstraints = _nonPositionedConstraints(
      parentConstraints,
    );
    var maxWidth = parentConstraints.minWidth;
    var maxHeight = parentConstraints.minHeight;
    var hasNonPositionedChildren = false;
    _hasVisualOverflow = false;

    for (
      RenderBox? child = firstChild;
      child != null;
      child = childAfter(child)
    ) {
      final childParentData = child.parentData! as StackParentData;
      if (childParentData.isPositioned) {
        continue;
      }
      hasNonPositionedChildren = true;
      child.layout(nonPositionedConstraints, parentUsesSize: true);
      maxWidth = math.max(maxWidth, child.size.width);
      maxHeight = math.max(maxHeight, child.size.height);
    }

    size = hasNonPositionedChildren
        ? parentConstraints.constrain(Size(maxWidth, maxHeight))
        : parentConstraints.biggest;
    final resolvedAlignment = alignment.resolve(textDirection);

    for (
      RenderBox? child = firstChild;
      child != null;
      child = childAfter(child)
    ) {
      final childParentData = child.parentData! as StackParentData;
      if (!childParentData.isPositioned) {
        continue;
      }
      child.layout(
        childParentData.positionedChildConstraints(size),
        parentUsesSize: true,
      );
      _setChildOffset(childParentData, child, resolvedAlignment);
    }

    for (
      RenderBox? child = firstChild;
      child != null;
      child = childAfter(child)
    ) {
      final childParentData = child.parentData! as StackParentData;
      if (childParentData.isPositioned) {
        continue;
      }
      childParentData.offset = _resolvedOffset(resolvedAlignment, child.size);
      _hasVisualOverflow =
          _hasVisualOverflow ||
          childParentData.offset.dx < 0.0 ||
          childParentData.offset.dy < 0.0 ||
          childParentData.offset.dx + child.size.width > size.width ||
          childParentData.offset.dy + child.size.height > size.height;
    }
  }

  void _paintStack(PaintingContext context, Offset offset) {
    for (
      RenderBox? child = firstChild;
      child != null;
      child = childAfter(child)
    ) {
      final childParentData = child.parentData! as StackParentData;
      context.paintChild(
        child,
        Offset(
          offset.dx + childParentData.offset.dx,
          offset.dy + childParentData.offset.dy,
        ),
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hasVisualOverflow || clipBehavior == Clip.none) {
      _paintStack(context, offset);
      return;
    }

    context.canvas.save();
    context.canvas.clipRect(offset & size, clipBehavior == Clip.antiAlias);
    _paintStack(context, offset);
    context.canvas.restore();
  }
}
