import 'dart:math' as math;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:tennoji/src/rendering/parent_data.dart';
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

/// Signature for a function that is called for each [RenderObject].
///
/// Used by [RenderObject.visitChildren] and [RenderObject.visitChildrenForSemantics].
typedef RenderObjectVisitor = void Function(RenderObject child);
abstract class RenderObject {
  RenderObject? _parent;
  PipelineOwner? _owner;
  bool _needsLayout = true;
  bool _needsPaint = true;
  Size? _size;
  ParentData? parentData;

  RenderObject? get parent => _parent;
  PipelineOwner? get owner => _owner;

  Logger get _log => Logger('RenderObject.${runtimeType}');

  bool get needsLayout => _needsLayout;
  bool get needsPaint => _needsPaint;
  bool get attached => _owner != null;
  Size get size => _size!;
  set size(Size value) => _size = value;

  /// Whether this [RenderObject] is a known relayout boundary.
  ///
  /// A relayout boundary is a [RenderObject] whose parent does not rely on the
  /// child [RenderObject]'s size in its own layout algorithm. In other words,
  /// if a [RenderObject]'s [performLayout] implementation does not ask the child
  /// for its size at all, **the child** is a relayout boundary.
  ///
  /// The type of "size" is typically defined by the coordinate system a
  /// [RenderObject] subclass uses. For instance, [RenderSliver]s produce
  /// [SliverGeometry] and [RenderBox]es produce [Size]. A parent [RenderObject]
  /// may not read the child's size but still depend on the child's layout (using
  /// a [RenderBox] child's baseline location, for example), this flag does not
  /// reflect such dependencies and the [RenderObject] subclass must handle those
  /// cases in its own implementation. See [RenderBox.markNeedsLayout] for an
  /// example.
  ///
  /// Relayout boundaries enable an important layout optimization: the parent not
  /// depending on the size of a child means the child changing size does not
  /// affect the layout of the parent. When a relayout boundary is marked as
  /// needing layout, its parent does not have to be marked as dirty, hence the
  /// name. For details, see [markNeedsLayout].
  ///
  /// This flag is typically set in [RenderObject.layout], and consulted by
  /// [markNeedsLayout] in deciding whether to recursively mark the parent as
  /// also needing layout.
  ///
  /// The flag is initially set to `null` when [layout] has yet been called, and
  /// reset to `null` when the parent drops this child via [dropChild].
  bool? _isRelayoutBoundary;

