import 'package:tennoji/src/rendering/box.dart';
import 'package:tennoji/src/rendering/pipeline_owner.dart';

import '../animation/animation.dart';
import '../foundation/geometry.dart';
import 'object.dart';

// ---------------------------------------------------------------------------
// RenderAnimatedOpacity
// ---------------------------------------------------------------------------

/// A render object that fades its single child using a [AnimationController].
///
/// Evaluates the animation at the current timeline time and applies the
/// resulting opacity (0.0 transparent → 1.0 opaque) via [Canvas.saveLayer].
class RenderAnimatedOpacity extends RenderBox
    with RenderObjectWithChildMixin {
  RenderAnimatedOpacity({
    required this.opacity,
  });

  final Animation<double> opacity;

  @override
  void performLayout() {
    child?.layout(constraints);
    size = child?.size ?? Size(constraints.maxWidth, constraints.maxHeight);
  }

  void _onOpacityUpdate() {
    markNeedsPaint();
  }

  @override
    void attach(PipelineOwner owner) {
      opacity.addListener(_onOpacityUpdate);
      super.attach(owner);
    }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final t = opacity.value;
    final alpha = (opacity.transform(t).clamp(0.0, 1.0) * 255).round();
    if (alpha <= 0) return;
    if (alpha >= 255) {
      context.paintChild(child!, offset);
      return;
    }
    context.canvas.saveLayer(alpha);
    context.paintChild(child!, offset);
    context.canvas.restore();
  }
}

// ---------------------------------------------------------------------------
// RenderAnimatedTranslation
// ---------------------------------------------------------------------------

/// A render object that translates its single child using a [AnimationController].
///
/// The [offset] tween produces fractional offsets multiplied by the child's
/// size, matching Flutter's [SlideTransition] semantics.
class RenderAnimatedTranslation extends RenderBox
    with RenderObjectWithChildMixin {
  RenderAnimatedTranslation({
    required this.animation,
    required this.offset,
  });

  final AnimationController animation;
  final OffsetTween offset;

  @override
  void performLayout() {
    child?.layout(constraints);
    size = child?.size ?? Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset paintOffset) {
    final child = this.child;
    if (child == null) return;
    final t = animation.value;
    final (dx, dy) = offset.transform(t);
    // Fractional offset: multiply by child size.
    final childSize = children.first.size;
    final translatedOffset = Offset(
      paintOffset.dx + dx * childSize.width,
      paintOffset.dy + dy * childSize.height,
    );
    context.paintChild(children.first, translatedOffset);
  }
}

// ---------------------------------------------------------------------------
// RenderAnimatedScale
// ---------------------------------------------------------------------------

/// A render object that scales its single child from a center point.
class RenderAnimatedScale extends RenderBox
    with ContainerRenderObjectMixin {
  RenderAnimatedScale({
    required this.animation,
    required this.scale,
    this.alignment = (0.5, 0.5),
  });

  final AnimationController animation;
  final Tween<double> scale;

  /// Alignment of the scale origin as (x, y) fractions of child size.
  /// (0.5, 0.5) = center (default), (0, 0) = top~left, (1, 1) = bottom~right.
  final (double, double) alignment;

  @override
  void performLayout() {
    for (final child in children) {
      child.layout(constraints);
    }
    size = children.isNotEmpty
        ? children.first.size
        : Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (children.isEmpty) return;
    final t = animation.evaluate(constraints.currentTime);
    final s = scale.transform(t);
    if (s == 0.0) return;

    final childSize = children.first.size;
    final cx = offset.dx + childSize.width * alignment.$1;
    final cy = offset.dy + childSize.height * alignment.$2;

    context.canvas.save();
    context.canvas.translate(cx, cy);
    context.canvas.scale(s, s);
    context.canvas.translate(-cx, -cy);
    context.paintChild(children.first, offset);
    context.canvas.restore();
  }
}

// ---------------------------------------------------------------------------
// RenderAnimatedRotation
// ---------------------------------------------------------------------------

/// A render object that rotates its single child around a center point.
///
/// The [turns] tween specifies rotation in full turns (1.0 = 360°),
/// matching Flutter's [RotationTransition] semantics.
class RenderAnimatedRotation extends RenderBox
    with ContainerRenderObjectMixin {
  RenderAnimatedRotation({
    required this.animation,
    required this.turns,
    this.alignment = (0.5, 0.5),
  });

  final AnimationController animation;
  final Tween<double> turns;

  /// Alignment of the rotation origin as (x, y) fractions of child size.
  final (double, double) alignment;

  @override
  void performLayout() {
    for (final child in children) {
      child.layout(constraints);
    }
    size = children.isNotEmpty
        ? children.first.size
        : Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (children.isEmpty) return;
    final t = animation.evaluate(constraints.currentTime);
    final degrees = turns.transform(t) * 360.0;

    final childSize = children.first.size;
    final cx = offset.dx + childSize.width * alignment.$1;
    final cy = offset.dy + childSize.height * alignment.$2;

    context.canvas.save();
    context.canvas.translate(cx, cy);
    context.canvas.rotate(degrees);
    context.canvas.translate(-cx, -cy);
    context.paintChild(children.first, offset);
    context.canvas.restore();
  }
}
