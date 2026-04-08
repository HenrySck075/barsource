import 'package:barsource/src/foundation/const.dart';
import 'package:barsource/src/widgets/binding.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:barsource/src/painting/basic_types.dart' show VoidCallback;
import 'package:barsource/src/rendering/parent_data.dart';
import 'dart:collection';

import '../widgets/framework.dart';
import '../rendering/object.dart';


@immutable
abstract class Key {
  const Key();
}


abstract class LocalKey extends Key {
  const LocalKey();
}

class ValueKey<T> extends LocalKey {
  const ValueKey(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValueKey<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class ObjectKey extends LocalKey {
  const ObjectKey(this.value);
  final Object value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectKey && identical(other.value, value);

  @override
  int get hashCode => identityHashCode(value);
}


abstract class GlobalKey<T extends State<StatefulWidget>> extends Key {
  const GlobalKey();

  Element? get _currentElement => WidgetsBinding.instance.buildOwner._globalKeyRegistry[this];

  BuildContext? get currentContext => _currentElement;
  Widget? get currentWidget => _currentElement?._widget;
  T? get currentState => switch (_currentElement) {
    StatefulElement(:final T _state) => _state,
    _ => null,
  };
}


typedef ElementVisitor = void Function(Element element);
class _InactiveElements {
  bool _locked = false;
  final Set<Element> _elements = HashSet<Element>();

  static void _unmount(Element element) {
    assert(element._lifecycleState == _ElementLifecycle.inactive);
    /*
    assert(() {
      if (debugPrintGlobalKeyedWidgetLifecycle) {
        if (element.widget.key is GlobalKey) {
          debugPrint('Discarding $element from inactive elements list.');
        }
      }
      return true;
    }());
    */
    element.visitChildren((Element child) {
      assert(child._parent == element);
      _unmount(child);
    });
    element.unmount();
    assert(element._lifecycleState == _ElementLifecycle.defunct);
  }

  void _unmountAll() {
    _locked = true;
    final List<Element> elements = _elements.toList()..sort(Element._sort);
    _elements.clear();
    try {
      elements.reversed.forEach(_unmount);
    } finally {
      assert(_elements.isEmpty);
      _locked = false;
    }
  }

  static void _deactivateRecursively(Element element) {
    assert(element._lifecycleState == _ElementLifecycle.active);
    try {
      element.deactivate();
    } catch (_) {
      Element._deactivateFailedSubtreeRecursively(element);
      rethrow;
    }
    element.visitChildren(_deactivateRecursively);
    /*
    assert(() {
      element.debugDeactivated();
      return true;
    }());
    */
  }

  void add(Element element) {
    assert(!_locked);
    assert(!_elements.contains(element));
    assert(element._parent == null);

    switch (element._lifecycleState) {
      case _ElementLifecycle.active:
        _deactivateRecursively(element);
        // This element is only added to _elements if the whole subtree is
        // successfully deactivated.
        _elements.add(element);
      case _ElementLifecycle.inactive:
        _elements.add(element);
      case _ElementLifecycle.initial || _ElementLifecycle.failed || _ElementLifecycle.defunct:
        assert(false, '$element must not be deactivated when in ${element._lifecycleState} state.');
    }
  }

  void remove(Element element) {
    assert(!_locked);
    assert(_elements.contains(element));
    assert(element._parent == null);
    _elements.remove(element);
    assert(element._lifecycleState == _ElementLifecycle.inactive);
  }

  bool debugContains(Element element) {
    late bool result;
    assert(() {
      result = _elements.contains(element);
      return true;
    }());
    return result;
  }
}
final class BuildScope {
  /// Creates a [BuildScope] with an optional [scheduleRebuild] callback.
  BuildScope({this.scheduleRebuild});

  // Whether `scheduleRebuild` is called.
  bool _buildScheduled = false;
  // Whether [BuildOwner.buildScope] is actively running in this [BuildScope].
  bool _building = false;

  final VoidCallback? scheduleRebuild;

  bool? _dirtyElementsNeedsResorting;
  final List<Element> _dirtyElements = <Element>[];

  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  void _scheduleBuildFor(Element element) {
    assert(identical(element.buildScope, this));
    if (!element._inDirtyList) {
      _dirtyElements.add(element);
      element._inDirtyList = true;
    }
    if (!_buildScheduled && !_building) {
      _buildScheduled = true;
      scheduleRebuild?.call();
    }
    if (_dirtyElementsNeedsResorting != null) {
      _dirtyElementsNeedsResorting = true;
    }
  }
  void _tryRebuild(Element element) {
    assert(element._inDirtyList);
    assert(identical(element.buildScope, this));
    element.rebuild();
  }
  @pragma('vm:notify-debugger-on-exception')
  void _flushDirtyElements({required Element debugBuildRoot}) {
    assert(_dirtyElementsNeedsResorting == null, '_flushDirtyElements must be non-reentrant');
    _dirtyElements.sort(Element._sort);
    _dirtyElementsNeedsResorting = false;
    try {
      for (var index = 0; index < _dirtyElements.length; index = _dirtyElementIndexAfter(index)) {
        final Element element = _dirtyElements[index];
        if (identical(element.buildScope, this)) {
          //assert(_debugAssertElementInScope(element, debugBuildRoot));
          _tryRebuild(element);
        }
      }
    } finally {
      for (final Element element in _dirtyElements) {
        if (identical(element.buildScope, this)) {
          element._inDirtyList = false;
        }
      }
      _dirtyElements.clear();
      _dirtyElementsNeedsResorting = null;
      _buildScheduled = false;
    }
  }

  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  int _dirtyElementIndexAfter(int index) {
    if (!_dirtyElementsNeedsResorting!) {
      return index + 1;
    }
    index += 1;
    _dirtyElements.sort(Element._sort);
    _dirtyElementsNeedsResorting = false;
    while (index > 0 && _dirtyElements[index - 1].dirty) {
      // It is possible for previously dirty but inactive widgets to move right in the list.
      // We therefore have to move the index left in the list to account for this.
      // We don't know how many could have moved. However, we do know that the only possible
      // change to the list is that nodes that were previously to the left of the index have
      // now moved to be to the right of the right-most cleaned node, and we do know that
      // all the clean nodes were to the left of the index. So we move the index left
      // until just after the right-most clean node.
      index -= 1;
    }
    assert(() {
      for (int i = index - 1; i >= 0; i -= 1) {
        final Element element = _dirtyElements[i];
        assert(!element.dirty || element._lifecycleState != _ElementLifecycle.active);
      }
      return true;
    }());
    return index;
  }
}
class BuildOwner {
  final _InactiveElements _inactiveElements = _InactiveElements();
  int _debugStateLockLevel = 0;

  final Set<Element>? _debugIllFatedElements = kDebugMode ? HashSet<Element>() : null;
  final Map<GlobalKey, Element> _globalKeyRegistry = {};
  void _registerGlobalKey(GlobalKey key, Element element) {
    assert(() {
      if (_globalKeyRegistry.containsKey(key)) {
        final Element oldElement = _globalKeyRegistry[key]!;
        assert(element.widget.runtimeType != oldElement.widget.runtimeType);
        _debugIllFatedElements?.add(oldElement);
      }
      return true;
    }());
    _globalKeyRegistry[key] = element;
  }

  void _unregisterGlobalKey(GlobalKey key, Element element) {
    assert(() {
      if (_globalKeyRegistry.containsKey(key) && _globalKeyRegistry[key] != element) {
        final Element oldElement = _globalKeyRegistry[key]!;
        assert(element.widget.runtimeType != oldElement.widget.runtimeType);
      }
      return true;
    }());
    if (_globalKeyRegistry[key] == element) {
      _globalKeyRegistry.remove(key);
    }
  }


  Map<Element, Set<GlobalKey>>? _debugElementsThatWillNeedToBeRebuiltDueToGlobalKeyShenanigans;

  void _debugTrackElementThatWillNeedToBeRebuiltDueToGlobalKeyShenanigans(
    Element node,
    GlobalKey key,
  ) {
    final Map<Element, Set<GlobalKey>> map =
        _debugElementsThatWillNeedToBeRebuiltDueToGlobalKeyShenanigans ??=
            HashMap<Element, Set<GlobalKey>>();
    final Set<GlobalKey> keys = map.putIfAbsent(node, () => HashSet<GlobalKey>());
    keys.add(key);
  }

  void _debugElementWasRebuilt(Element node) {
    _debugElementsThatWillNeedToBeRebuiltDueToGlobalKeyShenanigans?.remove(node);
  }


  void lockState(VoidCallback callback) {
    assert(_debugStateLockLevel >= 0);
    assert(() {
      _debugStateLockLevel += 1;
      return true;
    }());
    try {
      callback();
    } finally {
      assert(() {
        _debugStateLockLevel -= 1;
        return true;
      }());
    }
    assert(_debugStateLockLevel >= 0);
  }
  void scheduleBuildFor(Element element) {
    assert(element.owner == this);
    assert(element._parentBuildScope != null);
    element.buildScope._scheduleBuildFor(element);
  }

  void buildScope(Element context, [VoidCallback? callback]) {
    assert(context.owner == this);
    assert(context._parentBuildScope != null);
    final scope = context.buildScope;
    scope._building = true;
    callback?.call();
    scope._flushDirtyElements(debugBuildRoot: context);
    scope._building = false;
  }

  void finalizeTree() {
    lockState(_inactiveElements._unmountAll);
  }
}

abstract class BuildContext {
  // Returns the widget that this context is associated with.
  // Typed as dynamic here to avoid circular import with framework.dart.
  // framework.dart provides the concrete Widget type.
  dynamic get widget;

  T? dependOnInheritedWidgetOfExactType<T>();

  void visitAncestorElements(bool Function(Element element) visitor);
}
enum _ElementLifecycle {
  initial,
  active,
  inactive,
  defunct,
  failed,
}
abstract class Element implements BuildContext {
  Element(this._widget);
  Widget? _widget;

  Logger get _log => Logger('Element.$runtimeType');
  Object? _slot;
  Object? get slot => _slot;

  @override
  Widget get widget => _widget!;

  Element? _parent;

  BuildOwner? _owner;
  BuildOwner? get owner => _owner;

  BuildScope? _parentBuildScope;
  BuildScope get buildScope => _parentBuildScope!;
  bool _inDirtyList = false;

  //RenderObject? _renderObject;
  bool _active = false;
  bool _dirty = true;
  bool get dirty => _dirty;

  RenderObject? get renderObject {
    RenderObject? result;
    void visitor(Element element) {
      if (result != null) return;
      result = element.renderObject;
    }
    visitChildren(visitor);
    return result;
  }

  int get depth {
    assert(
      _lifecycleState != .initial, 
      "Depth is only available when the element is mounted."
    );
    return _depth;
  }
  int _depth = 0;
 
  @protected
  Element? get renderObjectAttachingChild {
    Element? next;
    visitChildren((Element child) {
      assert(next == null); // This verifies that there's only one child.
      next = child;
    });
    return next;
  } 
  void attachRenderObject(Object? newSlot) {
    assert(_slot == null);
    visitChildren((Element child) {
      child.attachRenderObject(newSlot);
    });
    _slot = newSlot;
  }
  void detachRenderObject() {
    visitChildren((Element child) {
      child.detachRenderObject();
    });
    _slot = null;
  } 
  static int _sort(Element a, Element b) {
    final int diff = a.depth - b.depth;
    // If depths are not equal, return the difference.
    if (diff != 0) {
      return diff;
    }
    // If the `dirty` values are not equal, sort with non-dirty elements being
    // less than dirty elements.
    final bool isBDirty = b.dirty;
    if (a.dirty != isBDirty) {
      return isBDirty ? -1 : 1;
    }
    // Otherwise, `depth`s and `dirty`s are equal.
    return 0;
  }

  @protected
  void updateSlotForChild(Element child, Object? newSlot) {
    assert(_lifecycleState == _ElementLifecycle.active);
    assert(child._parent == this);
    void visit(Element element) {
      element.updateSlot(newSlot);
      final Element? descendant = element.renderObjectAttachingChild;
      if (descendant != null) {
        visit(descendant);
      }
    }

    visit(child);
  }
  @protected
  @mustCallSuper
  void updateSlot(Object? newSlot) {
    assert(_lifecycleState == _ElementLifecycle.active);
    assert(_parent != null);
    assert(_parent!._lifecycleState == _ElementLifecycle.active);
    _slot = newSlot;
  }
  void _updateDepth(int parentDepth) {
    final int expectedDepth = parentDepth + 1;
    if (_depth < expectedDepth) {
      _depth = expectedDepth;
      visitChildren((Element child) {
        child._updateDepth(expectedDepth);
      });
    }
  }

  void _updateBuildScopeRecursively() {
    if (identical(buildScope, _parent?.buildScope)) {
      return;
    }
    // Unset the _inDirtyList flag so this Element can be added to the dirty list
    // of the new build scope if it's dirty.
    _inDirtyList = false;
    _parentBuildScope = _parent?.buildScope;
    visitChildren((Element child) {
      child._updateBuildScopeRecursively();
    });
  }
  void visitChildren(void Function(Element element) visitor) {}

  _ElementLifecycle _lifecycleState = _ElementLifecycle.initial;

  Map<Type, InheritedElement>? _inheritedElements;
  Set<InheritedElement>? _dependencies;

  @override
  T? dependOnInheritedWidgetOfExactType<T>() {
    assert(_active);
    final ancestor = _inheritedElements?[T];
    if (ancestor != null) {
      ancestor.setDependencies(this, null);
      _dependencies ??= HashSet<InheritedElement>();
      _dependencies!.add(ancestor);
      return ancestor.widget as T;
    }
    return null;
  }

  @override
  void visitAncestorElements(bool Function(Element element) visitor) {
    assert(_active);
    Element? ancestor = _parent;
    while (ancestor != null) {
      if (!visitor(ancestor)) {
        return;
      }
      ancestor = ancestor._parent;
    }
  }

  void _updateInheritance() {
    assert(_active);
    _inheritedElements = _parent?._inheritedElements;
  }

  void didChangeDependencies() {
    markNeedsBuild();
  }

  void mount(Element? parent, Object? newSlot) {
    _log.finer('Mounting');
    _slot = newSlot;
    _parent = parent;
    if (parent != null) {
      _owner = parent.owner;
      _parentBuildScope = parent.buildScope;
    }
    _active = true;
    _lifecycleState = _ElementLifecycle.active;
    assert(owner != null);
    final Key? key = widget.key;
    if (key is GlobalKey) {
      owner!._registerGlobalKey(key, this);
    }
    _updateInheritance();
  }
  
  // TODO: rootelementmixin, or not, maybe we can let everyone be a root element, idk
  void assignOwner(BuildOwner owner) {
    _owner = owner;
    _parentBuildScope = BuildScope();
  }

  void rebuild({bool force=false}) {
    if (_lifecycleState != _ElementLifecycle.active || (!_dirty && !force)) {
      return;
    }
    _log.finer('Rebuilding (force: $force)');
    performRebuild();
  }

  @protected
  @mustCallSuper
  void performRebuild() {
    _dirty = false;
  }

  void update(covariant Widget newWidget) {
    _widget = newWidget;
  }
  @protected
  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    // 1. If the new widget is null, the child is gone.
    if (newWidget == null) {
      if (child != null) {
        deactivateChild(child);
      }
      return null;
    }

    final Element newChild;

    // 2. If we have an existing child, try to update it.
    if (child != null) {
      if (child.widget == newWidget) {
        // The widget hasn't changed, just ensure the slot is correct.
        if (child.slot != newSlot) {
          updateSlotForChild(child, newSlot);
        }
        newChild = child;
      } else if (Widget.canUpdate(child.widget, newWidget)) {
        // The widget changed but is compatible (same Type and Key).
        if (child.slot != newSlot) {
          updateSlotForChild(child, newSlot);
        }
        child.update(newWidget);
        newChild = child;
      } else {
        // Incompatible: throw away the old element and create a new one.
        deactivateChild(child);
        newChild = inflateWidget(newWidget, newSlot);
      }
    } else {
      // 3. No existing child, so we create it.
      newChild = inflateWidget(newWidget, newSlot);
    }

    return newChild;
  }
  Element inflateWidget(Widget newWidget, Object? newSlot) {
    final Key? key = newWidget.key;
    final Element? inactiveChild = key is GlobalKey ? _retakeInactiveElement(key, newWidget) : null;
    final Element newChild = inactiveChild ?? newWidget.createElement();
    try {
        if (inactiveChild != null) {
          assert(inactiveChild._parent == null);
          inactiveChild._activateWithParent(this, newSlot);
          final Element? updatedChild = updateChild(inactiveChild, newWidget, newSlot);
          assert(inactiveChild == updatedChild);
          return updatedChild!;
        } else {
          newChild.mount(this, newSlot);
          assert(newChild._lifecycleState == _ElementLifecycle.active);
          return newChild;
        }
      } catch (_) {
        // Attempt to do some clean-up if activation or mount fails
        // to leave tree in a reasonable state.
        _deactivateFailedChildSilently(newChild);
        rethrow;
      }  } 
  Element? _retakeInactiveElement(GlobalKey key, Widget newWidget) {
    // The "inactivity" of the element being retaken here may be forward-looking: if
    // we are taking an element with a GlobalKey from an element that currently has
    // it as a child, then we know that element will soon no longer have that
    // element as a child. The only way that assumption could be false is if the
    // global key is being duplicated, and we'll try to track that using the
    // _debugTrackElementThatWillNeedToBeRebuiltDueToGlobalKeyShenanigans call below.
    final Element? element = key._currentElement;
    if (element == null) {
      return null;
    }
    if (!Widget.canUpdate(element.widget, newWidget)) {
      return null;
    }
    /*
    assert(() {
      if (debugPrintGlobalKeyedWidgetLifecycle) {
        debugPrint(
          'Attempting to take $element from ${element._parent ?? "inactive elements list"} to put in $this.',
        );
      }
      return true;
    }());
    */
    final Element? parent = element._parent;
    if (parent != null) {
      assert(() {
        if (parent == this) {
          /*
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary("A GlobalKey was used multiple times inside one widget's child list."),
            DiagnosticsProperty<GlobalKey>('The offending GlobalKey was', key),
            parent.describeElement('The parent of the widgets with that key was'),
            element.describeElement('The first child to get instantiated with that key became'),
            DiagnosticsProperty<Widget>(
              'The second child that was to be instantiated with that key was',
              widget,
              style: DiagnosticsTreeStyle.errorProperty,
            ),
            ErrorDescription(
              'A GlobalKey can only be specified on one widget at a time in the widget tree.',
            ),
          ]);
          */
          throw StateError("A GlobalKey was used multiple times inside one widget's child list. The offending GlobalKey was $key. The parent of the widgets with that key was $parent. The first child to get instantiated with that key became $element. The second child that was to be instantiated with that key was $widget. A GlobalKey can only be specified on one widget at a time in the widget tree.");
        }
        parent.owner!._debugTrackElementThatWillNeedToBeRebuiltDueToGlobalKeyShenanigans(
          parent,
          key,
        );
        return true;
      }());
      parent.forgetChild(element);
      parent.deactivateChild(element);
    }
    assert(element._parent == null);
    owner!._inactiveElements.remove(element);
    return element;
  }

  void unmount() {
    _log.finer('Unmounting');
    assert(_lifecycleState == _ElementLifecycle.inactive);
    assert(_widget != null);
    
    if (_dependencies != null) {
      for (final InheritedElement dependency in _dependencies!) {
        dependency.removeDependent(this);
      }
      _dependencies = null;
    }
    _inheritedElements = null;

    final Key? key = widget.key;
    if (key is GlobalKey) {
      owner!._unregisterGlobalKey(key, this);
    }

    _active = false;
    _lifecycleState = _ElementLifecycle.defunct;
  }

  void markNeedsBuild() {
    if (_dirty && _active) return;
    assert(_owner != null);
    _dirty = true;
    _owner!.scheduleBuildFor(this);
  }

  void _activateWithParent(Element parent, Object? newSlot) {
    assert(_lifecycleState == _ElementLifecycle.inactive);
    _parent = parent;
    _owner = parent.owner;
    /*
    assert(() {
      if (debugPrintGlobalKeyedWidgetLifecycle) {
        debugPrint('Reactivating $this (now child of $_parent).');
      }
      return true;
    }());
    */
    _updateDepth(_parent!.depth);
    _updateBuildScopeRecursively();
    _activateRecursively(this);
    attachRenderObject(newSlot);
    assert(_lifecycleState == _ElementLifecycle.active);
  }

  static void _activateRecursively(Element element) {
    assert(element._lifecycleState == _ElementLifecycle.inactive);
    element.activate();
    assert(element._lifecycleState == _ElementLifecycle.active);
    element.visitChildren(_activateRecursively);
  }

  bool _hadUnsatisfiedDependencies = false;
  @mustCallSuper
  @visibleForOverriding
  void activate() {
    assert(_lifecycleState == _ElementLifecycle.inactive);
    assert(owner != null);
    final bool hadDependencies =
        (_dependencies?.isNotEmpty ?? false) || _hadUnsatisfiedDependencies;
    _lifecycleState = _ElementLifecycle.active;
    // We unregistered our dependencies in deactivate, but never cleared the list.
    // Since we're going to be reused, let's clear our list now.
    _dependencies?.clear();
    _hadUnsatisfiedDependencies = false;
    _updateInheritance();
    //attachNotificationTree();
    if (_dirty) {
      owner!.scheduleBuildFor(this);
    }
    if (hadDependencies) {
      didChangeDependencies();
    }
  }

  void forgetChild(Element child) {}
  void deactivateChild(Element child) {
    child._parent = null;
    child.detachRenderObject();
    owner!._inactiveElements.add(child);
  }
  @mustCallSuper
  @visibleForOverriding
  void deactivate() {
    assert(_lifecycleState == _ElementLifecycle.active);
    assert(_widget != null); // Use the private property to avoid a CastError during hot reload.
    _ensureDeactivated();
  }

  /// Removes dependencies and sets the lifecycle state of this [Element] to
  /// inactive.
  ///
  /// This method is immediately called after [Element.deactivate], even if that
  /// call throws an exception.
  void _ensureDeactivated() {
    if (_dependencies case final Set<InheritedElement> dependencies? when dependencies.isNotEmpty) {
      for (final dependency in dependencies) {
        dependency.removeDependent(this);
      }
      // For expediency, we don't actually clear the list here, even though it's
      // no longer representative of what we are registered with. If we never
      // get re-used, it doesn't matter. If we do, then we'll clear the list in
      // activate(). The benefit of this is that it allows Element's activate()
      // implementation to decide whether to rebuild based on whether we had
      // dependencies here.
    }
    _inheritedElements = null;
    _lifecycleState = _ElementLifecycle.inactive;
  } 

  void _deactivateFailedChildSilently(Element child) {
    try {
      child._parent = null;
      child.detachRenderObject();
      _deactivateFailedSubtreeRecursively(child);
    } catch (_) {
      // Do not rethrow:
      // The subtree has already thrown a different error and the framework is
      // cleaning up on a best-effort basis.
    }
  }

  // This method calls _ensureDeactivated for the subtree rooted at `element`,
  // supressing all exceptions thrown.
  //
  // This method will attempt to keep doing treewalk even one of the nodes
  // failed to deactivate.
  //
  // The subtree has already thrown a different error and the framework is
  // cleaning up on a best-effort basis.
  static void _deactivateFailedSubtreeRecursively(Element element) {
    try {
      element.deactivate();
    } catch (_) {
      element._ensureDeactivated();
    }
    element._lifecycleState = _ElementLifecycle.failed;
    try {
      element.visitChildren(_deactivateFailedSubtreeRecursively);
    } catch (_) {}
  }
}

abstract class ComponentElement extends Element {
  ComponentElement(super.widget);
  Element? _child;

