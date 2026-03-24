import 'package:meta/meta.dart';
import 'dart:collection';

import '../widgets/framework.dart';
import '../rendering/object.dart';
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

  @override
  Widget get widget => _widget!;

  Element? _parent;
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
    _parent = parent;
    _active = true;
    _lifecycleState = _ElementLifecycle.active;
    _updateInheritance();
  }

  void rebuild({bool force=false}) {
    if (_lifecycleState != _ElementLifecycle.active || (!_dirty && !force)) {
      return;
    }
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
    _dirty = true;
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

class RenderObjectElement extends Element {
  RenderObjectElement(RenderObjectWidget super.widget);

  final List<Element> _children = [];
  RenderObject? _renderObject;

  @override
  RenderObject? get renderObject => _renderObject;

  @override
  void visitChildren(void Function(Element element) visitor) {
    for (final Element child in _children) {
      visitor(child);
    }
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _renderObject = (widget as RenderObjectWidget).createRenderObject(this);

    // Attach to parent's render object if it has a container mixin
    _attachToParentRenderObject();

    // Mount children based on widget type
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
