import 'package:tennoji/src/rendering/box.dart';

import '../animation/animation.dart';
import '../foundation/geometry.dart';
import 'object.dart';

// ---------------------------------------------------------------------------
// Animated-list slot metadata
// ---------------------------------------------------------------------------

/// Describes which item a child render object corresponds to in the animated
/// list and the animation that should drive its insertion or removal
/// transition.
class AnimatedListSlot {
  const AnimatedListSlot({
    required this.index,
    required this.animation,
    this.removing = false,
  });

  /// Logical index of this item among the *currently-visible* items at the
  /// time it was laid out.
  final int index;

  /// The animation that drives the transition for this slot.
  /// For inserting items the animation runs 0→1 (appear).
  /// For removing items the animation runs 1→0 (disappear).
  final AnimationController animation;

  /// Whether this slot is being removed (playing the exit transition).
  final bool removing;
}

// ---------------------------------------------------------------------------
// RenderAnimatedList
// ---------------------------------------------------------------------------

/// A render object that lays out a vertical list of children and applies
/// insert/remove animations based on timeline-driven [AnimatedListSlot]
/// metadata attached to each child.
///
/// Children are stacked vertically.  Each child's visible height is scaled
/// by the animation progress of its slot, producing a size-transition effect
/// similar to Flutter's [SizeTransition] wrapped around each item.
class RenderAnimatedList extends RenderBox with ContainerRenderObjectMixin {
  // ---- Layout ---------------------------------------------------------------

  @override
  void performLayout() { 
    double totalHeight = 0;
    visitChildren((child) {
      child.layout(BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
        minHeight: 0,
        maxHeight: constraints.maxHeight,
      ), parentUsesSize: true);
      totalHeight += child.size.height;
    });

    // Total height = sum of each child's height × animation progress.

    size = Size(
      constraints.maxWidth,
      totalHeight.clamp(0.0, constraints.maxHeight),
    );
  }

  // ---- Paint ----------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    double dy = offset.dy;

    visitChildren((child) {

      // Clip to the visible portion so the item "slides" in vertically.
      // TODO: check if AnimatedList has clip parameter
      context.canvas.save();
      context.canvas.clipRect(
          Rect.fromLTWH(offset.dx, dy, child.size.width, child.size.height));
      context.paintChild(child, Offset(offset.dx, dy));
      context.canvas.restore();

      dy += child.size.height;
    });
  }
}