  @override
  void visitChildren(void Function(Element element) visitor) {
    if (_child != null) {
      visitor(_child!);
    }
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _firstBuild();
  }

  void _firstBuild() {
    rebuild();
  }

  @override
  void performRebuild() {
    Widget built = build();
    _child = updateChild(_child, built, slot);
    super.performRebuild();
  }

  Widget build();
}

class StatelessElement extends ComponentElement {
  StatelessElement(StatelessWidget super.widget);

  @override
  Widget build() => (widget as StatelessWidget).build(this);
}

class StatefulElement extends ComponentElement {
  StatefulElement(StatefulWidget super.widget) {
    _state = (widget as StatefulWidget).createState()
      ..bindElement(this)
      ..bindWidget(widget as StatefulWidget);
  }

  late State _state;

  @override
  void _firstBuild() {
    _state.initState();
    //_state.didChangeDependencies();
    super._firstBuild();
  }

  @override
  Widget build() => _state.build(this);
}

abstract class RenderObjectElement extends Element {
  RenderObjectElement(RenderObjectWidget super.widget);

  RenderObject? _renderObject;

  @override
  RenderObject get renderObject {
    assert(_renderObject != null, "$runtimeType unmounted");
    return _renderObject!;
  }

  @override 
  Element? get renderObjectAttachingChild => null;

