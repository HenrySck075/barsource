// Copyright (c) 2026 HenrySck075. All Sogginess Reserved.
// 
// Part of the file contains source code Copyright 2014 The Flutter Authors,
// which is governed by a BSD-style license that can be
// found in the LICENSE.flutter file.

import 'dart:math' as math;

import 'package:barsource/src/painting/basic_types.dart';

import 'box.dart';
import 'object.dart';

enum FlexFit { tight, loose }

enum MainAxisSize { min, max }

enum MainAxisAlignment {
  start,
  end,
  center,
  spaceBetween,
  spaceAround,
  spaceEvenly;


  (double leadingSpace, double betweenSpace) _distributeSpace(
    double freeSpace,
    int itemCount,
    bool flipped,
    double spacing,
  ) {
    assert(itemCount >= 0);
    return switch (this) {
      MainAxisAlignment.start => flipped ? (freeSpace, spacing) : (0.0, spacing),

      MainAxisAlignment.end => MainAxisAlignment.start._distributeSpace(
        freeSpace,
        itemCount,
        !flipped,
        spacing,
      ),
      MainAxisAlignment.spaceBetween when itemCount < 2 => MainAxisAlignment.start._distributeSpace(
        freeSpace,
        itemCount,
        flipped,
        spacing,
      ),
      MainAxisAlignment.spaceAround when itemCount == 0 => MainAxisAlignment.start._distributeSpace(
        freeSpace,
        itemCount,
        flipped,
        spacing,
      ),

      MainAxisAlignment.center => (freeSpace / 2.0, spacing),
      MainAxisAlignment.spaceBetween => (0.0, freeSpace / (itemCount - 1) + spacing),
      MainAxisAlignment.spaceAround => (freeSpace / itemCount / 2, freeSpace / itemCount + spacing),
      MainAxisAlignment.spaceEvenly => (
        freeSpace / (itemCount + 1),
        freeSpace / (itemCount + 1) + spacing,
      ),
    };
  }
}

enum CrossAxisAlignment { start, end, center, stretch, baseline }

class FlexParentData extends ContainerBoxParentData<RenderBox> {
  int flex = 0;
  FlexFit fit = FlexFit.tight;
}


class RenderFlex extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, FlexParentData> {
  RenderFlex({
    List<RenderBox>? children,
    this._direction = Axis.horizontal,
    this._mainAxisAlignment = .start,
    this._crossAxisAlignment = .center,
    this._mainAxisSize = .max,
    this._clipBehavior = Clip.none,
    this._spacing = 0.0,
  }) {
    addAll(children);
  }

  double get spacing => _spacing;
  double _spacing = 0.0;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  Axis get direction => _direction;
  Axis _direction;
  set direction(Axis value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsLayout();
  }

  MainAxisAlignment get mainAxisAlignment => _mainAxisAlignment;
  MainAxisAlignment _mainAxisAlignment;
  set mainAxisAlignment(MainAxisAlignment value) {
    if (_mainAxisAlignment == value) return;
    _mainAxisAlignment = value;
    markNeedsLayout();
  }

  CrossAxisAlignment get crossAxisAlignment => _crossAxisAlignment;
  CrossAxisAlignment _crossAxisAlignment;
  set crossAxisAlignment(CrossAxisAlignment value) {
    if (_crossAxisAlignment == value) return;
    _crossAxisAlignment = value;
    markNeedsLayout();
  }

  MainAxisSize get mainAxisSize => _mainAxisSize;
  MainAxisSize _mainAxisSize;
  set mainAxisSize(MainAxisSize value) {
    if (_mainAxisSize == value) return;
    _mainAxisSize = value;
    markNeedsLayout();
  }

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior;
  set clipBehavior(Clip value) {
    if (_clipBehavior == value) return;
    _clipBehavior = value;
    markNeedsPaint();
  }

