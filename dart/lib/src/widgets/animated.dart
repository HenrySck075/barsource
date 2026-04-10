import 'package:barsource/src/dart_ui/dart_ui.dart';
import 'package:barsource/src/foundation/listenable.dart';
import 'package:barsource/src/painting/alignment.dart';
import 'package:barsource/src/painting/basic_types.dart';

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
    required this.opacity,
    super.child,
  });

  final Animation<double> opacity;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAnimatedOpacity(opacity: opacity);

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderAnimatedOpacity renderObject) {
    renderObject.opacity = opacity;
  }
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
    required this.offset,
    this.asPixel = false,
    super.child,
  });

  final Animation<Offset> offset;
  /// Whether or not to treat [offset] as a literal pixel unit instead of fraction of the widget's size
  final bool asPixel;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAnimatedTranslation(offset: offset, asPixel: asPixel);

  @override
  void updateRenderObject(BuildContext context,
      covariant RenderAnimatedTranslation renderObject) {
    renderObject.offset = offset;
    renderObject.asPixel = asPixel;
  }
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
    required this.scale,
    this.alignment = Alignment.center,
    super.child,
  });

  final Animation<double> scale;

  /// Alignment of the scale origin
  final Alignment alignment;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAnimatedScale(
        scale: scale,
        alignment: alignment,
      );

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderAnimatedScale renderObject) {
      renderObject
        ..scale = scale
        ..alignment = alignment;
  }
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
    required this.turns,
    this.alignment = Alignment.center,
    super.child,
  });

  final Animation<double> turns;

  /// Alignment of the rotation origin as (x, y) fractions of child size.
  final Alignment alignment;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAnimatedRotation(
        turns: turns,
        alignment: alignment,
      );

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderAnimatedRotation renderObject) {
    renderObject
      ..turns = turns
      ..alignment = alignment;
  }
}


// ---------------------------------------------------------------------------
// SizeTransition
// ---------------------------------------------------------------------------

class SizeTransition extends SingleChildRenderObjectWidget {
  const SizeTransition({
    super.key,
    required this.sizeFactor,
    this.axis = Axis.vertical,
    this.alignment = Alignment.center,
    super.child,
  });

  final Animation<double> sizeFactor;
  final Axis axis;
  final Alignment alignment;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAnimatedSize(
        sizeFactor: sizeFactor,
        axis: axis,
        alignment: alignment,
      );

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderAnimatedSize renderObject) {
    renderObject
      ..sizeFactor = sizeFactor
      ..axis = axis
      ..alignment = alignment;
  }
}

// ---------------------------------------------------------------------------
// ListenableBuilder
// ---------------------------------------------------------------------------

class ListenableBuilder extends StatefulWidget {
  const ListenableBuilder({
    super.key,
    required this.listenable,
    this.child,
    required this.builder,
  });

  final Listenable listenable;
  final Widget? child;
  final Widget Function(BuildContext context, Widget? child) builder;

  @override
  State<ListenableBuilder> createState() => _ListenableBuilderState(); 
}

class _ListenableBuilderState extends State<ListenableBuilder> {
  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onChange);
  }

  @override
  void didUpdateWidget(ListenableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onChange);
      widget.listenable.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.child);
}


typedef AnimatedBuilder = ListenableBuilder;