  RenderObjectElement? _ancestorRenderObjectElement;

  RenderObjectElement? _findAncestorRenderObjectElement() {
    Element? ancestor = _parent;
    while (ancestor != null && ancestor is! RenderObjectElement) {
      // In debug mode we check whether the ancestor accepts RenderObjects to
      // produce a better error message in attachRenderObject. In release mode,
      // we assume only correct trees are built (i.e.
      // debugExpectsRenderObjectForSlot always returns true) and don't check
      // explicitly.
      /*
      assert(() {
        if (!ancestor!.debugExpectsRenderObjectForSlot(slot)) {
          ancestor = null;
        }
        return true;
      }());
      */
      ancestor = ancestor._parent;
    }
    /*
    assert(() {
      if (ancestor?.debugExpectsRenderObjectForSlot(slot) == false) {
        ancestor = null;
      }
      return true;
    }());
    */
    return ancestor as RenderObjectElement?;
  }
  List<ParentDataElement<ParentData>> _findAncestorParentDataElements() {
    Element? ancestor = _parent;
    final result = <ParentDataElement<ParentData>>[];
    /*
    final debugAncestorTypes = <Type>{};
    final debugParentDataTypes = <Type>{};
    final debugAncestorCulprits = <Type>[];
    */
    // More than one ParentDataWidget can contribute ParentData, but there are
    // some constraints.
    // 1. ParentData can only be written by unique ParentDataWidget types.
    //    For example, two KeepAlive ParentDataWidgets trying to write to the
    //    same child is not allowed.
    // 2. Each contributing ParentDataWidget must contribute to a unique
    //    ParentData type, less ParentData be overwritten.
    //    For example, there cannot be two ParentDataWidgets that both write
    //    ParentData of type KeepAliveParentDataMixin, if the first check was
    //    subverted by a subclassing of the KeepAlive ParentDataWidget.
    // 3. The ParentData itself must be compatible with all ParentDataWidgets
    //    writing to it.
    //    For example, TwoDimensionalViewportParentData uses the
    //    KeepAliveParentDataMixin, so it could be compatible with both
    //    KeepAlive, and another ParentDataWidget with ParentData type
    //    TwoDimensionalViewportParentData or a subclass thereof.
    // The first and second cases are verified here. The third is verified in
    // debugIsValidRenderObject.

    while (ancestor != null && ancestor is! RenderObjectElement) {
      if (ancestor is ParentDataElement<ParentData>) {
        /*
        assert((ParentDataElement<ParentData> ancestor) {
          if (!debugAncestorTypes.add(ancestor.runtimeType) ||
              !debugParentDataTypes.add(ancestor.debugParentDataType)) {
            debugAncestorCulprits.add(ancestor.runtimeType);
          }
          return true;
        }(ancestor));
        */
        result.add(ancestor);
      }
      ancestor = ancestor._parent;
    }
    assert(() {
      if (result.isEmpty || ancestor == null) {
        return true;
      }
      /*
      // Validate points 1 and 2 from above.
      _debugCheckCompetingAncestors(
        result,
        debugAncestorTypes,
        debugParentDataTypes,
        debugAncestorCulprits,
      );
      */
      return true;
    }());
    return result;
  }
  @override
  void attachRenderObject(Object? newSlot) {
    assert(_ancestorRenderObjectElement == null);
    _slot = newSlot;
    _ancestorRenderObjectElement = _findAncestorRenderObjectElement();
    assert(() {
      if (_ancestorRenderObjectElement == null) {
        /*
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary(
                'The render object for ${toStringShort()} cannot find ancestor render object to attach to.',
              ),
              ErrorDescription(
                'The ownership chain for the RenderObject in question was:\n  ${debugGetCreatorChain(10)}',
              ),
              ErrorHint(
                'Try wrapping your widget in a View widget or any other widget that is backed by '
                'a $RenderTreeRootElement to serve as the root of the render tree.',
              ),
            ]),
          ),
        );
        */
        throw "dumbass";
      }
      return true;
    }());
    _ancestorRenderObjectElement?.insertRenderObjectChild(renderObject, newSlot);
    final List<ParentDataElement<ParentData>> parentDataElements =
        _findAncestorParentDataElements();
    for (final parentDataElement in parentDataElements) {
      _updateParentData(parentDataElement.widget as ParentDataWidget<ParentData>);
    }
  }
  @override
  void detachRenderObject() {
    if (_ancestorRenderObjectElement != null) {
      _ancestorRenderObjectElement!.removeRenderObjectChild(renderObject, slot);
      _ancestorRenderObjectElement = null;
    }
    _slot = null;
  }

