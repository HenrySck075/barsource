import 'package:meta/meta.dart';
import 'package:tennoji/src/dart_ui/dart_ui.dart';
import 'package:tennoji/src/foundation/debug.dart';

import '../foundation/geometry.dart';
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
    return RelativeRect.fromLTRB(left - delta, top - delta, right - delta, bottom - delta);
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
    return Rect.fromLTRB(left, top, container.width - right, container.height - bottom);
  }

  Size toSize(Size container) {
    return Size(container.width - left - right, container.height - top - bottom);
  }

  static RelativeRect? lerp(RelativeRect? a, RelativeRect? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return RelativeRect.fromLTRB(b!.left * t, b.top * t, b.right * t, b.bottom * t);
    }
    if (b == null) {
      final double k = 1.0 - t;
      return RelativeRect.fromLTRB(b!.left * k, b.top * k, b.right * k, b.bottom * k);
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
      (final double left?, final double right?) => stackSize.width - right - left,
      (_, _) => this.width,
    };

    final double? height = switch ((top, bottom)) {
      (final double top?, final double bottom?) => stackSize.height - bottom - top,
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
class RenderStack extends RenderBox with ContainerRenderObjectMixin<RenderBox,ContainerParentDataMixin<RenderBox>> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! StackParentData) {
      child.parentData = StackParentData();
    }
  }
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
