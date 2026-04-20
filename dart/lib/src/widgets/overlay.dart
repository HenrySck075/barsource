import 'package:barsource/elements.dart' show ObjectKey;
import 'package:barsource/src/dart_ui/dart_ui.dart';

import '../rendering/box.dart';
import '../rendering/object.dart';
import 'framework.dart';
import 'stack.dart';

class OverlayController {
  OverlayState? _state;

  bool get mounted => _state != null;

  void insert(OverlayEntry entry, {OverlayEntry? below, OverlayEntry? above}) {
    final OverlayState? state = _state;
    if (state == null) {
      throw StateError('OverlayController is not attached to an Overlay.');
    }
    state.insert(entry, below: below, above: above);
  }

  void insertAll(
    Iterable<OverlayEntry> entries, {
    OverlayEntry? below,
    OverlayEntry? above,
  }) {
    final OverlayState? state = _state;
    if (state == null) {
      throw StateError('OverlayController is not attached to an Overlay.');
    }
    state.insertAll(entries, below: below, above: above);
  }
}

class Overlay extends StatefulWidget {
  const Overlay({
    super.key,
    this.controller,
    this.initialEntries = const <OverlayEntry>[],
  });

  final OverlayController? controller;

  final List<OverlayEntry> initialEntries;

  static OverlayState of(BuildContext context, {bool rootOverlay = false}) {
    final OverlayState? result = maybeOf(context, rootOverlay: rootOverlay);
    if (result == null) {
      throw StateError('No Overlay widget found.');
    }
    return result;
  }

  static OverlayState? maybeOf(
    BuildContext context, {
    bool rootOverlay = false,
  }) {
    if (!rootOverlay) {
      final _OverlayScope? scope = context
          .dependOnInheritedWidgetOfExactType<_OverlayScope>();
      return scope?.state;
    }

    OverlayState? result;
    context.visitAncestorElements((element) {
      final dynamic widget = element.widget;
      if (widget is _OverlayScope) {
        result = widget.state;
      }
      return true;
    });
    return result;
  }

  @override
  State<Overlay> createState() => OverlayState();
}