  @protected
  void insertRenderObjectChild(covariant RenderObject child, covariant Object? slot);
  @protected
  void moveRenderObjectChild(
    covariant RenderObject child,
    covariant Object? oldSlot,
    covariant Object? newSlot,
  );
  @protected
  void removeRenderObjectChild(covariant RenderObject child, covariant Object? slot);

  bool _debugDoingBuild = false;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    assert(() {
      _debugDoingBuild = true;
      return true;
    }());
    _renderObject = (widget as RenderObjectWidget).createRenderObject(this);
    //assert(!_renderObject!.debugDisposed!);
    assert(() {
      _debugDoingBuild = false;
      return true;
    }());
    assert(() {
      //_debugUpdateRenderObjectOwner();
      return true;
    }());
    assert(slot == newSlot);
    attachRenderObject(newSlot);
    super.performRebuild(); // clears the "dirty" flag
  }

  void _updateParentData(ParentDataWidget<ParentData> parentDataWidget) {
    if (_renderObject != null) {
      final parentData = _renderObject!.parentData;
      if (parentData is ParentData) {
        parentDataWidget.applyParentData(renderObject);
      }
    }
  }

  @override
  void update(covariant RenderObjectWidget newWidget) {
    super.update(newWidget);
    newWidget.updateRenderObject(this, _renderObject!);
  }

