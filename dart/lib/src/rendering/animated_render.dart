import 'package:tennoji/src/painting/alignment.dart';
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
class RenderAnimatedOpacity extends RenderProxyBox {
  RenderAnimatedOpacity({
    required this.opacity,
  });

  final Animation<double> opacity;

/*
  void _onOpacityUpdate() {
    markNeedsPaint();
  }
*/
  @override
  void attach(PipelineOwner owner) {
    //opacity.addListener(_onOpacityUpdate);
    super.attach(owner);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final alpha = (opacity.value.clamp(0.0, 1.0) * 255).round();
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
class RenderAnimatedTranslation extends RenderProxyBox {
  RenderAnimatedTranslation({
    required this.offset,
  });

  final Animation<Offset> offset;

  @override
  void paint(PaintingContext context, Offset paintOffset) {
    final child = this.child;
    if (child == null) return;
    final o = offset.value;
    // Fractional offset: multiply by child size.
    final childSize = child.size;
    final translatedOffset = Offset(
      paintOffset.dx + o.dx * childSize.width,
      paintOffset.dy + o.dy * childSize.height,
    );
    context.paintChild(child, translatedOffset);
  }
}

// ---------------------------------------------------------------------------
// RenderAnimatedScale
// ---------------------------------------------------------------------------

/// A render object that scales its single child from a center point.
/// NOTE: Incomplete conversion
class RenderAnimatedScale extends RenderProxyBox {
  RenderAnimatedScale({
    required this.scale,
    this.alignment = Alignment.center,
  });

  final Animation<double> scale;

  /// Alignment of the scale origin as (x, y) fractions of child size.
  /// (0.5, 0.5) = center (default), (0, 0) = top~left, (1, 1) = bottom~right.
  final Alignment alignment;

  @override
  void performLayout() {
    child?.layout(constraints);
    size = child?.size
        ?? Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final s = scale.value;
    if (s == 0.0) return;

    final childSize = child.size;
    final cx = offset.dx + childSize.width * alignment.x;
    final cy = offset.dy + childSize.height * alignment.y;

    context.canvas.save();
    context.canvas.translate(cx, cy);
    context.canvas.scale(s, s);
    context.canvas.translate(-cx, -cy);
    context.paintChild(child, offset);
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
class RenderAnimatedRotation extends RenderProxyBox {
  RenderAnimatedRotation({
    required this.turns,
    this.alignment = Alignment.center,
  });

  final Animation<double> turns;

  /// Alignment of the rotation origin as (x, y) fractions of child size.
  final Alignment alignment;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final degrees = turns.value * 360.0;

    final childSize = child.size;
    final cx = offset.dx + childSize.width * alignment.x;
    final cy = offset.dy + childSize.height * alignment.y;

    context.canvas.save();
    context.canvas.translate(cx, cy);
    context.canvas.rotate(degrees);
    context.canvas.translate(-cx, -cy);
    context.paintChild(child, offset);
    context.canvas.restore();
  }
}