  /// Override to setup parent data correctly for your children.
  ///
  /// You can call this function to set up the parent data for child before the
  /// child is added to the parent's child list.
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! ParentData) {
      child.parentData = ParentData();
    }
  }
  /// Clears the needs-layout flag. Called by subclasses after performing layout.
  void clearNeedsLayout() {
    _needsLayout = false;
  }

  /// Clears the needs-paint flag. Called after painting.
  void clearNeedsPaint() {
    _needsPaint = false;
  }

  void markNeedsLayout() {
    _log.finest('markNeedsLayout');
    _needsLayout = true;
    if (_isRelayoutBoundary ?? true) {
      _owner?.requestLayout(this);
    } else if (parent != null) {
      markParentNeedsLayout();
    }
  }
  void markParentNeedsLayout() {
    _log.finest('markParentNeedsLayout');
    _needsLayout = true;
    assert(parent != null);
    parent!.markNeedsLayout();
  }

  void markNeedsPaint() {
    _log.finest('markNeedsPaint');
    _needsPaint = true;
    _owner?.requestPaint(this);
  }

  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    _log.finer('layout with $constraints');
    _needsLayout = false;
  }

  void paint(PaintingContext context, Offset offset);

  void attach(PipelineOwner owner) {
    _owner = owner;
    if (_needsLayout) {
    }
    if (_needsPaint) {
      _owner!.requestPaint(this);
    }
  }

  void detach() {
    _owner = null;
  }

  /// The depth of this render object in the render tree.
  ///
  /// The depth of nodes in a tree monotonically increases as you traverse down
  /// the tree: a node always has a [depth] greater than its ancestors.
  /// There's no guarantee regarding depth between siblings.
  ///
  /// The [depth] of a child can be more than one greater than the [depth] of
  /// the parent, because the [depth] values are never decreased: all that
  /// matters is that it's greater than the parent. Consider a tree with a root
  /// node A, a child B, and a grandchild C. Initially, A will have [depth] 0,
  /// B [depth] 1, and C [depth] 2. If C is moved to be a child of A,
  /// sibling of B, then the numbers won't change. C's [depth] will still be 2.
  ///
  /// The depth of a node is used to ensure that nodes are processed in
  /// depth order.  The [depth] is automatically maintained by the [adoptChild]
  /// and [dropChild] methods.
  int get depth => _depth;
  int _depth = 0;

  /// Adjust the [depth] of the given [child] to be greater than this node's own
  /// [depth].
  ///
  /// Only call this method from overrides of [redepthChildren].
  @protected
  void redepthChild(RenderObject child) {
    assert(child.owner == owner);
    if (child._depth <= _depth) {
      child._depth = _depth + 1;
      child.redepthChildren();
    }
  }

  void visitChildren(RenderObjectVisitor visitor) {}
  /// Adjust the [depth] of this node's children, if any.
  ///
  /// Override this method in subclasses with child nodes to call [redepthChild]
  /// for each child. Do not call this method directly.
  @protected
  void redepthChildren() {}
  /// Called by subclasses when they decide a render object is a child.
  ///
  /// Only for use by subclasses when changing their child lists. Calling this
  /// in other cases will lead to an inconsistent tree and probably cause crashes.
  @mustCallSuper
  @protected
  void adoptChild(RenderObject child) {
    assert(child._parent == null);
    assert(() {
      var node = this;
      while (node.parent != null) {
        node = node.parent!;
      }
      assert(node != child); // indicates we are about to create a cycle
      return true;
    }());

    setupParentData(child);
    markNeedsLayout();
    //markNeedsCompositingBitsUpdate();
    child._parent = this;
    if (attached) {
      child.attach(_owner!);
    }
    redepthChild(child);
  }
  /// Called by subclasses when they decide a render object is no longer a child.
  ///
  /// Only for use by subclasses when changing their child lists. Calling this
  /// in other cases will lead to an inconsistent tree and probably cause crashes.
  @mustCallSuper
  @protected
  void dropChild(RenderObject child) {
    assert(child._parent == this);
    assert(child.attached == attached);
    assert(child.parentData != null);
    if (!(child._isRelayoutBoundary ?? true)) {
      child._isRelayoutBoundary = null;
    }
    child.parentData!.detach();
    child.parentData = null;
    child._parent = null;
    if (attached) {
      child.detach();
    }
    markNeedsLayout();
    //markNeedsCompositingBitsUpdate();
    //markNeedsSemanticsUpdate();
  }
}
mixin ContainerParentDataMixin<ChildType extends RenderObject> on ParentData {
  /// The previous sibling in the parent's child list.
  ChildType? previousSibling;

  /// The next sibling in the parent's child list.
  ChildType? nextSibling;

  /// Clear the sibling pointers.
  @override
  void detach() {
    assert(
      previousSibling == null,
      'Pointers to siblings must be nulled before detaching ParentData.',
    );
    assert(nextSibling == null, 'Pointers to siblings must be nulled before detaching ParentData.');
    super.detach();
  }
}
/// Mixin for render objects that have a list of children.
mixin ContainerRenderObjectMixin<
  ChildType extends RenderObject,
  ParentDataType extends ContainerParentDataMixin<ChildType>