  @override
  void unmount() {
    //_renderObject!.detach();
    final oldWidget = widget as RenderObjectWidget;
    super.unmount();
    oldWidget.didUnmountRenderObject(_renderObject!);
    _renderObject!.dispose();
    _renderObject = null;
  }
  @override
  // ignore: must_call_super, _performRebuild calls super.
  void performRebuild() {
    _performRebuild(); // calls widget.updateRenderObject()
  }

  @pragma('dart2js:tryInline')
  @pragma('vm:prefer-inline')
  @pragma('wasm:prefer-inline')
  void _performRebuild() {
    assert(() {
      _debugDoingBuild = true;
      return true;
    }());
    (widget as RenderObjectWidget).updateRenderObject(this, renderObject);
    assert(() {
      _debugDoingBuild = false;
      return true;
    }());
    super.performRebuild(); // clears the "dirty" flag
  }
}

/// An [Element] that uses a [LeafRenderObjectWidget] as its configuration.
class LeafRenderObjectElement extends RenderObjectElement {
  /// Creates an element that uses the given widget as its configuration.
  LeafRenderObjectElement(LeafRenderObjectWidget super.widget);

  @override
  void forgetChild(Element child) {
    assert(false);
    super.forgetChild(child);
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    assert(false);
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    assert(false);
  }
}
class SingleChildRenderObjectElement extends RenderObjectElement {
  /// Creates an element that uses the given widget as its configuration.
  SingleChildRenderObjectElement(SingleChildRenderObjectWidget super.widget);

