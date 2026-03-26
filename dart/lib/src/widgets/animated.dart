import '../animation/animation.dart';
import '../rendering/animated_render.dart';
import '../rendering/object.dart';
import 'framework.dart';

// ---------------------------------------------------------------------------
// FadeTransition
// ---------------------------------------------------------------------------

/// Animates the opacity of a child over time.
///
/// ```dart
/// FadeTransition(
///   animation: AnimationController(
///     duration: Duration(seconds: 1),
///     curve: Curves.easeIn,
///   ),
///   opacity: Tween(begin: 0.0, end: 1.0),
///   child: VideoClip(source: 'intro.mp4'),
/// )
/// ```
class FadeTransition extends SingleChildRenderObjectWidget {
  const FadeTransition({
    super.key,
    required this.animation,
    this.opacity = const Tween(begin: 0.0, end: 1.0),
    super.child,
  });

  final AnimationController animation;
  final Tween<double> opacity;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAnimatedOpacity(animation: animation, opacity: opacity);

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderAnimatedOpacity renderObject) {}
}

// ---------------------------------------------------------------------------
// SlideTransition
// ---------------------------------------------------------------------------

/// Animates the position of a child by a fractional offset over time.
///
/// Offset values are fractions of the child's size:
/// `(1.0, 0.0)` means "one full width to the right".
///
/// ```dart
/// SlideTransition(
///   animation: AnimationController(
///     duration: Duration(milliseconds: 500),
///     curve: Curves.easeOut,
///   ),
///   offset: OffsetTween(begin: (-1.0, 0.0), end: (0.0, 0.0)),
///   child: Container(color: Color(0xFFFF0000)),
/// )
/// ```
class SlideTransition extends SingleChildRenderObjectWidget {
  const SlideTransition({
    super.key,
    required this.animation,
    required this.offset,
    super.child,
  });

  final AnimationController animation;
  final OffsetTween offset;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAnimatedTranslation(animation: animation, offset: offset);

  @override
  void updateRenderObject(BuildContext context,
      covariant RenderAnimatedTranslation renderObject) {}
}

// ---------------------------------------------------------------------------
// ScaleTransition
// ---------------------------------------------------------------------------

/// Animates the scale of a child over time.
///
/// ```dart
/// ScaleTransition(
///   animation: AnimationController(
///     duration: Duration(seconds: 1),
///     curve: Curves.bounceOut,
///   ),
///   scale: Tween(begin: 0.0, end: 1.0),
///   child: Container(color: Color(0xFF00FF00)),
/// )
/// ```
class ScaleTransition extends SingleChildRenderObjectWidget {
  const ScaleTransition({
    super.key,
    required this.animation,
    this.scale = const Tween(begin: 0.0, end: 1.0),
    this.alignment = const (0.5, 0.5),
    super.child,
  });

  final AnimationController animation;
  final Tween<double> scale;

  /// Alignment of the scale origin as (x, y) fractions of child size.
  /// (0.5, 0.5) = center, (0, 0) = top~left, (1, 1) = bottom~right.
  final (double, double) alignment;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAnimatedScale(
        animation: animation,
        scale: scale,
        alignment: alignment,
      );

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderAnimatedScale renderObject) {}
}

// ---------------------------------------------------------------------------
// RotationTransition
// ---------------------------------------------------------------------------

/// Animates the rotation of a child over time.
///
/// The [turns] tween specifies rotation in full turns (1.0 = 360°).
///
/// ```dart
/// RotationTransition(
///   animation: AnimationController(
///     duration: Duration(seconds: 2),
///     curve: Curves.easeInOut,
///   ),
///   turns: Tween(begin: 0.0, end: 1.0),
///   child: Container(width: 100, height: 100, color: Color(0xFF0000FF)),
/// )
/// ```
class RotationTransition extends SingleChildRenderObjectWidget {
  const RotationTransition({
    super.key,
    required this.animation,
    this.turns = const Tween(begin: 0.0, end: 1.0),
    this.alignment = const (0.5, 0.5),
    super.child,
  });

  final AnimationController animation;
  final Tween<double> turns;

  /// Alignment of the rotation origin as (x, y) fractions of child size.
  final (double, double) alignment;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAnimatedRotation(
        animation: animation,
        turns: turns,
        alignment: alignment,
      );

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderAnimatedRotation renderObject) {}
}