  double _overflow = 0.0;
  bool get _hasOverflow => _overflow > 0.0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! FlexParentData) {
      child.parentData = FlexParentData();
    }
  }
 

  double _getMainExtent(Size size) {
    return switch (direction) {
      Axis.horizontal => size.width,
      Axis.vertical => size.height,
    };
  }

  double _getCrossExtent(Size size) {
    return switch (direction) {
      Axis.horizontal => size.height,
      Axis.vertical => size.width,
    };
  }

  BoxConstraints _constraintsForNonFlexChild(BoxConstraints constraints) {
    final fillCross = crossAxisAlignment == CrossAxisAlignment.stretch;
    return switch (direction) {
      Axis.horizontal => BoxConstraints(
        minHeight: fillCross ? constraints.maxHeight : 0.0,
        maxHeight: constraints.maxHeight,
      ),
      Axis.vertical => BoxConstraints(
        minWidth: fillCross ? constraints.maxWidth : 0.0,
        maxWidth: constraints.maxWidth,
      ),
    };
  }

  BoxConstraints _constraintsForFlexChild(
    BoxConstraints constraints,
    double maxChildExtent,
    FlexFit fit,
  ) {
    final minChildExtent = fit == FlexFit.tight ? maxChildExtent : 0.0;
    final fillCross = crossAxisAlignment == CrossAxisAlignment.stretch;
    return switch (direction) {
      Axis.horizontal => BoxConstraints(
        minWidth: minChildExtent,
        maxWidth: maxChildExtent,
        minHeight: fillCross ? constraints.maxHeight : 0.0,
        maxHeight: constraints.maxHeight,
      ),
      Axis.vertical => BoxConstraints(
        minWidth: fillCross ? constraints.maxWidth : 0.0,
        maxWidth: constraints.maxWidth,
        minHeight: minChildExtent,
        maxHeight: maxChildExtent,
      ),
    };
  }


  ({Size size, double mainAxisFreeSpace}) _computeSizes(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layoutChild
  ) {
    final nonFlexConstraints = _constraintsForNonFlexChild(constraints);

    // type system cheating
    final List<RenderBox> flexChildren = List.filled(0, this, growable: true);
    int totalFlex = 0; // i cant come up with a good name its a sum of every child.parentData.flex factor

    double mainAxisExtent = 0;
    double crossAxisExtent = 0;
    
    // im following the docs here
    // https://api.flutter.dev/flutter/rendering/RenderFlex-class.html

    // Step 1: Layout on non-flex children
    for (RenderBox? child = firstChild; child != null; child = childAfter(child)) {
      final childParentData = child.parentData! as FlexParentData;
      if (childParentData.flex == 0) {
        final childSize = layoutChild(child, nonFlexConstraints);
        mainAxisExtent += _getMainExtent(childSize) + spacing;
        crossAxisExtent = math.max(crossAxisExtent, _getCrossExtent(childSize));
      } else {
        flexChildren.add(child);
        totalFlex += childParentData.flex;
      }
    }

    // Step 2: Split the remaining spaces (includes spacing)
    final remainingSpace = math.max(0.0, _getMainExtent(constraints.biggest) - mainAxisExtent - spacing * (flexChildren.length - 1));
    final spacesPerFlex = totalFlex > 0 ? remainingSpace / totalFlex : 0.0;

    // Step 3: Layout on flex children
    for (final child in flexChildren) {
      final childParentData = child.parentData! as FlexParentData;
      final childSize = layoutChild(
        child,
        _constraintsForFlexChild(
          constraints,
          spacesPerFlex * childParentData.flex,
          childParentData.fit,
        ),
      );
      mainAxisExtent += _getMainExtent(childSize) + spacing;
      crossAxisExtent = math.max(crossAxisExtent, _getCrossExtent(childSize));
    }

    final maxMainAxis = _getMainExtent(constraints.biggest);
    final idealMainAxis = mainAxisSize == .max ? maxMainAxis : mainAxisExtent;

    return (
      size: direction == .horizontal ? Size(idealMainAxis, crossAxisExtent) : Size(crossAxisExtent, idealMainAxis),
      mainAxisFreeSpace: math.max(0.0, idealMainAxis - mainAxisExtent - spacing * (childCount - 1))
    );
  }

  @override
  void performLayout() {
    final sizes = _computeSizes(
      constraints,
      (child, cc) {child.layout(cc); return child.size;}
    );

    size = sizes.size;

    final double remainingSpace = math.max(0.0, sizes.mainAxisFreeSpace);

    final (double leadingSpace, double betweenSpace) = mainAxisAlignment._distributeSpace(
      remainingSpace,
      childCount,
      false,//flipMainAxis,
      spacing,
    );

    final (RenderBox? Function(RenderBox) nextChild, RenderBox? topLeftChild) = (childAfter, firstChild);

    var childMainPosition = leadingSpace;
    for (var child = topLeftChild; child != null; child = nextChild(child)) {
      final childCrossPosition = crossAxisAlignment._getChildCrossAxisOffset(
        crossAxisExtent - _getCrossExtent(child.size),
        flipCrossAxis,
      );
  }

  void _paintChildren(PaintingContext context, Offset offset) {
    for (
      RenderBox? child = firstChild;
      child != null;
      child = childAfter(child)
    ) {
      final childParentData = child.parentData! as FlexParentData;
      context.paintChild(
        child,
        Offset(
          offset.dx + childParentData.offset.dx,
          offset.dy + childParentData.offset.dy,
        ),
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hasOverflow || clipBehavior == Clip.none) {
      _paintChildren(context, offset);
      return;
    }

    context.canvas.save();
    context.canvas.clipRect(offset & size, clipBehavior == Clip.antiAlias);
    _paintChildren(context, offset);
    context.canvas.restore();
  }
}