  Element? _child;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) {
      visitor(_child!);
    }
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child);
    _child = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _child = updateChild(_child, (widget as SingleChildRenderObjectWidget).child, null);
  }

  @override
  void update(SingleChildRenderObjectWidget newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    _child = updateChild(_child, (widget as SingleChildRenderObjectWidget).child, null);
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    final renderObject = this.renderObject as RenderObjectWithChildMixin<RenderObject>;
    assert(slot == null);
    //assert(renderObject.debugValidateChild(child));
    renderObject.child = child;
    assert(renderObject == this.renderObject);
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    final renderObject = this.renderObject as RenderObjectWithChildMixin<RenderObject>;
    assert(slot == null);
    assert(renderObject.child == child);
    renderObject.child = null;
    assert(renderObject == this.renderObject);
  }
}
class MultiChildRenderObjectElement extends RenderObjectElement {
  /// Creates an element that uses the given widget as its configuration.
  MultiChildRenderObjectElement(MultiChildRenderObjectWidget super.widget);
    //: assert(!debugChildrenHaveDuplicateKeys(widget, widget.children));

  @override
  ContainerRenderObjectMixin<RenderObject, ContainerParentDataMixin<RenderObject>>
  get renderObject {
    return super.renderObject
        as ContainerRenderObjectMixin<RenderObject, ContainerParentDataMixin<RenderObject>>;
  }

  /// The current list of children of this element.
  ///
  /// This list is filtered to hide elements that have been forgotten (using
  /// [forgetChild]).
  @protected
  @visibleForTesting
  Iterable<Element> get children =>
      _children.where((Element child) => !_forgottenChildren.contains(child));

  late List<Element> _children;
  // We keep a set of forgotten children to avoid O(n^2) work walking _children
  // repeatedly to remove children.
  final Set<Element> _forgottenChildren = HashSet<Element>();

  @override
  void insertRenderObjectChild(RenderObject child, IndexedSlot<Element?> slot) {
    final ContainerRenderObjectMixin<RenderObject, ContainerParentDataMixin<RenderObject>>
    renderObject = this.renderObject;
    //assert(renderObject.debugValidateChild(child));
    renderObject.insert(child, after: slot.value?.renderObject);
    assert(renderObject == this.renderObject);
  }

  @override
  void moveRenderObjectChild(
    RenderObject child,
    IndexedSlot<Element?> oldSlot,
    IndexedSlot<Element?> newSlot,
  ) {
    final ContainerRenderObjectMixin<RenderObject, ContainerParentDataMixin<RenderObject>>
    renderObject = this.renderObject;
    assert(child.parent == renderObject);
    renderObject.move(child, after: newSlot.value?.renderObject);
    assert(renderObject == this.renderObject);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    final ContainerRenderObjectMixin<RenderObject, ContainerParentDataMixin<RenderObject>>
    renderObject = this.renderObject;
    assert(child.parent == renderObject);
    renderObject.remove(child);
    assert(renderObject == this.renderObject);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    for (final Element child in _children) {
      if (!_forgottenChildren.contains(child)) {
        visitor(child);
      }
    }
  }

  @override
  void forgetChild(Element child) {
    assert(_children.contains(child));
    assert(!_forgottenChildren.contains(child));
    _forgottenChildren.add(child);
    super.forgetChild(child);
  }

/*
  bool _debugCheckHasAssociatedRenderObject(Element newChild) {
    assert(() {
      if (newChild.renderObject == null) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary(
                'The children of `MultiChildRenderObjectElement` must each has an associated render object.',
              ),
              ErrorHint(
                'This typically means that the `${newChild.widget}` or its children\n'
                'are not a subtype of `RenderObjectWidget`.',
              ),
              newChild.describeElement(
                'The following element does not have an associated render object',
              ),
              DiagnosticsDebugCreator(DebugCreator(newChild)),
            ]),
          ),
        );
      }
      return true;
    }());
    return true;
  }
  */

  @override
  Element inflateWidget(Widget newWidget, Object? newSlot) {
    final Element newChild = super.inflateWidget(newWidget, newSlot);
    //assert(_debugCheckHasAssociatedRenderObject(newChild));
    return newChild;
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    final multiChildRenderObjectWidget = widget as MultiChildRenderObjectWidget;
    final children = List<Element>.filled(
      multiChildRenderObjectWidget.children.length,
      _NullElement.instance,
    );
    Element? previousChild;
    for (var i = 0; i < children.length; i += 1) {
      final Element newChild = inflateWidget(
        multiChildRenderObjectWidget.children[i],
        IndexedSlot<Element?>(i, previousChild),
      );
      children[i] = newChild;
      previousChild = newChild;
    }
    _children = children;
  }

