import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:tennoji/src/rendering/parent_data.dart';
import 'dart:collection';

import '../widgets/framework.dart';
import '../rendering/object.dart';

class BuildOwner {
  final List<Element> _dirtyElements = [];

  void scheduleBuildFor(Element element) {
    if (!_dirtyElements.contains(element)) {
      _dirtyElements.add(element);
    }
  }

  void buildScope(Element context) {
    // Process dirty elements.
    // Note: We use a simple loop index because rebuilding an element might
    // add more elements to the list (e.g. children marked dirty).
    int i = 0;
    while (i < _dirtyElements.length) {
      final element = _dirtyElements[i];
      if (element._dirty && element._active) {
        element.rebuild();
      }
      i++;
    }
    _dirtyElements.clear();
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
}
abstract class Element implements BuildContext {
  Element(this._widget);
  Widget? _widget;

  Logger get _log => Logger('Element.${runtimeType}');
  Object? _slot;
  Object? get slot => _slot;

  @override
  Widget get widget => _widget!;

  Element? _parent;
  BuildOwner? _owner;
  
  BuildOwner? get owner => _owner;

  //RenderObject? _renderObject;
  bool _active = false;
  bool _dirty = true;

  RenderObject? get renderObject {
    RenderObject? result;
    void visitor(Element element) {
      if (result != null) return;
      result = element.renderObject;
    }
    visitChildren(visitor);
    return result;
  }
 
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

  void visitChildren(void Function(Element element) visitor);

  _ElementLifecycle _lifecycleState = _ElementLifecycle.initial;

  Map<Type, InheritedElement>? _inheritedWidgets;
  Set<InheritedElement>? _dependencies;

  @override
  T? dependOnInheritedWidgetOfExactType<T>() {
    assert(_active);
    final ancestor = _inheritedWidgets?[T];
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
    _inheritedWidgets = _parent?._inheritedWidgets;
  }

  void didChangeDependencies() {
    markNeedsBuild();
  }

  void mount(Element? parent, Object? newSlot) {
    _log.finer('Mounting');
    _parent = parent;
    _owner = parent?.owner;
    _active = true;
    _lifecycleState = _ElementLifecycle.active;
    _updateInheritance();
  }
  
  void assignOwner(BuildOwner owner) {
    _owner = owner;
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
    _inheritedWidgets = null;

    _active = false;
    _lifecycleState = _ElementLifecycle.defunct;
  }

  void markNeedsBuild() {
    if (_dirty && _active) return;
    _dirty = true;
    _owner?.scheduleBuildFor(this);
  }

  Widget build();
}

class ComponentElement extends Element {
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
    _child = updateChild(_child, built, null);
    super.performRebuild();
  }

  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    if (newWidget == null) {
      if (child != null) {
        child.unmount();
      }
      return null;
    }
    if (child != null) {
      if (identical(child.widget, newWidget)) {
        return child;
      }
      child.update(newWidget);
      return child;
    }
    final newChild = newWidget.createElement();
    newChild.mount(this, newSlot);
    return newChild;
  }

  @override
  Widget build() => throw UnimplementedError('Subclass must override build');
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

  final List<Element> _children = [];
  RenderObject? _renderObject;

  @override
  RenderObject? get renderObject => _renderObject;

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
      ancestor = ancestor?._parent;
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
  @override
  void visitChildren(void Function(Element element) visitor) {
    for (final Element child in _children) {
      visitor(child);
    }
  }
  List<ParentDataElement<ParentData>> _findAncestorParentDataElements() {
    Element? ancestor = _parent;
    final result = <ParentDataElement<ParentData>>[];
    final debugAncestorTypes = <Type>{};
    final debugParentDataTypes = <Type>{};
    final debugAncestorCulprits = <Type>[];

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
    _ancestorRenderObjectElement?.insertRenderObjectChild(renderObject!, newSlot);
    final List<ParentDataElement<ParentData>> parentDataElements =
        _findAncestorParentDataElements();
    for (final parentDataElement in parentDataElements) {
      _updateParentData(parentDataElement.widget as ParentDataWidget<ParentData>);
    }
  }
  @override
  void detachRenderObject() {
    if (_ancestorRenderObjectElement != null) {
      _ancestorRenderObjectElement!.removeRenderObjectChild(renderObject!, slot);
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
    assert(!_renderObject!.debugDisposed!);
    assert(() {
      _debugDoingBuild = false;
      return true;
    }());
    assert(() {
      _debugUpdateRenderObjectOwner();
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
        parentDataWidget.applyParentData(_renderObject!);
      }
    }
  }

  void _attachToParentRenderObject() {
    // Walk up to find the nearest ancestor render object with ContainerRenderObjectMixin
    // This is handled by the parent's _adoptChildRenderObject call
  }

  void _adoptChildRenderObject(Element childElement) {
    final childRenderObject = childElement.renderObject;
    if (childRenderObject != null && _renderObject is ContainerRenderObjectMixin) {
      (_renderObject as ContainerRenderObjectMixin).add(childRenderObject);
    }
  }

  @override
  void update(covariant RenderObjectWidget newWidget) {
    super.update(newWidget);
    newWidget.updateRenderObject(this, _renderObject!);

    // Reconcile children (Naive "nuke and pave" approach)
    // 1. Unmount old children
    final oldChildren = List<Element>.of(_children);
    _children.clear();
    
    for (final child in oldChildren) {
      final childRenderObject = child.renderObject;
      if (childRenderObject != null && _renderObject is ContainerRenderObjectMixin) {
        (_renderObject as ContainerRenderObjectMixin).remove(childRenderObject);
      }
      child.unmount();
    }

    // 2. Mount new children
    final w = widget;
    if (w is SingleChildRenderObjectWidget && w.child != null) {
      final childElement = w.child!.createElement();
      _children.add(childElement);
      childElement.mount(this, null);
      _adoptChildRenderObject(childElement);
    } else if (w is MultiChildRenderObjectWidget) {
      for (final childWidget in w.children) {
        final childElement = childWidget.createElement();
        _children.add(childElement);
        childElement.mount(this, null);
        _adoptChildRenderObject(childElement);
      }
    }
  }

  @override
  void unmount() {
    for (final child in _children) {
      child.unmount();
    }
    _renderObject!.detach();
    super.unmount();
  }

  @override
  Widget build() =>
      throw UnimplementedError('RenderObjectElement does not build');
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
    final Map<Type, InheritedElement>? incomingWidgets = _parent?._inheritedWidgets;
    if (incomingWidgets != null) {
      _inheritedWidgets = HashMap<Type, InheritedElement>.from(incomingWidgets);
    } else {
      _inheritedWidgets = HashMap<Type, InheritedElement>();
    }
    _inheritedWidgets![widget.runtimeType] = this;
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
