import 'dart:math' as math;
import '../foundation/geometry.dart';
import '../painting/canvas.dart';
import '../painting/edge_insets.dart';
import 'pipeline_owner.dart';

abstract class Constraints {
  const Constraints();
  bool get isTight;
}

class BoxConstraints extends Constraints {
  const BoxConstraints({
    this.minWidth = 0.0,
    this.maxWidth = double.infinity,
    this.minHeight = 0.0,
    this.maxHeight = double.infinity,
  });
  final double minWidth;
  final double maxWidth;
  final double minHeight;
  final double maxHeight;

  /// Tight constraints with a specific size.
  BoxConstraints.tight(Size size)
      : minWidth = size.width,
        maxWidth = size.width,
        minHeight = size.height,
        maxHeight = size.height;

  /// Loose constraints that allow anything up to the given size.
  BoxConstraints.loose(Size size)
      : minWidth = 0.0,
        maxWidth = size.width,
        minHeight = 0.0,
        maxHeight = size.height;

  @override
  bool get isTight => minWidth == maxWidth && minHeight == maxHeight;

  bool get hasBoundedWidth => maxWidth < double.infinity;
  bool get hasBoundedHeight => maxHeight < double.infinity;

  double constrainWidth([double width = double.infinity]) {
    return width.clamp(minWidth, maxWidth);
  }

  double constrainHeight([double height = double.infinity]) {
    return height.clamp(minHeight, maxHeight);
  }

  Size constrain(Size size) {
    return Size(constrainWidth(size.width), constrainHeight(size.height));
  }

  BoxConstraints loosen() {
    return BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  BoxConstraints tighten({double? width, double? height}) {
    return BoxConstraints(
      minWidth: width ?? minWidth,
      maxWidth: width ?? maxWidth,
      minHeight: height ?? minHeight,
      maxHeight: height ?? maxHeight,
    );
  }

  BoxConstraints deflate(EdgeInsets insets) {
    final double horizontal = insets.left + insets.right;
    final double vertical = insets.top + insets.bottom;
    final double deflatedMinWidth = math.max(0.0, minWidth - horizontal);
    final double deflatedMinHeight = math.max(0.0, minHeight - vertical);
    return BoxConstraints(
      minWidth: deflatedMinWidth,
      maxWidth: math.max(deflatedMinWidth, maxWidth - horizontal),
      minHeight: deflatedMinHeight,
      maxHeight: math.max(deflatedMinHeight, maxHeight - vertical),
    );
  }

  static const BoxConstraints expand = BoxConstraints(
    minWidth: double.infinity,
    maxWidth: double.infinity,
    minHeight: double.infinity,
    maxHeight: double.infinity,
  );

  bool debugAssertIsValid() {
    assert(minWidth >= 0.0 && minWidth <= maxWidth);
    assert(minHeight >= 0.0 && minHeight <= maxHeight);
    return true;
  }
}

class PaintingContext {
  PaintingContext(this.canvas);
  final Canvas canvas;

  void paintChild(RenderObject child, Offset offset) {
    child.paint(this, offset);
  }
}

abstract class RenderObject {
  RenderObject? parent;
  PipelineOwner? _owner;
  bool _needsLayout = true;
  bool _needsPaint = true;
  Size? _size;

  bool get needsLayout => _needsLayout;
  bool get needsPaint => _needsPaint;
  Size get size => _size!;
  set size(Size value) => _size = value;

  /// Clears the needs-layout flag. Called by subclasses after performing layout.
  void clearNeedsLayout() {
    _needsLayout = false;
  }

  /// Clears the needs-paint flag. Called after painting.
  void clearNeedsPaint() {
    _needsPaint = false;
  }

  void markNeedsLayout() {
    _needsLayout = true;
    _owner?.requestLayout(this);
  }

  void markNeedsPaint() {
    _needsPaint = true;
    _owner?.requestPaint(this);
  }

  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    _needsLayout = false;
  }

  void paint(PaintingContext context, Offset offset);

  void attach(PipelineOwner owner) {
    _owner = owner;
  }

  void detach() {
    _owner = null;
  }
}

/// Mixin for render objects that have a list of children.
mixin ContainerRenderObjectMixin on RenderObject {
  final List<RenderObject> _children = [];

  List<RenderObject> get children => _children;

  void add(RenderObject child) {
    child.parent = this;
    _children.add(child);
    if (_owner != null) {
      child.attach(_owner!);
    }
    markNeedsLayout();
  }

  void remove(RenderObject child) {
    _children.remove(child);
    child.parent = null;
    child.detach();
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final child in _children) {
      child.attach(owner);
    }
  }

  @override
  void detach() {
    for (final child in _children) {
      child.detach();
    }
    super.detach();
  }
}