  @override
  void update(MultiChildRenderObjectWidget newWidget) {
    super.update(newWidget);
    final multiChildRenderObjectWidget = widget as MultiChildRenderObjectWidget;
    assert(widget == newWidget);
    //assert(!debugChildrenHaveDuplicateKeys(widget, multiChildRenderObjectWidget.children));
    _children = updateChildren(
      _children,
      multiChildRenderObjectWidget.children,
      forgottenChildren: _forgottenChildren,
    );
    _forgottenChildren.clear();
  }

  @protected
  List<Element> updateChildren(
    List<Element> oldChildren,
    List<Widget> newWidgets, {
    Set<Element>? forgottenChildren,
    List<Object?>? slots,
  }) {
    assert(slots == null || newWidgets.length == slots.length);

    Element? replaceWithNullIfForgotten(Element child) {
      return (forgottenChildren?.contains(child) ?? false) ? null : child;
    }

    Object? slotFor(int newChildIndex, Element? previousChild) {
      return slots != null
          ? slots[newChildIndex]
          : IndexedSlot<Element?>(newChildIndex, previousChild);
    }

    // This attempts to diff the new child list (newWidgets) with
    // the old child list (oldChildren), and produce a new list of elements to
    // be the new list of child elements of this element. The called of this
    // method is expected to update this render object accordingly.

    // The cases it tries to optimize for are:
    //  - the old list is empty
    //  - the lists are identical
    //  - there is an insertion or removal of one or more widgets in
    //    only one place in the list
    // If a widget with a key is in both lists, it will be synced.
    // Widgets without keys might be synced but there is no guarantee.

    // The general approach is to sync the entire new list backwards, as follows:
    // 1. Walk the lists from the top, syncing nodes, until you no longer have
    //    matching nodes.
    // 2. Walk the lists from the bottom, without syncing nodes, until you no
    //    longer have matching nodes. We'll sync these nodes at the end. We
    //    don't sync them now because we want to sync all the nodes in order
    //    from beginning to end.
    // At this point we narrowed the old and new lists to the point
    // where the nodes no longer match.
    // 3. Walk the narrowed part of the old list to get the list of
    //    keys and sync null with non-keyed items.
    // 4. Walk the narrowed part of the new list forwards:
    //     * Sync non-keyed items with null
    //     * Sync keyed items with the source if it exists, else with null.
    // 5. Walk the bottom of the list again, syncing the nodes.
    // 6. Sync null with any items in the list of keys that are still
    //    mounted.

    var newChildrenTop = 0;
    var oldChildrenTop = 0;
    int newChildrenBottom = newWidgets.length - 1;
    int oldChildrenBottom = oldChildren.length - 1;

    final newChildren = List<Element>.filled(newWidgets.length, _NullElement.instance);

    Element? previousChild;

    // Update the top of the list.
    while ((oldChildrenTop <= oldChildrenBottom) && (newChildrenTop <= newChildrenBottom)) {
      final Element? oldChild = replaceWithNullIfForgotten(oldChildren[oldChildrenTop]);
      final Widget newWidget = newWidgets[newChildrenTop];
      assert(oldChild == null || oldChild._lifecycleState == _ElementLifecycle.active);
      if (oldChild == null || !Widget.canUpdate(oldChild.widget, newWidget)) {
        break;
      }
      final Element newChild = updateChild(
        oldChild,
        newWidget,
        slotFor(newChildrenTop, previousChild),
      )!;
      assert(newChild._lifecycleState == _ElementLifecycle.active);
      newChildren[newChildrenTop] = newChild;
      previousChild = newChild;
      newChildrenTop += 1;
      oldChildrenTop += 1;
    }

    // Scan the bottom of the list.
    while ((oldChildrenTop <= oldChildrenBottom) && (newChildrenTop <= newChildrenBottom)) {
      final Element? oldChild = replaceWithNullIfForgotten(oldChildren[oldChildrenBottom]);
      final Widget newWidget = newWidgets[newChildrenBottom];
      assert(oldChild == null || oldChild._lifecycleState == _ElementLifecycle.active);
      if (oldChild == null || !Widget.canUpdate(oldChild.widget, newWidget)) {
        break;
      }
      oldChildrenBottom -= 1;
      newChildrenBottom -= 1;
    }

    // Scan the old children in the middle of the list.
    final bool haveOldChildren = oldChildrenTop <= oldChildrenBottom;
    Map<Key, Element>? oldKeyedChildren;
    if (haveOldChildren) {
      oldKeyedChildren = <Key, Element>{};
      while (oldChildrenTop <= oldChildrenBottom) {
        final Element? oldChild = replaceWithNullIfForgotten(oldChildren[oldChildrenTop]);
        assert(oldChild == null || oldChild._lifecycleState == _ElementLifecycle.active);
        if (oldChild != null) {
          if (oldChild.widget.key != null) {
            oldKeyedChildren[oldChild.widget.key!] = oldChild;
          } else {
            deactivateChild(oldChild);
          }
        }
        oldChildrenTop += 1;
      }
    }

    // Update the middle of the list.
    while (newChildrenTop <= newChildrenBottom) {
      Element? oldChild;
      final Widget newWidget = newWidgets[newChildrenTop];
      if (haveOldChildren) {
        final Key? key = newWidget.key;
        if (key != null) {
          oldChild = oldKeyedChildren![key];
          if (oldChild != null) {
            if (Widget.canUpdate(oldChild.widget, newWidget)) {
              // we found a match!
              // remove it from oldKeyedChildren so we don't unsync it later
              oldKeyedChildren.remove(key);
            } else {
              // Not a match, let's pretend we didn't see it for now.
              oldChild = null;
            }
          }
        }
      }
      assert(oldChild == null || Widget.canUpdate(oldChild.widget, newWidget));
      final Element newChild = updateChild(
        oldChild,
        newWidget,
        slotFor(newChildrenTop, previousChild),
      )!;
      assert(newChild._lifecycleState == _ElementLifecycle.active);
      assert(
        oldChild == newChild ||
            oldChild == null ||
            oldChild._lifecycleState != _ElementLifecycle.active,
      );
      newChildren[newChildrenTop] = newChild;
      previousChild = newChild;
      newChildrenTop += 1;
    }

    // We've scanned the whole list.
    assert(oldChildrenTop == oldChildrenBottom + 1);
    assert(newChildrenTop == newChildrenBottom + 1);
    assert(newWidgets.length - newChildrenTop == oldChildren.length - oldChildrenTop);
    newChildrenBottom = newWidgets.length - 1;
    oldChildrenBottom = oldChildren.length - 1;

    // Update the bottom of the list.
    while ((oldChildrenTop <= oldChildrenBottom) && (newChildrenTop <= newChildrenBottom)) {
      final Element oldChild = oldChildren[oldChildrenTop];
      assert(replaceWithNullIfForgotten(oldChild) != null);
      assert(oldChild._lifecycleState == _ElementLifecycle.active);
      final Widget newWidget = newWidgets[newChildrenTop];
      assert(Widget.canUpdate(oldChild.widget, newWidget));
      final Element newChild = updateChild(
        oldChild,
        newWidget,
        slotFor(newChildrenTop, previousChild),
      )!;
      assert(newChild._lifecycleState == _ElementLifecycle.active);
      assert(oldChild == newChild || oldChild._lifecycleState != _ElementLifecycle.active);
      newChildren[newChildrenTop] = newChild;
      previousChild = newChild;
      newChildrenTop += 1;
      oldChildrenTop += 1;
    }

    // Clean up any of the remaining middle nodes from the old list.
    if (haveOldChildren && oldKeyedChildren!.isNotEmpty) {
      for (final Element oldChild in oldKeyedChildren.values) {
        if (forgottenChildren == null || !forgottenChildren.contains(oldChild)) {
          deactivateChild(oldChild);
        }
      }
    }
    assert(newChildren.every((Element element) => element is! _NullElement));
    return newChildren;
  }
}
/// Used as a placeholder in [List<Element>] objects when the actual
/// elements are not yet determined.
class _NullElement extends Element {
  _NullElement() : super(const _NullWidget());