class OverlayState extends State<Overlay> {
  late final List<OverlayEntry> _entries;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _entries = List<OverlayEntry>.of(widget.initialEntries);
    for (final OverlayEntry entry in _entries) {
      _adoptEntry(entry);
    }
  }

  @override
  void didUpdateWidget(covariant Overlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller!._state = null;
      }
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller!._state = null;
    }
    for (final OverlayEntry entry in _entries) {
      entry._detach(this);
    }
    super.dispose();
  }

  List<Widget> _buildEntries() {
    final List<Widget> children = <Widget>[];
    bool onstage = true;

    for (int i = _entries.length - 1; i >= 0; i -= 1) {
      final OverlayEntry entry = _entries[i];
      final bool isHiddenByOpaqueEntryAbove = !onstage;
      if (isHiddenByOpaqueEntryAbove && !entry.maintainState) {
        continue;
      }

      Widget child = _OverlayEntryWidget(key: ObjectKey(entry), entry: entry);
      if (isHiddenByOpaqueEntryAbove) {
        child = Offstage(offstage: true, child: child);
      }
      children.add(child);

      if (entry.opaque) {
        onstage = false;
      }
    }

    return children.reversed.toList(growable: false);
  }

  int _insertionIndex({OverlayEntry? below, OverlayEntry? above}) {
    assert(
      !(below != null && above != null),
      'Only one of above/below may be specified.',
    );
    if (below != null) {
      final int index = _entries.indexOf(below);
      if (index < 0) {
        throw StateError('The "below" entry is not in this Overlay.');
      }
      return index;
    }
    if (above != null) {
      final int index = _entries.indexOf(above);
      if (index < 0) {
        throw StateError('The "above" entry is not in this Overlay.');
      }
      return index + 1;
    }
    return _entries.length;
  }

  void _adoptEntry(OverlayEntry entry) {
    if (entry._overlay != null) {
      throw StateError('OverlayEntry is already inserted into an Overlay.');
    }
    entry._overlay = this;
  }

  void _remove(OverlayEntry entry) {
    final int index = _entries.indexOf(entry);
    if (index < 0) {
      return;
    }
    setState(() {
      _entries.removeAt(index);
      entry._detach(this);
    });
  }

  void _markEntryNeedsBuild(OverlayEntry entry) {
    if (!_entries.contains(entry)) {
      return;
    }
    setState(() {});
  }

  void _onEntryChanged(OverlayEntry entry) {
    if (!_entries.contains(entry)) {
      return;
    }
    setState(() {});
  }

  void insert(OverlayEntry entry, {OverlayEntry? below, OverlayEntry? above}) {
    final int index = _insertionIndex(below: below, above: above);
    setState(() {
      _adoptEntry(entry);
      _entries.insert(index, entry);
    });
  }

  void insertAll(
    Iterable<OverlayEntry> entries, {
    OverlayEntry? below,
    OverlayEntry? above,
  }) {
    final List<OverlayEntry> newEntries = entries.toList(growable: false);
    if (newEntries.isEmpty) {
      return;
    }
    final int index = _insertionIndex(below: below, above: above);
    setState(() {
      for (final OverlayEntry entry in newEntries) {
        _adoptEntry(entry);
      }
      _entries.insertAll(index, newEntries);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _OverlayScope(
      state: this,
      child: Stack(children: _buildEntries()),
    );
  }
}

class OverlayEntry {
  OverlayEntry({
    required this.builder,
    bool opaque = false,
    bool maintainState = false,
  }) : _opaque = opaque,
       _maintainState = maintainState;

  final WidgetBuilder builder;

  OverlayState? _overlay;

  bool get mounted => _overlay != null;

  bool get opaque => _opaque;
  bool _opaque;
  set opaque(bool value) {
    if (_opaque == value) {
      return;
    }
    _opaque = value;
    _overlay?._onEntryChanged(this);
  }

  bool get maintainState => _maintainState;
  bool _maintainState;
  set maintainState(bool value) {
    if (_maintainState == value) {
      return;
    }
    _maintainState = value;
    _overlay?._onEntryChanged(this);
  }

  void markNeedsBuild() {
    _overlay?._markEntryNeedsBuild(this);
  }

  void remove() {
    _overlay?._remove(this);
  }

  void _detach(OverlayState overlay) {
    if (_overlay == overlay) {
      _overlay = null;
    }
  }
}

class _OverlayEntryWidget extends StatelessWidget {
  const _OverlayEntryWidget({super.key, required this.entry});

  final OverlayEntry entry;

  @override
  Widget build(BuildContext context) => entry.builder(context);
}

class _OverlayScope extends InheritedWidget {
  const _OverlayScope({required this.state, required super.child});

  final OverlayState state;

  @override
  bool updateShouldNotify(_OverlayScope oldWidget) => state != oldWidget.state;
}

class Offstage extends SingleChildRenderObjectWidget {
  const Offstage({super.key, this.offstage = true, super.child});

  final bool offstage;

  @override
  RenderOffstage createRenderObject(BuildContext context) {
    return RenderOffstage(offstage: offstage);
  }

  @override
  void updateRenderObject(BuildContext context, RenderOffstage renderObject) {
    renderObject.offstage = offstage;
  }
}

class RenderOffstage extends RenderProxyBox {
  RenderOffstage({bool offstage = true}) : _offstage = offstage;

  bool get offstage => _offstage;
  bool _offstage;
  set offstage(bool value) {
    if (_offstage == value) {
      return;
    }
    _offstage = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
      size = offstage ? constraints.smallest : child.size;
      return;
    }
    size = constraints.smallest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (!offstage && child != null) {
      context.paintChild(child, offset);
    }
  }
}
