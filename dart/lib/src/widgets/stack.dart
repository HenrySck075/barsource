import 'package:barsource/src/dart_ui/dart_ui.dart';
import 'package:barsource/src/rendering/object.dart';

import '../rendering/stack_render.dart';
import 'basic.dart';
import 'framework.dart';

class Stack extends MultiChildRenderObjectWidget {
  const Stack({
    super.key,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.fit = StackFit.loose,
    this.clipBehavior = Clip.hardEdge,
    super.children,
  });

  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final StackFit fit;
  final Clip clipBehavior;

  @override
  RenderStack createRenderObject(BuildContext context) => RenderStack(
    alignment: alignment,
    textDirection: textDirection ?? Directionality.maybeOf(context),
    fit: fit,
    clipBehavior: clipBehavior,
  );

  @override
  void updateRenderObject(BuildContext context, RenderStack renderObject) {
    renderObject
      ..alignment = alignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context)
      ..fit = fit
      ..clipBehavior = clipBehavior;
  }
}

class Positioned extends ParentDataWidget<StackParentData> {
  Positioned({
    super.key,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    required super.child,
  }) : assert(left == null || right == null || width == null),
       assert(top == null || bottom == null || height == null);

  Positioned.fromRect({super.key, required Rect rect, required super.child})
    : left = rect.left,
      top = rect.top,
      right = null,
      bottom = null,
      width = rect.width,
      height = rect.height;

  Positioned.fromRelativeRect({
    super.key,
    required RelativeRect rect,
    required super.child,
  }) : left = rect.left,
       top = rect.top,
       right = rect.right,
       bottom = rect.bottom,
       width = null,
       height = null;

  Positioned.fill({
    super.key,
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
    required super.child,
  }) : width = null,
       height = null;

  Positioned.directional({
    super.key,
    required TextDirection textDirection,
    double? start,
    this.top,
    double? end,
    this.bottom,
    this.width,
    this.height,
    required super.child,
  }) : left = switch (textDirection) {
         TextDirection.rtl => end,
         TextDirection.ltr => start,
       },
       right = switch (textDirection) {
         TextDirection.rtl => start,
         TextDirection.ltr => end,
       },
       assert(start == null || end == null || width == null),
       assert(top == null || bottom == null || height == null);

  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final double? width;
  final double? height;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData;
    if (parentData is! StackParentData) {
      return;
    }

    var needsLayout = false;

    if (parentData.left != left) {
      parentData.left = left;
      needsLayout = true;
    }
    if (parentData.top != top) {
      parentData.top = top;
      needsLayout = true;
    }
    if (parentData.right != right) {
      parentData.right = right;
      needsLayout = true;
    }
    if (parentData.bottom != bottom) {
      parentData.bottom = bottom;
      needsLayout = true;
    }
    if (parentData.width != width) {
      parentData.width = width;
      needsLayout = true;
    }
    if (parentData.height != height) {
      parentData.height = height;
      needsLayout = true;
    }

    if (needsLayout) {
      renderObject.parent?.markNeedsLayout();
    }
  }
}

class PositionedDirectional extends StatelessWidget {
  const PositionedDirectional({
    super.key,
    this.start,
    this.top,
    this.end,
    this.bottom,
    this.width,
    this.height,
    required this.child,
  }) : assert(start == null || end == null || width == null),
       assert(top == null || bottom == null || height == null);

  final double? start;
  final double? top;
  final double? end;
  final double? bottom;
  final double? width;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    return Positioned.directional(
      textDirection: textDirection,
      start: start,
      top: top,
      end: end,
      bottom: bottom,
      width: width,
      height: height,
      child: child,
    );
  }
}
