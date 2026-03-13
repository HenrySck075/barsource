import '../animation/animation.dart';
import '../rendering/animated_list_render.dart';
import '../rendering/object.dart';
import 'framework.dart';

// ---------------------------------------------------------------------------
// Instructions — declarative insert / remove schedule
// ---------------------------------------------------------------------------

/// The type of operation an [AnimatedListInstruction] represents.
enum AnimatedListInstructionType {
  /// Insert an item into the list.
  insert,

  /// Remove an item from the list.
  remove,
}

/// A single instruction that tells the [AnimatedList] to insert or remove an
/// item at a specific point on the timeline.
///
/// ```dart
/// AnimatedListInstruction<String>(
///   type: AnimatedListInstructionType.insert,
///   time: Duration(seconds: 2),
///   data: 'the cat that sogs the world',
///   duration: Duration(milliseconds: 500),
///   curve: Curves.easeOut,
/// )
/// ```
class AnimatedListInstruction<T> {
  const AnimatedListInstruction({
    required this.type,
    required this.time,
    required this.data,
    this.index,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.linear,
  });

  /// Whether this instruction inserts or removes an item.
  final AnimatedListInstructionType type;

  /// The timeline time at which this instruction takes effect.
  final Duration time;

  /// The data payload carried by the item.
  ///
  /// For **insert** instructions this is the data that will be handed to the
  /// [AnimatedList.itemBuilder].
  ///
  /// For **remove** instructions this identifies *which* item to remove.
  /// The first item in the current list whose data equals [data] will be
  /// targeted.  Alternatively, set [index] to remove by position.
  final T data;

  /// Optional positional index.
  ///
  /// • For **insert**: the index at which to insert (defaults to appending).
  /// • For **remove**: the index of the item to remove (if provided, [data]
  ///   is still passed to the removed-item builder but is not used for
  ///   look-up).
  final int? index;

  /// How long the insert / remove animation lasts.
  final Duration duration;

  /// The easing curve for the animation.
  final Curve curve;
}

// ---------------------------------------------------------------------------
// AnimatedList widget
// ---------------------------------------------------------------------------

/// A builder that receives the item [data] and the current
/// [TimelineAnimation] driving the transition.
///
/// The animation progresses from 0→1 when the item is being inserted and
/// should be used to drive transition widgets (e.g. [FadeTransition],
/// [SlideTransition]).
typedef AnimatedListItemBuilder<T> = Widget Function(
  BuildContext context,
  T data,
  TimelineAnimation animation,
);

/// A builder for items that are being removed.
///
/// Same signature as [AnimatedListItemBuilder]; the animation progresses
/// from 0→1 where 1 means fully visible and the value decreases toward 0
/// as the item is leaving.
typedef AnimatedListRemovedItemBuilder<T> = Widget Function(
  BuildContext context,
  T data,
  TimelineAnimation animation,
);

/// A timeline-driven animated list inspired by Flutter's [AnimatedList].
///
/// Instead of imperative `insertItem` / `removeItem` calls, you provide a
/// declarative list of [instructions] that describe *what* happens and
/// *when* on the timeline.  Each instruction carries a [data] payload that
/// is forwarded to the [itemBuilder], so the builder always knows what to
/// render.
///
/// ### Quick example
///
/// ```dart
/// AnimatedList<String>(
///   initialItems: ['hello'],
///   instructions: [
///     AnimatedListInstruction(
///       type: AnimatedListInstructionType.insert,
///       time: Duration(seconds: 1),
///       data: 'the cat that sogs the world',
///       duration: Duration(milliseconds: 500),
///       curve: Curves.easeOut,
///     ),
///     AnimatedListInstruction(
///       type: AnimatedListInstructionType.remove,
///       time: Duration(seconds: 3),
///       data: 'hello',
///       duration: Duration(milliseconds: 400),
///       curve: Curves.easeIn,
///     ),
///   ],
///   itemBuilder: (context, data, animation) {
///     return FadeTransition(
///       animation: animation,
///       child: Container(height: 60, child: Text(data)),
///     );
///   },
/// )
/// ```
class AnimatedList<T> extends MultiChildRenderObjectWidget {
  AnimatedList({
    super.key,
    this.initialItems = const [],
    this.instructions = const [],
    required this.itemBuilder,
    this.removedItemBuilder,
  }) : super(children: _buildChildren<T>(
          initialItems: initialItems,
          instructions: instructions,
          itemBuilder: itemBuilder,
          removedItemBuilder: removedItemBuilder,
        ));

  /// Items present in the list from the very beginning (time = 0).
  final List<T> initialItems;

  /// Timeline-ordered instructions for inserting and removing items.
  ///
  /// Instructions are processed in order.  Each instruction's [time]
  /// determines when the animation *starts*; the animation lasts for
  /// [AnimatedListInstruction.duration].
  final List<AnimatedListInstruction<T>> instructions;

  /// Builds a widget for each visible item.
  final AnimatedListItemBuilder<T> itemBuilder;

