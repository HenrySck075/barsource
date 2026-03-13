import '../widgets/framework.dart';
import '../rendering/object.dart';

abstract class Element implements BuildContext {
  Element(this._widget);
  Widget _widget;

  @override
  Widget get widget => _widget;

  Element? _parent;
  RenderObject? _renderObject;
  bool _active = false;
  bool _dirty = true;

  RenderObject? get renderObject => _renderObject;

  void mount(Element? parent, Object? newSlot) {
    _parent = parent;
    _active = true;
  }

  void update(covariant Widget newWidget) {
    _widget = newWidget;
  }

  void unmount() {
    _active = false;
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
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _firstBuild();
  }

  void _firstBuild() {
    rebuild();
  }

  void rebuild() {
    Widget built = build();
    _child = updateChild(_child, built, null);
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
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _state.initState();
  }

  @override
  Widget build() => _state.build(this);
}

class RenderObjectElement extends Element {
  RenderObjectElement(RenderObjectWidget super.widget);

  final List<Element> _children = [];

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
    final childRenderObject = _findChildRenderObject(childElement);
    if (childRenderObject != null && _renderObject is ContainerRenderObjectMixin) {
      (_renderObject as ContainerRenderObjectMixin).add(childRenderObject);
    }
  }

  /// Walk down through component elements to find the nearest render object.
  RenderObject? _findChildRenderObject(Element element) {
    if (element.renderObject != null) return element.renderObject;
    // For component elements, check their built child
    if (element is ComponentElement && element._child != null) {
      return _findChildRenderObject(element._child!);
    }
    return null;
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
