import '../animation/animation.dart';
import '../foundation/geometry.dart';
import 'object.dart';
import 'time_box.dart';

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
  final TimelineAnimation animation;

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
class RenderAnimatedList extends RenderTimeBox with ContainerRenderObjectMixin {
  /// Per-child slot metadata, indexed in the same order as [children].
  final List<AnimatedListSlot> _slots = [];

  List<AnimatedListSlot> get slots => _slots;

  /// Adds a child together with its slot metadata.
  void addWithSlot(RenderObject child, AnimatedListSlot slot) {
    add(child);
    _slots.add(slot);
  }

  @override
  void remove(RenderObject child) {
    // We do not remove slots here because they are managed declaratively
    // by the widget's updateRenderObject method.
    super.remove(child);
  }

  // ---- Layout ---------------------------------------------------------------

  @override
  void performLayout() {
    final time = constraints.currentTime;
    
    for (final child in children) {
      child.layout(TimeBoxConstraints(
        currentTime: time,
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
        minHeight: 0,
        maxHeight: constraints.maxHeight,
      ));
    }

    // Total height = sum of each child's height × animation progress.
    double totalHeight = 0;
    for (int i = 0; i < children.length; i++) {
      final t = _progressFor(i, time);
      totalHeight += children[i].size.height * t;
    }

    size = Size(
      constraints.maxWidth,
      totalHeight.clamp(0.0, constraints.maxHeight),
    );
  }

  // ---- Paint ----------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    final time = constraints.currentTime;
    double dy = offset.dy;

    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      final t = _progressFor(i, time);

      if (t <= 0.0) continue; // fully collapsed – skip

      final childHeight = child.size.height;
      final visibleHeight = childHeight * t;

      // Clip to the visible portion so the item "slides" in vertically.
      context.canvas.save();
      context.canvas.clipRect(
          Rect.fromLTWH(offset.dx, dy, child.size.width, visibleHeight));
      context.paintChild(child, Offset(offset.dx, dy));
      context.canvas.restore();

      dy += visibleHeight;
    }
  }

  // ---- Helpers --------------------------------------------------------------

  /// Returns the animation progress [0..1] for the child at [index].
  double _progressFor(int index, Duration time) {
    if (index >= _slots.length) return 1.0;
    final slot = _slots[index];
    final t = slot.animation.evaluate(time);
    // Removing items play the animation in reverse (1→0).
    return slot.removing ? (1.0 - t) : t;
  }
}
