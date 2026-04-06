import 'package:meta/meta.dart';

abstract class Layer {
  int _depth = 0;
  int get depth => _depth;

  Layer? _previousSibling;
  Layer? _nextSibling;

  Layer? get previousSibling => _previousSibling;
  Layer? get nextSibling => _nextSibling;

  ContainerLayer? _parent;
  ContainerLayer? get parent => _parent;

  Object? _owner;
  Object? get owner => _owner;
  bool get attached => owner != null;

  @mustCallSuper
  void attach(covariant Object owner) {
    assert(_owner == null);
    _owner = owner;
  }
  @mustCallSuper
  void detach() {
    assert(_owner != null);
    _owner = null;
    assert(parent == null || attached == parent!.attached);
  }
  @mustCallSuper
  void remove() {
    //assert(!_debugMutationsLocked);
    parent?._removeChild(this);
  }

  /// i propose pulling another Canvas to pass down to the layer tree
  /// but you do you i guess

  void dispose() {}
}

abstract class ContainerLayer extends Layer {
  Layer? _firstChild;
  Layer? get firstChild => _firstChild;
  Layer? _lastChild;
  Layer? get lastChild => _lastChild;

  bool get hasChildren => _firstChild != null;

  @override
  void dispose() {
    removeAllChildren();
    super.dispose();
  }
  @override
  void attach(Object owner) {
    //assert(!_debugMutationsLocked);
    super.attach(owner);
    Layer? child = firstChild;
    while (child != null) {
      child.attach(owner);
      child = child.nextSibling;
    }
  }

  @override
  void detach() {
    //assert(!_debugMutationsLocked);
    super.detach();
    Layer? child = firstChild;
    while (child != null) {
      child.detach();
      child = child.nextSibling;
    }
    // Detach indicates that we may never be composited again. Clients
    // interested in observing composition need to get an update here because
    // they might otherwise never get another one even though the layer is no
    // longer visible.
    //
    // Children fired them already in child.detach().
    //_fireCompositionCallbacks(includeChildren: false);
  }


  void append(Layer child) {
    //assert(!_debugMutationsLocked);
    assert(child != this);
    assert(child != firstChild);
    assert(child != lastChild);
    assert(child.parent == null);
    assert(!child.attached);
    assert(child.nextSibling == null);
    assert(child.previousSibling == null);
    assert(child._parentHandle.layer == null);
    assert(() {
      Layer node = this;
      while (node.parent != null) {
        node = node.parent!;
      }
      assert(node != child); // indicates we are about to create a cycle
      return true;
    }());
    _adoptChild(child);
    child._previousSibling = lastChild;
    if (lastChild != null) {
      lastChild!._nextSibling = child;
    }
    _lastChild = child;
    _firstChild ??= child;
    child._parentHandle.layer = child;
    assert(child.attached == attached);
  }

  void _adoptChild(Layer child) {
    /*
    assert(!_debugMutationsLocked);
    if (!alwaysNeedsAddToScene) {
      markNeedsAddToScene();
    }
    if (child._compositionCallbackCount != 0) {
      _updateSubtreeCompositionObserverCount(child._compositionCallbackCount);
    }
    */
    assert(child._parent == null);
    assert(() {
      Layer node = this;
      while (node.parent != null) {
        node = node.parent!;
      }
      assert(node != child); // indicates we are about to create a cycle
      return true;
    }());
    child._parent = this;
    if (attached) {
      child.attach(_owner!);
    }
    redepthChild(child);
  }
}
