import 'dart:math' as math;

import 'package:barsource/src/rendering/parent_data.dart';

import 'box.dart';
import 'object.dart';

import '../painting/basic_types.dart';

/// How children are placed along the main axis.
enum MainAxisAlignment {
  start,
  end,
  center,
  spaceBetween,
  spaceAround,
  spaceEvenly,
}

/// How children are placed along the cross axis.
enum CrossAxisAlignment {
  start,
  end,
  center,
  stretch,
}

/// How much space a flex container should occupy on the main axis.
enum MainAxisSize {
  /// As small as possible on the main axis.
  min,

  /// As large as possible on the main axis.
  max,
}

/// Data stored per child in a flex layout.
class FlexParentData extends ParentData with ContainerParentDataMixin<RenderBox> {
  int flex;
  FlexFit fit;

  FlexParentData({this.flex = 0, this.fit = FlexFit.tight});
}

/// How a flex child is inscribed into the available space.
enum FlexFit {
  tight,
  loose,
}

class RenderFlex extends RenderBox with ContainerRenderObjectMixin<RenderBox, FlexParentData> {
  RenderFlex({
    required this.direction,
    this.mainAxisAlignment = .start,
    this.crossAxisAlignment = .center,
    this.mainAxisSize = .max,
    this.clipBehavior = .none
  });

  Axis direction;
  MainAxisAlignment mainAxisAlignment;
  CrossAxisAlignment crossAxisAlignment;
  MainAxisSize mainAxisSize;
  Clip clipBehavior;

  double _getMainAxisExtent(Size size) =>
      direction == Axis.horizontal ? size.width : size.height;

  double _getCrossAxisExtent(Size size) =>
      direction == Axis.horizontal ? size.height : size.width;

  double _getMainAxisConstraintMax(BoxConstraints c) =>
      direction == Axis.horizontal ? c.maxWidth : c.maxHeight;

  double _getCrossAxisConstraintMax(BoxConstraints c) =>
      direction == Axis.horizontal ? c.maxHeight : c.maxWidth;

  @override
  void performLayout() {
    final parentConstraints = constraints;
    final maxMainAxis = _getMainAxisConstraintMax(parentConstraints);
    final maxCrossAxis = _getCrossAxisConstraintMax(parentConstraints);

    // Phase 1: Lay out non-flex children and compute total flex.
    double allocatedMainAxis = 0;
    double maxChildCrossAxis = 0;
    int totalFlex = 0;
    final List<double> childMainAxisExtents = List.filled(childCount, 0);

    int i = 0;
    visitChildren((child) {
      final parentData = child.parentData as FlexParentData;
      final flex = parentData.flex;

      if (flex > 0) {
        totalFlex += flex;
      } else {
        // Non-flex child: lay out with loose cross-axis constraints.
        final childConstraints = _makeChildConstraints(
          mainAxisMax: maxMainAxis,
          crossAxisMin:
              crossAxisAlignment == CrossAxisAlignment.stretch
                  ? maxCrossAxis
                  : 0,
          crossAxisMax: maxCrossAxis,
        );
        child.layout(childConstraints, parentUsesSize: true);
        final childMainExtent = _getMainAxisExtent(child.size);
        allocatedMainAxis += childMainExtent;
        childMainAxisExtents[i] = childMainExtent;
        maxChildCrossAxis =
            math.max(maxChildCrossAxis, _getCrossAxisExtent(child.size));
      }
      i++;
    });

    // Phase 2: Distribute remaining space to flex children.
    final double freeSpace = math.max(0, maxMainAxis - allocatedMainAxis);
    final double spacePerFlex = totalFlex > 0 ? freeSpace / totalFlex : 0;

    /*int*/ i = 0;
    visitChildren((child){
      final parentData = child.parentData as FlexParentData;
      final flex = parentData.flex;

      if (flex > 0) {
        final double childMainExtent = spacePerFlex * flex;
        final childConstraints = _makeChildConstraints(
          mainAxisMin:
              parentData.fit == FlexFit.tight ? childMainExtent : 0,
          mainAxisMax: childMainExtent,
          crossAxisMin:
              crossAxisAlignment == CrossAxisAlignment.stretch
                  ? maxCrossAxis
                  : 0,
          crossAxisMax: maxCrossAxis,
        );
        child.layout(childConstraints, parentUsesSize: true);
        childMainAxisExtents[i] = _getMainAxisExtent(child.size);
        allocatedMainAxis += childMainAxisExtents[i];
        maxChildCrossAxis =
            math.max(maxChildCrossAxis, _getCrossAxisExtent(child.size));
      }
      i++;
    });

    // Determine own size.
    final double idealMainAxis =
        mainAxisSize == MainAxisSize.max ? maxMainAxis : allocatedMainAxis;
    final double actualMainAxis =
        direction == Axis.horizontal
            ? parentConstraints.constrainWidth(idealMainAxis)
            : parentConstraints.constrainHeight(idealMainAxis);
    final double actualCrossAxis =
        crossAxisAlignment == CrossAxisAlignment.stretch
            ? maxCrossAxis
            : direction == Axis.horizontal
                ? parentConstraints.constrainHeight(maxChildCrossAxis)
                : parentConstraints.constrainWidth(maxChildCrossAxis);

    size =
        direction == Axis.horizontal
            ? Size(actualMainAxis, actualCrossAxis)
            : Size(actualCrossAxis, actualMainAxis);

    // Phase 3: Position children (compute offsets for paint).
    _childOffsets.clear();
    final double remainingSpace = actualMainAxis - allocatedMainAxis;

    double leadingSpace;
    double betweenSpace;
    switch (mainAxisAlignment) {
      case MainAxisAlignment.start:
        leadingSpace = 0;
        betweenSpace = 0;
      case MainAxisAlignment.end:
        leadingSpace = remainingSpace;
        betweenSpace = 0;
      case MainAxisAlignment.center:
        leadingSpace = remainingSpace / 2;
        betweenSpace = 0;
      case MainAxisAlignment.spaceBetween:
        leadingSpace = 0;
        betweenSpace =
            childCount > 1 ? remainingSpace / (childCount - 1) : 0;
      case MainAxisAlignment.spaceAround:
        betweenSpace = childCount > 0 ? remainingSpace / childCount : 0;
        leadingSpace = betweenSpace / 2;
      case MainAxisAlignment.spaceEvenly:
        betweenSpace =
            childCount > 0 ? remainingSpace / (childCount + 1) : 0;
        leadingSpace = betweenSpace;
    }

    double mainAxisOffset = leadingSpace;
    /*int*/ i = 0;
    visitChildren((child) {
      final childCrossExtent = _getCrossAxisExtent(child.size);

      double crossAxisOffset;
      switch (crossAxisAlignment) {
        case CrossAxisAlignment.start:
          crossAxisOffset = 0;
        case CrossAxisAlignment.end:
          crossAxisOffset = actualCrossAxis - childCrossExtent;
        case CrossAxisAlignment.center:
        case CrossAxisAlignment.stretch:
          crossAxisOffset = (actualCrossAxis - childCrossExtent) / 2;
      }

      _childOffsets[child] =
          direction == Axis.horizontal
              ? Offset(mainAxisOffset, crossAxisOffset)
              : Offset(crossAxisOffset, mainAxisOffset);

      mainAxisOffset += childMainAxisExtents[i] + betweenSpace;
      i++;
    });
  }

