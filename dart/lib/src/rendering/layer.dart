import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:typed_data';
import '../dart_ui/dart_ui.dart';

class LayerHandle<T extends Layer> {
  LayerHandle([this._layer]) {
    if (_layer != null) {
      _layer!._ref();
    }
  }
  T? _layer;
  
  T? get layer => _layer;
  set layer(T? value) {
    _layer?._unref();
    _layer = value;
    _layer?._ref();
  }
}

abstract class Layer {
  int _refCount = 0;
  void _ref() => _refCount++;
  void _unref() {
    _refCount--;
    if (_refCount == 0) dispose();
  }


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

  final LayerHandle<Layer> _parentHandle = LayerHandle<Layer>();

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
    parent?._removeChild(this);
  }

  /// Subclasses should override to paint themselves.
  void addToScene(Canvas canvas);

  void dispose() {}
  
  /// Update the depth of this layer.
  void updateSubtreeDepth() {
    final int expectedDepth = parent != null ? parent!.depth + 1 : 0;
    if (_depth != expectedDepth) {
      _depth = expectedDepth;
      redepthChildren();
    }
  }
  
  /// Override in subclasses to update child depths.
  @protected
  void redepthChildren() {}
}

mixin DontSkipOnEmptyChildren on ContainerLayer {}

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
    super.attach(owner);
    Layer? child = firstChild;
    while (child != null) {
      child.attach(owner);
      child = child.nextSibling;
    }
  }

  @override
  void detach() {
    super.detach();
    Layer? child = firstChild;
    while (child != null) {
      child.detach();
      child = child.nextSibling;
    }
  }

  @override
  void addToScene(Canvas canvas) {
    addChildrenToScene(canvas);
  }

  void addChildrenToScene(Canvas canvas) {
    Layer? child = firstChild;
    while (child != null) {
      // skip child if its non-leaf and does not have any children
      // and does not explicitly told the framework to exclude it from this check
      if (child is ContainerLayer && !child.hasChildren /*&& child is! DontSkipOnEmptyChildren*/) {
        child = child.nextSibling;
        continue;
      }
      child.addToScene(canvas);
      child = child.nextSibling;
    }
  }

  void append(Layer child) {
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

  void _removeChild(Layer child) {
    assert(child.parent == this);
    assert(child._parentHandle.layer == child);
    
    child._parentHandle.layer = null;
    
    if (child._previousSibling == null) {
      assert(_firstChild == child);
      _firstChild = child._nextSibling;
    } else {
      child._previousSibling!._nextSibling = child._nextSibling;
    }
    
    if (child._nextSibling == null) {
      assert(_lastChild == child);
      _lastChild = child._previousSibling;
    } else {
      child._nextSibling!._previousSibling = child._previousSibling;
    }
    
    child._previousSibling = null;
    child._nextSibling = null;
    _dropChild(child);
  }

  void removeAllChildren() {
    Layer? child = firstChild;
    while (child != null) {
      final Layer? next = child.nextSibling;
      child._previousSibling = null;
      child._nextSibling = null;
      child._parentHandle.layer = null;
      _dropChild(child);
      child = next;
    }
    _firstChild = null;
    _lastChild = null;
  }

  void _adoptChild(Layer child) {
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

  void _dropChild(Layer child) {
    assert(child._parent == this);
    assert(child.attached == attached);
    child._parent = null;
    if (attached) {
      child.detach();
    }
  }

  void redepthChild(Layer child) {
    assert(child.owner == owner);
    if (child._depth <= _depth) {
      child._depth = _depth + 1;
      child.redepthChildren();
    }
  }

  @override
  void redepthChildren() {
    Layer? child = firstChild;
    while (child != null) {
      redepthChild(child);
      child = child.nextSibling;
    }
  }
}

/// A layer that clips its children.
class ClipRectLayer extends ContainerLayer {
  ClipRectLayer({Rect? clipRect, this.clipBehavior}) : _clipRect = clipRect;
  
  Rect? _clipRect;
  Rect? get clipRect => _clipRect;
  set clipRect(Rect? value) {
    if (_clipRect != value) {
      _clipRect = value;
    }
  }

  Clip? clipBehavior;

  @override
  void addToScene(Canvas canvas) {
    assert(_clipRect != null);
    final clipBehavior2 = clipBehavior ?? .none;
    if (clipBehavior2 != .none) {
      canvas.save();
      canvas.clipRect(_clipRect!, clipBehavior2 == .antiAlias);
    }
    addChildrenToScene(canvas);
    if (clipBehavior2 != .none) canvas.restore();
  }
}

/// A layer that transforms its children.
class TransformLayer extends ContainerLayer {
  TransformLayer({required Matrix4 transform}) : _transform = transform;
  
  Matrix4 _transform;
  Matrix4 get transform => _transform;
  set transform(Matrix4 value) {
    if (_transform != value) {
      _transform = value;
    }
  }

  @override
  void addToScene(Canvas canvas) {
    canvas.save();
    canvas.transform(_transform);
    addChildrenToScene(canvas);
    canvas.restore();
  }
}

/// A layer that applies opacity to its children.
class OpacityLayer extends ContainerLayer {
  OpacityLayer({required int alpha}) : _alpha = alpha;
  
  int _alpha;
  int get alpha => _alpha;
  set alpha(int value) {
    if (_alpha != value) {
      _alpha = value;
    }
  }

  @override
  void addToScene(Canvas canvas) {
    final paint = Paint()..color = Color.fromARGB(_alpha, 255, 255, 255);
    canvas.saveLayer(paint);
    addChildrenToScene(canvas);
    canvas.restore();
  }
}

/// A layer that represents a picture to be painted.
class PictureLayer extends Layer {
  PictureLayer(this.canvasRect);
  
  final Rect canvasRect;

  Picture? picture;

  @override
  void addToScene(Canvas canvas) {
    canvas.drawPicture(picture!);
  }
  
  @override
  void dispose() {
    picture?.dispose();
    super.dispose();
  }
}

class OffsetLayer extends ContainerLayer {
  OffsetLayer({Offset offset = Offset.zero}) : _offset = offset;
  
  Offset _offset;
  Offset get offset => _offset;
  set offset(Offset value) {
    if (_offset != value) {
      _offset = value;
    }
  }

  @override
  void addToScene(Canvas canvas) {
    if (_offset != Offset.zero) {
      canvas.save();
      canvas.translate(_offset.dx, _offset.dy);
    }
    addChildrenToScene(canvas);
    if (_offset != Offset.zero) canvas.restore();
  }
}

class ColorFilterLayer extends ContainerLayer {
  ColorFilterLayer({ColorFilter? colorFilter}) : _colorFilter = colorFilter;
  
  ColorFilter? _colorFilter;
  ColorFilter? get colorFilter => _colorFilter;
  set colorFilter(ColorFilter value) {
    if (_colorFilter != value) {
      _colorFilter = value;
    }
  }

  @override
  void addToScene(Canvas canvas) {
    if (_colorFilter != null) {
      final paint = Paint()..colorFilter = _colorFilter;
      canvas.saveLayer(paint);
    }
    addChildrenToScene(canvas);
    if (_colorFilter != null) canvas.restore();
  }
}
