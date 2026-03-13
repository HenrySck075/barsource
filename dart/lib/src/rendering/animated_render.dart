import '../animation/animation.dart';
import '../foundation/geometry.dart';
import 'object.dart';
import 'time_box.dart';

// ---------------------------------------------------------------------------
// RenderAnimatedOpacity
// ---------------------------------------------------------------------------

/// A render object that fades its single child using a [TimelineAnimation].
///
/// Evaluates the animation at the current timeline time and applies the
/// resulting opacity (0.0 transparent → 1.0 opaque) via [Canvas.saveLayer].
class RenderAnimatedOpacity extends RenderTimeBox
    with ContainerRenderObjectMixin {
  RenderAnimatedOpacity({
    required this.animation,
    required this.opacity,
  });

  final TimelineAnimation animation;
  final Tween<double> opacity;

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
    final alpha = (opacity.transform(t).clamp(0.0, 1.0) * 255).round();
    if (alpha <= 0) return;
    if (alpha >= 255) {
      context.paintChild(children.first, offset);
      return;
    }
    context.canvas.saveLayer(alpha);
    context.paintChild(children.first, offset);
    context.canvas.restore();
  }
}

// ---------------------------------------------------------------------------
// RenderAnimatedTranslation
// ---------------------------------------------------------------------------

/// A render object that translates its single child using a [TimelineAnimation].
///
/// The [offset] tween produces fractional offsets multiplied by the child's
/// size, matching Flutter's [SlideTransition] semantics.
class RenderAnimatedTranslation extends RenderTimeBox
    with ContainerRenderObjectMixin {
  RenderAnimatedTranslation({
    required this.animation,
    required this.offset,
  });

  final TimelineAnimation animation;
  final OffsetTween offset;

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
  void paint(PaintingContext context, Offset paintOffset) {
    if (children.isEmpty) return;
    final t = animation.evaluate(constraints.currentTime);
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
class RenderAnimatedScale extends RenderTimeBox
    with ContainerRenderObjectMixin {
  RenderAnimatedScale({
    required this.animation,
    required this.scale,
    this.alignment = (0.5, 0.5),
  });

  final TimelineAnimation animation;
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
class RenderAnimatedRotation extends RenderTimeBox
    with ContainerRenderObjectMixin {
  RenderAnimatedRotation({
    required this.animation,
    required this.turns,
    this.alignment = (0.5, 0.5),
  });

  final TimelineAnimation animation;
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