  /// Stored child offsets for painting.
  final Map<RenderObject, Offset> _childOffsets = {};

  BoxConstraints _makeChildConstraints({
    double mainAxisMin = 0,
    double mainAxisMax = double.infinity,
    double crossAxisMin = 0,
    double crossAxisMax = double.infinity,
  }) {
    return direction == Axis.horizontal
        ? BoxConstraints(
            minWidth: mainAxisMin,
            maxWidth: mainAxisMax,
            minHeight: crossAxisMin,
            maxHeight: crossAxisMax,
          )
        : BoxConstraints(
            minWidth: crossAxisMin,
            maxWidth: crossAxisMax,
            minHeight: mainAxisMin,
            maxHeight: mainAxisMax,
          );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (clipBehavior != .none && childCount != 0) {
      context.canvas.save();
      context.canvas.clipRect(offset & size, clipBehavior == .antiAlias);
    }
    visitChildren((child) {
      final childOffset = _childOffsets[child] ?? Offset.zero;
      context.paintChild(child, Offset(
        offset.dx + childOffset.dx,
        offset.dy + childOffset.dy,
      ));
    });
    if (clipBehavior != .none && childCount != 0) {
      context.canvas.restore();
    }
  }

  @override
  void setupParentData(covariant RenderObject child) {
    if (child is RenderExpanded) {
      child.parentData = FlexParentData(
        flex: child.flex,
        fit: child.fit,
      );
    } else {
      child.parentData = FlexParentData();
    }
  }
}

/// A pass-through render object that communicates flex data to its parent
/// [RenderFlex] via parent data.
class RenderExpanded extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  RenderExpanded({this.flex = 1, this.fit = FlexFit.tight});
  final int flex;
  final FlexFit fit;

  @override
  void performLayout() {
    // Register our flex data with the parent RenderFlex.
    if (parent is RenderFlex) {
      (parent! as RenderFlex).setupParentData(
        this
      );
    }

    final child = this.child;
    // Lay out our single child with the same constraints we received.
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
      size = child.size;
    } else {
      size = Size(constraints.minWidth, constraints.minHeight);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) {
      context.paintChild(child, offset);
    }
  }
}