  static _NullElement instance = _NullElement();
}
class _NullWidget extends Widget {
  const _NullWidget();

  @override
  Element createElement() => throw UnimplementedError();
}
@immutable
class IndexedSlot<T extends Element?> {
  /// Creates an [IndexedSlot] with the provided [index] and slot [value].
  const IndexedSlot(this.index, this.value);

  /// Information to define where the child occupying this slot fits in its
  /// parent's child list.
  final T value;

  /// The index of this slot in the parent's child list.
  final int index;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is IndexedSlot && index == other.index && value == other.value;
  }

  @override
  int get hashCode => Object.hash(index, value);
}
/// An [Element] that uses a [ProxyWidget] as its configuration.
abstract class ProxyElement extends ComponentElement {
  /// Initializes fields for subclasses.
  ProxyElement(ProxyWidget super.widget);

  @override
  Widget build() => (widget as ProxyWidget).child;

  @override
  void update(ProxyWidget newWidget) {
    final oldWidget = widget as ProxyWidget;
    assert(widget != newWidget);
    super.update(newWidget);
    assert(widget == newWidget);
    updated(oldWidget);
    rebuild(force: true);
  }

  /// Called during build when the [widget] has changed.
  ///
  /// By default, calls [notifyClients]. Subclasses may override this method to
  /// avoid calling [notifyClients] unnecessarily (e.g. if the old and new
  /// widgets are equivalent).
  @protected
  void updated(covariant ProxyWidget oldWidget) {
    notifyClients(oldWidget);
  }

  /// Notify other objects that the widget associated with this element has
  /// changed.
  ///
  /// Called during [update] (via [updated]) after changing the widget
  /// associated with this element but before rebuilding this element.
  @protected
  void notifyClients(covariant ProxyWidget oldWidget);
}
class ParentDataElement<T extends ParentData> extends ProxyElement {
  ParentDataElement(ParentDataWidget<T> super.widget);
  void _applyParentData(ParentDataWidget<T> widget) {
    void applyParentDataToChild(Element child) {
      if (child is RenderObjectElement) {
        child._updateParentData(widget);
      } else if (child.renderObjectAttachingChild != null) {
        applyParentDataToChild(child.renderObjectAttachingChild!);
      }
    }

    if (renderObjectAttachingChild != null) {
      applyParentDataToChild(renderObjectAttachingChild!);
    }
  }
  @override
  void notifyClients(ParentDataWidget<T> oldWidget) {
    _applyParentData(widget as ParentDataWidget<T>);
  }
}

class InheritedElement extends ProxyElement {
  InheritedElement(InheritedWidget super.widget);

  final Map<Element, Object?> _dependents = HashMap<Element, Object?>();

  @override
  void _updateInheritance() {
    assert(_active);
    final Map<Type, InheritedElement>? incomingWidgets = _parent?._inheritedElements;
    if (incomingWidgets != null) {
      _inheritedElements = HashMap<Type, InheritedElement>.from(incomingWidgets);
    } else {
      _inheritedElements = HashMap<Type, InheritedElement>();
    }
    _inheritedElements![widget.runtimeType] = this;
  }

  @override
  void notifyClients(InheritedWidget oldWidget) {
    for (final Element dependent in _dependents.keys) {
      notifyDependent(oldWidget, dependent);
    }
  }

  @protected
  void notifyDependent(covariant InheritedWidget oldWidget, Element dependent) {
    dependent.didChangeDependencies();
  }

  @override
  void updated(InheritedWidget oldWidget) {
    if ((widget as InheritedWidget).updateShouldNotify(oldWidget)) {
      super.updated(oldWidget);
    }
  }

  @protected
  Object? getDependencies(Element dependent) {
    return _dependents[dependent];
  }

  @protected
  void setDependencies(Element dependent, Object? value) {
    _dependents[dependent] = value;
  }

  @protected
  void updateDependencies(Element dependent, Object? aspect) {
    setDependencies(dependent, null);
  }

  @protected
  void removeDependent(Element dependent) {
    _dependents.remove(dependent);
  }
}