  /// Builds a widget for an item that is being removed.
  ///
  /// If not provided, [itemBuilder] is used for the removal animation as
  /// well.
  final AnimatedListRemovedItemBuilder<T>? removedItemBuilder;

  // ---- RenderObject plumbing ------------------------------------------------

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAnimatedList();

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderAnimatedList renderObject) {}

  // ---- Static child builder -------------------------------------------------

  /// Produces the list of child widgets (and their slot metadata) by
  /// replaying [instructions] on top of [initialItems].
  ///
  /// We walk through *all* instructions and build two kinds of children:
  ///
  /// 1. **Active items** – currently in the list (insert animations).
  /// 2. **Removing items** – items being removed (exit animations).
  ///
  /// Because this is a video-editor library the entire timeline is known
  /// ahead of time, so we can pre-compute the full child list.
  static List<Widget> _buildChildren<T>({
    required List<T> initialItems,
    required List<AnimatedListInstruction<T>> instructions,
    required AnimatedListItemBuilder<T> itemBuilder,
    AnimatedListRemovedItemBuilder<T>? removedItemBuilder,
  }) {
    // --- Replay instructions to produce (data, slot) pairs ----------------

    // Represents an item currently in the logical list.
    final List<_ItemEntry<T>> activeItems = [
      for (final item in initialItems)
        _ItemEntry(
          data: item,
          animation: TimelineAnimation(
            duration: Duration.zero,
            startTime: Duration.zero,
          ),
          removing: false,
        ),
    ];

    // Items that have been removed but still need their exit animation
    // rendered.
    final List<_ItemEntry<T>> removingItems = [];

    // Sort instructions by time so the replay is deterministic.
    final sorted = List<AnimatedListInstruction<T>>.of(instructions)
      ..sort((a, b) => a.time.compareTo(b.time));

    for (final instr in sorted) {
      switch (instr.type) {
        case AnimatedListInstructionType.insert:
          final entry = _ItemEntry<T>(
            data: instr.data,
            animation: TimelineAnimation(
              startTime: instr.time,
              duration: instr.duration,
              curve: instr.curve,
            ),
            removing: false,
          );
          final idx = instr.index ?? activeItems.length;
          activeItems.insert(idx.clamp(0, activeItems.length), entry);

        case AnimatedListInstructionType.remove:
          // Find the item to remove.
          int removeIdx;
          if (instr.index != null) {
            removeIdx = instr.index!;
          } else {
            removeIdx =
                activeItems.indexWhere((e) => e.data == instr.data);
          }

          if (removeIdx < 0 || removeIdx >= activeItems.length) continue;

          final removed = activeItems.removeAt(removeIdx);
          removingItems.add(_ItemEntry<T>(
            data: removed.data,
            animation: TimelineAnimation(
              startTime: instr.time,
              duration: instr.duration,
              curve: instr.curve,
            ),
            removing: true,
            insertAfterIndex: removeIdx,
          ));
      }
    }

    // --- Merge active + removing items into a single ordered list ----------
    // We interleave removing items at their original positions so that the
    // exit animation appears in the correct visual spot.

    final List<_ItemEntry<T>> merged = [];

    // Sort removing items by insertAfterIndex descending so that later
    // removals don't shift earlier indices.
    final removingSorted = List<_ItemEntry<T>>.of(removingItems)
      ..sort((a, b) =>
          (a.insertAfterIndex ?? 0).compareTo(b.insertAfterIndex ?? 0));

    // Build the merged list: start with active items, then splice in
    // removing items at their positions.
    merged.addAll(activeItems);
    for (final rem in removingSorted) {
      final pos = (rem.insertAfterIndex ?? merged.length)
          .clamp(0, merged.length);
      merged.insert(pos, rem);
    }

    // --- Build widgets from merged entries ----------------------------------
    final builder = removedItemBuilder ?? itemBuilder;

    return [
      for (final entry in merged)
        entry.removing
            ? _AnimatedListChild<T>(
                entry: entry,
                builder: builder,
              )
            : _AnimatedListChild<T>(
                entry: entry,
                builder: itemBuilder,
              ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

class _ItemEntry<T> {
  const _ItemEntry({
    required this.data,
    required this.animation,
    required this.removing,
    this.insertAfterIndex,
  });

  final T data;
  final TimelineAnimation animation;
  final bool removing;

  /// For removing items: the index in the active list where this item was
  /// before removal, used to splice the exit animation in the right spot.
  final int? insertAfterIndex;
}

/// A thin wrapper widget that carries the [_ItemEntry] so that the
/// [RenderObjectElement] can attach the corresponding [AnimatedListSlot]
/// to the [RenderAnimatedList].
class _AnimatedListChild<T> extends StatelessWidget {
  const _AnimatedListChild({
    required this.entry,
    required this.builder,
  });

  final _ItemEntry<T> entry;
  final AnimatedListItemBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    return builder(context, entry.data, entry.animation);
  }
}
