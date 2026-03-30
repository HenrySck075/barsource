import 'package:tennoji/src/foundation/collections.dart';
import 'package:tennoji/src/widgets/flex.dart';

import '../animation/animation.dart';
import '../foundation/listenable.dart';
import 'framework.dart';
import 'package:collection/collection.dart' hide binarySearch;

// ---------------------------------------------------------------------------
// ListController — imperative insert / remove schedule
// ---------------------------------------------------------------------------

class ListController<T> extends ChangeNotifier {
  final List<_ListOperation<T>> _operations = [];

  ListController(Iterable<T> initialItems) {
    _operations.addAll(initialItems.mapIndexed((i,e)=>_ListOperation(
      type: .insert,
      index: i, 
      data: e,
      duration: Duration.zero
    )));
  }

  void insert(int index, T item, {Duration duration = const Duration(milliseconds: 300)}) {
    _operations.add(_ListOperation(
      type: .insert,
      index: index,
      data: item,
      duration: duration,
    ));
    notifyListeners();
  }

  void removeAt(int index, {Duration duration = const Duration(milliseconds: 300)}) {
    _operations.add(_ListOperation(
      type: .remove,
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
typedef AnimatedItemBuilder<T> = Widget Function(
  BuildContext context,
  T data,
  Animation<double> animation,
);

/// A builder for items that are being removed.
typedef AnimatedRemovedItemBuilder<T> = Widget Function(
  BuildContext context,
  T data,
  Animation<double> animation,
);

/// A streaming-oriented animated list.
class AnimatedList<T extends Object> extends StatefulWidget {
  const AnimatedList({
    super.key,
    required this.itemBuilder,
    required this.listController,
    this.removedItemBuilder,
  });

  final AnimatedItemBuilder<T> itemBuilder;
  final ListController<T> listController;
  final AnimatedRemovedItemBuilder<T>? removedItemBuilder;

  @override
  State<AnimatedList<T>> createState() => _AnimatedListState<T>();
}

/// TODO(henrysck): When grid exist, move the majority of the logic to a separate AnimatedMultiBoxMixin
class _AnimatedListState<T extends Object> extends State<AnimatedList<T>> {
  final List<_ActiveItem<T>> _incomingItems = [];
  final List<_ActiveItem<T>> _outgoingItems = [];
  final List<T> _items = <T>[];

  _ActiveItem<T>? _removeActiveItemAt(List<_ActiveItem<T>> items, int itemIndex) {
    final int i = binarySearch(items, _ActiveItem.index(itemIndex));
    return i == -1 ? null : items.removeAt(i);
  }

  _ActiveItem<T>? _activeItemAt(List<_ActiveItem<T>> items, int itemIndex) {
    final int i = binarySearch(items, _ActiveItem.index(itemIndex));
    return i == -1 ? null : items[i];
  }

  @override
  void initState() {
    super.initState();
    // 
    widget.listController.addListener(_update);
  }

  @override
  void dispose() {
    widget.listController.removeListener(_update);
    super.dispose();
  }

  int _indexToItemIndex(int index) {
    var itemIndex = index;
    for (final _ActiveItem item in _outgoingItems) {
      if (item.itemIndex <= itemIndex) {
        itemIndex += 1;
      } else {
        break;
      }
    }
    return itemIndex;
  }

  int _itemIndexToIndex(int itemIndex) {
    var index = itemIndex;
    for (final _ActiveItem item in _outgoingItems) {
      assert(item.itemIndex != itemIndex);
      if (item.itemIndex < itemIndex) {
        index -= 1;
      } else {
        break;
      }
    }
    return index;
  }

  void insertItem(int index, T data, {Duration duration = _kDuration}) {
    assert(index >= 0);

    final int itemIndex = _indexToItemIndex(index);
    assert(itemIndex >= 0 && itemIndex <= _items.length);

    for (final _ActiveItem item in _incomingItems) {
      if (item.itemIndex >= itemIndex) {
        item.itemIndex += 1;
      }
    }
    for (final _ActiveItem item in _outgoingItems) {
      if (item.itemIndex >= itemIndex) {
        item.itemIndex += 1;
      }
    }

    final controller = AnimationController(duration: duration/*, vsync: this*/);
    final incomingItem = _ActiveItem.incoming(data, controller, itemIndex);
    setState(() {
      _incomingItems
        ..add(incomingItem)
        ..sort();
      _items.insert(index, data);
    });

    controller.forward().then<void>((_) {
      _removeActiveItemAt(_incomingItems, incomingItem.itemIndex)!.controller!.dispose();
    });
  }
  void insertAllItems(int startIndex, Iterable<T> items, {Duration duration = _kDuration}) {
    final iter = items.iterator;
    for (var i = 0; i < items.length; i++) {
      iter.moveNext();
      insertItem(startIndex + i, iter.current);
    }
  }
  // TODO(henrysck) technically builder is already available as AnimatedList.removedItemBuilder
  void removeItem(int index, AnimatedRemovedItemBuilder<T> builder, {Duration duration = _kDuration}) {
    assert(index >= 0);

    final int itemIndex = _indexToItemIndex(index);
    assert(itemIndex >= 0 && itemIndex < _items.length);
    assert(_activeItemAt(_outgoingItems, itemIndex) == null);

    final _ActiveItem? incomingItem = _removeActiveItemAt(_incomingItems, itemIndex);
    final AnimationController controller =
        incomingItem?.controller ??
        AnimationController(duration: duration, value: 1.0/*, vsync: this*/);
    final outgoingItem = _ActiveItem.outgoing(_items[index], controller, itemIndex, builder);
    setState(() {
      _outgoingItems
        ..add(outgoingItem)
        ..sort();
    });

    controller.reverse().then<void>((void value) {
      _removeActiveItemAt(_outgoingItems, outgoingItem.itemIndex)!.controller!.dispose();
      _items.removeAt(outgoingItem.itemIndex);

      // Decrement the incoming and outgoing item indices to account
      // for the removal.
      for (final _ActiveItem item in _incomingItems) {
        if (item.itemIndex > outgoingItem.itemIndex) {
          item.itemIndex -= 1;
        }
      }
      for (final _ActiveItem item in _outgoingItems) {
        if (item.itemIndex > outgoingItem.itemIndex) {
          item.itemIndex -= 1;
        }
      }
    });
  }

  void _update() {
    setState(() {
      final ops = widget.listController._consume();
      for (final op in ops) {
        if (op.type == _ListOpType.insert) {
          if (op.index >= 0 && op.index <= _items.length) {
            insertItem(op.index, op.data!, duration: op.duration);
          }
        } else if (op.type == _ListOpType.remove) {
          if (op.index >= 0 && op.index < _incomingItems.length) {
            removeItem(op.index, widget.removedItemBuilder ?? widget.itemBuilder, duration: op.duration);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        _items.length, (int itemIndex) {
          final _ActiveItem? outgoingItem = _activeItemAt(_outgoingItems, itemIndex);
          if (outgoingItem != null) {
            return outgoingItem.removedItemBuilder!(context, outgoingItem.data!, outgoingItem.controller!);
          }

          final incomingItem = _activeItemAt(_incomingItems, itemIndex);
          final Animation<double> animation = incomingItem?.controller ?? kAlwaysCompleteAnimation;
          final T data = incomingItem?.data ?? _items[_itemIndexToIndex(itemIndex)];
          return widget.itemBuilder(context, data, animation);
        }
      )
    );
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

// The default insert/remove animation duration.
const Duration _kDuration = Duration(milliseconds: 300);

// Incoming and outgoing animated items.
class _ActiveItem<T extends Object> implements Comparable<_ActiveItem> {
  _ActiveItem.incoming(this.data, this.controller, this.itemIndex) : removedItemBuilder = null;

  _ActiveItem.outgoing(this.data, this.controller, this.itemIndex, this.removedItemBuilder);

  _ActiveItem.index(this.itemIndex) : controller = null, removedItemBuilder = null, data = null;

  final AnimationController? controller;
  final AnimatedRemovedItemBuilder<T>? removedItemBuilder;
  int itemIndex;
  final T? data;

  @override
  int compareTo(_ActiveItem other) => itemIndex - other.itemIndex;
}

class _AnimatedListChild<T extends Object> extends StatelessWidget {
  const _AnimatedListChild({
    required this.entry,
    required this.builder,
  });

  final _ActiveItem<T> entry;
  final AnimatedItemBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    return builder(context, entry.data!, entry.controller!);
  }
}