> on RenderObject { 
  int _childCount = 0;

  /// The number of children.
  int get childCount => _childCount;

  ChildType? _firstChild;
  ChildType? _lastChild;
  void _insertIntoChildList(ChildType child, {ChildType? after}) {
    final childParentData = child.parentData! as ParentDataType;
    assert(childParentData.nextSibling == null);
    assert(childParentData.previousSibling == null);
    _childCount += 1;
    assert(_childCount > 0);
    if (after == null) {
      // insert at the start (_firstChild)
      childParentData.nextSibling = _firstChild;
      if (_firstChild != null) {
        final firstChildParentData = _firstChild!.parentData! as ParentDataType;
        firstChildParentData.previousSibling = child;
      }
      _firstChild = child;
      _lastChild ??= child;
    } else {
      assert(_firstChild != null);
      assert(_lastChild != null);
     // assert(_debugUltimatePreviousSiblingOf(after, equals: _firstChild));
      //assert(_debugUltimateNextSiblingOf(after, equals: _lastChild));
      final afterParentData = after.parentData! as ParentDataType;
      if (afterParentData.nextSibling == null) {
        // insert at the end (_lastChild); we'll end up with two or more children
        assert(after == _lastChild);
        childParentData.previousSibling = after;
        afterParentData.nextSibling = child;
        _lastChild = child;
      } else {
        // insert in the middle; we'll end up with three or more children
        // set up links from child to siblings
        childParentData.nextSibling = afterParentData.nextSibling;
        childParentData.previousSibling = after;
        // set up links from siblings to child
        final childPreviousSiblingParentData =
            childParentData.previousSibling!.parentData! as ParentDataType;
        final childNextSiblingParentData =
            childParentData.nextSibling!.parentData! as ParentDataType;
        childPreviousSiblingParentData.nextSibling = child;
        childNextSiblingParentData.previousSibling = child;
        assert(afterParentData.nextSibling == child);
      }
    }
  }

  /// Insert child into this render object's child list after the given child.
  ///
  /// If `after` is null, then this inserts the child at the start of the list,
  /// and the child becomes the new [firstChild].
  void insert(ChildType child, {ChildType? after}) {
    assert(child != this, 'A RenderObject cannot be inserted into itself.');
    assert(
      after != this,
      'A RenderObject cannot simultaneously be both the parent and the sibling of another RenderObject.',
    );
    assert(child != after, 'A RenderObject cannot be inserted after itself.');
    assert(child != _firstChild);
    assert(child != _lastChild);
    adoptChild(child);
    assert(
      child.parentData is ParentDataType,
      'A child of $runtimeType has parentData of type ${child.parentData.runtimeType}, '
      'which does not conform to $ParentDataType. Class using ContainerRenderObjectMixin '
      'should override setupParentData() to set parentData to type $ParentDataType.',
    );
    _insertIntoChildList(child, after: after);
  }

  /// Append child to the end of this render object's child list.
  void add(ChildType child) {
    insert(child, after: _lastChild);
  }

  /// Add all the children to the end of this render object's child list.
  void addAll(List<ChildType>? children) {
    children?.forEach(add);
  }

  void _removeFromChildList(ChildType child) {
    final childParentData = child.parentData! as ParentDataType;
    //assert(_debugUltimatePreviousSiblingOf(child, equals: _firstChild));
    //assert(_debugUltimateNextSiblingOf(child, equals: _lastChild));
    assert(_childCount >= 0);
    if (childParentData.previousSibling == null) {
      assert(_firstChild == child);
      _firstChild = childParentData.nextSibling;
    } else {
      final childPreviousSiblingParentData =
          childParentData.previousSibling!.parentData! as ParentDataType;
      childPreviousSiblingParentData.nextSibling = childParentData.nextSibling;
    }
    if (childParentData.nextSibling == null) {
      assert(_lastChild == child);
      _lastChild = childParentData.previousSibling;
    } else {
      final childNextSiblingParentData = childParentData.nextSibling!.parentData! as ParentDataType;
      childNextSiblingParentData.previousSibling = childParentData.previousSibling;
    }
    childParentData.previousSibling = null;
    childParentData.nextSibling = null;
    _childCount -= 1;
  }

  /// Remove this child from the child list.
  ///
  /// Requires the child to be present in the child list.
  void remove(ChildType child) {
    _removeFromChildList(child);
    dropChild(child);
  }

  /// Remove all their children from this render object's child list.
  ///
  /// More efficient than removing them individually.
  void removeAll() {
    ChildType? child = _firstChild;
    while (child != null) {
      final childParentData = child.parentData! as ParentDataType;
      final ChildType? next = childParentData.nextSibling;
      childParentData.previousSibling = null;
      childParentData.nextSibling = null;
      dropChild(child);
      child = next;
    }
    _firstChild = null;
    _lastChild = null;
    _childCount = 0;
  }

  /// Move the given `child` in the child list to be after another child.
  ///
  /// More efficient than removing and re-adding the child. Requires the child
  /// to already be in the child list at some position. Pass null for `after` to
  /// move the child to the start of the child list.
  void move(ChildType child, {ChildType? after}) {
    assert(child != this);
    assert(after != this);
    assert(child != after);
    assert(child.parent == this);
    final childParentData = child.parentData! as ParentDataType;
    if (childParentData.previousSibling == after) {
      return;
    }
    _removeFromChildList(child);
    _insertIntoChildList(child, after: after);
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    ChildType? child = _firstChild;
    while (child != null) {
      child.attach(owner);
      final childParentData = child.parentData! as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  @override
  void detach() {
    super.detach();
    ChildType? child = _firstChild;
    while (child != null) {
      child.detach();
      final childParentData = child.parentData! as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  @override
  void redepthChildren() {
    ChildType? child = _firstChild;
    while (child != null) {
      redepthChild(child);
      final childParentData = child.parentData! as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  @override
  void visitChildren(void Function(RenderObject) visitor) {
    ChildType? child = _firstChild;
    while (child != null) {
      visitor(child);
      final childParentData = child.parentData! as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  /// The first child in the child list.
  ChildType? get firstChild => _firstChild;

  /// The last child in the child list.
  ChildType? get lastChild => _lastChild;

  /// The previous child before the given child in the child list.
  ChildType? childBefore(ChildType child) {
    assert(child.parent == this);
    final childParentData = child.parentData! as ParentDataType;
    return childParentData.previousSibling;
  }

  /// The next child after the given child in the child list.
  ChildType? childAfter(ChildType child) {
    assert(child.parent == this);
    final childParentData = child.parentData! as ParentDataType;
    return childParentData.nextSibling;
  }
}
