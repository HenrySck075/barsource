import 'package:barsource/src/painting/alignment.dart';
import 'package:barsource/src/painting/basic_types.dart';
import 'package:barsource/src/rendering/box.dart';
import 'package:barsource/src/rendering/pipeline_owner.dart';

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
    required Animation<double> opacity,
  }) : _opacity = opacity;

  Animation<double> _opacity;
  Animation<double> get opacity => _opacity;
  set opacity(Animation<double> value) {
    if (_opacity == value) return;
    opacity.removeListener(markNeedsPaint);
    _opacity = value;
    opacity.addListener(markNeedsPaint);
    markNeedsPaint();
  }

/*
  void _onOpacityUpdate() {
    markNeedsPaint();
  }
*/
  @override
  void attach(PipelineOwner owner) {
    opacity.addListener(markNeedsPaint);
    super.attach(owner);
  }
  @override
  void detach() {
    opacity.removeListener(markNeedsPaint);
    super.detach();
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
    context.canvas.saveLayerAlpha(alpha);
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
    required Animation<Offset> offset,
    required this.asPixel
  }) : _offset = offset;

  Animation<Offset> _offset;
  Animation<Offset> get offset => _offset;
  set offset(Animation<Offset> value) {
    if (_offset == value) return;
    offset.removeListener(markNeedsPaint);
    _offset = value;
    offset.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  bool asPixel;

  @override
  void attach(PipelineOwner owner) {
    offset.addListener(markNeedsPaint);
    super.attach(owner);
  }
  @override
  void detach() {
    offset.removeListener(markNeedsPaint);
    super.detach();
  }

  static final Size sizeOfOne = const Size(1,1);
  @override
  void paint(PaintingContext context, Offset paintOffset) {
    final child = this.child;
    if (child == null) return;
    final o = offset.value;
    // Fractional offset: multiply by child size.
    final childSize = asPixel ? sizeOfOne : child.size ;
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
    required Animation<double> scale,
    Alignment alignment = .center,
  }) : _scale = scale, _alignment = alignment;

  Animation<double> _scale;
  Animation<double> get scale => _scale;
  set scale(Animation<double> value) {
    if (_scale == value) return;
    scale.removeListener(markNeedsPaint);
    _scale = value;
    scale.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    scale.addListener(markNeedsPaint);
    super.attach(owner);
  }
  @override
  void detach() {
    scale.removeListener(markNeedsPaint);
    super.detach();
  }

  /// Alignment of the scale origin as (x, y) fractions of child size.
  /// (0.5, 0.5) = center (default), (0, 0) = top~left, (1, 1) = bottom~right.
  Alignment _alignment;
  Alignment get alignment => _alignment;
  set alignment(Alignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsPaint();
  }

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
    required Animation<double> turns,
    Alignment alignment = .center,
  }) : _turns = turns, _alignment = alignment;

  Animation<double> _turns;
  Animation<double> get turns => _turns;
  set turns(Animation<double> value) {
    if (_turns == value) return;
    turns.removeListener(markNeedsPaint);
    _turns = value;
    turns.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  /// Alignment of the rotation origin as (x, y) fractions of child size.
  Alignment _alignment;
  Alignment get alignment => _alignment;
  set alignment(Alignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    turns.addListener(markNeedsPaint);
    super.attach(owner);
  }
  @override
  void detach() {
    turns.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final degrees = turns.value * 360.0;

    final off = offset + alignment.alongSize(child.size);

    context.canvas.save();
    context.canvas.translate(off.dx, off.dy);
    context.canvas.rotate(degrees);
    context.canvas.translate(-off.dx, -off.dy);
    context.paintChild(child, offset);
    context.canvas.restore();
  }
}

// ---------------------------------------------------------------------------
// RenderAnimatedSize
// ---------------------------------------------------------------------------

// acts as a ClipRect
class RenderAnimatedSize extends RenderProxyBox {
  RenderAnimatedSize({
    required Animation<double> sizeFactor,
    Axis axis = Axis.vertical,
    Alignment alignment = .center,
  }) : _sizeFactor = sizeFactor, _axis = axis, _alignment = alignment;

  Animation<double> _sizeFactor;
  Animation<double> get sizeFactor => _sizeFactor;
  set sizeFactor(Animation<double> value) {
    if (_sizeFactor == value) return;
    sizeFactor.removeListener(markNeedsLayout);
    _sizeFactor = value;
    sizeFactor.addListener(markNeedsLayout);
    markNeedsPaint();
  }

  Axis _axis;
  Axis get axis => _axis;
  set axis(Axis value) {
    if (_axis == value) return;
    _axis = value;
    markNeedsPaint();
  }

  Alignment _alignment;
  Alignment get alignment => _alignment;
  set alignment(Alignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    sizeFactor.addListener(markNeedsLayout);
    super.attach(owner);
  }
  @override
  void detach() {
    sizeFactor.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;

    final s = sizeFactor.value.clamp(0.0, 1.0);
    if (s == 0.0) return;

    final childSize = child.size;
    final clipRect = alignment.inscribe(
      axis == Axis.vertical
          ? Size(childSize.width, childSize.height * s)
          : Size(childSize.width * s, childSize.height),
      Offset.zero & childSize,
    );

    context.canvas.save();
    context.canvas.clipRect(offset & clipRect.size, false);
    context.paintChild(child, offset);
    context.canvas.restore();
  }
}
