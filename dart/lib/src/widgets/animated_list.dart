import '../animation/animation.dart';
import '../engine/engine.dart';
import '../foundation/change_notifier.dart';
import '../rendering/animated_list_render.dart';
import '../rendering/object.dart';
import 'framework.dart';

// ---------------------------------------------------------------------------
// ListController — imperative insert / remove schedule
// ---------------------------------------------------------------------------

class ListController<T> extends ChangeNotifier {
  final List<_ListOperation<T>> _operations = [];

  void insert(int index, T item, {Duration duration = const Duration(milliseconds: 300)}) {
    _operations.add(_ListOperation(
      type: _ListOpType.insert,
      index: index,
      data: item,
      duration: duration,
    ));
    notifyListeners();
  }

  void removeAt(int index, {Duration duration = const Duration(milliseconds: 300)}) {
    _operations.add(_ListOperation(
      type: _ListOpType.remove,
      index: index,
      duration: duration,
    ));
    notifyListeners();
  }

  // Internal: consume operations
  List<_ListOperation<T>> _consume() {
    final ops = List.of(_operations);
    _operations.clear();
    return ops;
  }
}

enum _ListOpType { insert, remove }

class _ListOperation<T> {
  _ListOperation({
    required this.type,
    required this.index,
    this.data,
    required this.duration,
  });

  final _ListOpType type;
  final int index;
  final T? data;
  final Duration duration;
}

// ---------------------------------------------------------------------------
// AnimatedList widget
// ---------------------------------------------------------------------------

/// A builder that receives the item [data] and the current
/// [AnimationController] driving the transition.
typedef AnimatedListItemBuilder<T> = Widget Function(
  BuildContext context,
  T data,
  AnimationController animation,
);

/// A builder for items that are being removed.
typedef AnimatedListRemovedItemBuilder<T> = Widget Function(
  BuildContext context,
  T data,
  AnimationController animation,
);

/// A streaming-oriented animated list.
class AnimatedList<T> extends StatefulWidget {
  const AnimatedList({
    super.key,
    required this.itemBuilder,
    required this.listController,
    this.initialItemCount = 0,
    this.initialItemBuilder,
    this.removedItemBuilder,
  });

  final AnimatedListItemBuilder<T> itemBuilder;
  final ListController<T> listController;
  final int initialItemCount;
  final T Function(int)? initialItemBuilder;
  final AnimatedListRemovedItemBuilder<T>? removedItemBuilder;

  @override
  State<AnimatedList<T>> createState() => _AnimatedListState<T>();
}

class _AnimatedListState<T> extends State<AnimatedList<T>> {
  final List<_ItemEntry<T>> _activeItems = [];
  final List<_ItemEntry<T>> _removingItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialItemBuilder != null) {
      for (int i = 0; i < widget.initialItemCount; i++) {
        _activeItems.add(_ItemEntry(
          data: widget.initialItemBuilder!(i),
          animation: AnimationController(duration: Duration.zero),
          removing: false,
        ));
      }
    }
    widget.listController.addListener(_update);
  }

  @override
  void dispose() {
    widget.listController.removeListener(_update);
    super.dispose();
  }

  void _update() {
    setState(() {
      final ops = widget.listController._consume();
      for (final op in ops) {
        if (op.type == _ListOpType.insert) {
          final entry = _ItemEntry<T>(
            data: op.data as T,
            animation: AnimationController(
              startTime: Engine.instance.currentTime,
              duration: op.duration,
            ),
            removing: false,
          );
          _activeItems.insert(op.index.clamp(0, _activeItems.length), entry);
        } else if (op.type == _ListOpType.remove) {
          if (op.index >= 0 && op.index < _activeItems.length) {
            final removed = _activeItems.removeAt(op.index);
            _removingItems.add(_ItemEntry<T>(
              data: removed.data,
              animation: AnimationController(
                startTime: Engine.instance.currentTime,
                duration: op.duration,
              ),
              removing: true,
              insertAfterIndex: op.index,
            ));
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Clean up finished removing items
    final now = Engine.instance.currentTime;
    _removingItems.removeWhere(
        (item) => now > item.animation.startTime + item.animation.duration);

    final merged = <_ItemEntry<T>>[];
    merged.addAll(_activeItems);

    // Re-insert removing items
    _removingItems.sort(
        (a, b) => (a.insertAfterIndex ?? 0).compareTo(b.insertAfterIndex ?? 0));

    for (final rem in _removingItems) {
      int index = rem.insertAfterIndex ?? 0;
      if (index > merged.length) index = merged.length;
      merged.insert(index, rem);
    }

    return _CoreAnimatedList<T>(
      items: merged,
      itemBuilder: widget.itemBuilder,
      removedItemBuilder: widget.removedItemBuilder,
    );
  }
}

class _CoreAnimatedList<T> extends MultiChildRenderObjectWidget {
  _CoreAnimatedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.removedItemBuilder,
  }) : super(
          children: [
            for (final entry in items)
              _AnimatedListChild<T>(
                entry: entry,
                builder: entry.removing && removedItemBuilder != null
                    ? removedItemBuilder
                    : itemBuilder,
              )
          ],
        );

  final List<_ItemEntry<T>> items;
  final AnimatedListItemBuilder<T> itemBuilder;
  final AnimatedListRemovedItemBuilder<T>? removedItemBuilder;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final renderObject = RenderAnimatedList();
    _updateSlots(renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderAnimatedList renderObject) {
    _updateSlots(renderObject);
  }

  void _updateSlots(RenderAnimatedList renderObject) {
    renderObject.slots.clear();
    for (int i = 0; i < items.length; i++) {
      final entry = items[i];
      renderObject.slots.add(AnimatedListSlot(
        index: i,
        animation: entry.animation,
        removing: entry.removing,
      ));
    }
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
  final AnimationController animation;
  final bool removing;
  final int? insertAfterIndex;
}

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

