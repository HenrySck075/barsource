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
  spaceEvenly,
}

enum CrossAxisAlignment { start, end, center, stretch, baseline }

class FlexParentData extends ContainerBoxParentData<RenderBox> {
  int flex = 0;
  FlexFit fit = FlexFit.tight;
}

class RenderExpanded extends RenderProxyBox {
  RenderExpanded({this._flex = 1, this._fit = FlexFit.loose});

  int get flex => _flex;
  int _flex;
  set flex(int value) {
    assert(value >= 0);
    if (_flex == value) return;
    _flex = value;
    markNeedsLayout();
    parent?.markNeedsLayout();
  }

  FlexFit get fit => _fit;
  FlexFit _fit;
  set fit(FlexFit value) {
    if (_fit == value) return;
    _fit = value;
    markNeedsLayout();
    parent?.markNeedsLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }
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

  
  int _getFlex(RenderBox child) {
    if (child is RenderExpanded) {
      return child.flex;
    }
    return 0;
  }

  FlexFit _getFit(RenderBox child) {
    if (child is RenderExpanded) {
      return child.fit;
    }
    return FlexFit.tight;
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

  (double leadingSpace, double betweenSpace) _distributeSpace(
    double remainingSpace,
    int itemCount,
  ) {
    if (itemCount <= 0) {
      return (0.0, 0.0);
    }
    return switch (mainAxisAlignment) {
      MainAxisAlignment.start => (0.0, 0.0),
      MainAxisAlignment.end => (remainingSpace, 0.0),
      MainAxisAlignment.center => (remainingSpace / 2.0, 0.0),
      MainAxisAlignment.spaceBetween when itemCount < 2 => (0.0, 0.0),
      MainAxisAlignment.spaceBetween => (0.0, remainingSpace / (itemCount - 1)),
      MainAxisAlignment.spaceAround => (
        remainingSpace / itemCount / 2.0,
        remainingSpace / itemCount,
      ),
      MainAxisAlignment.spaceEvenly => (
        remainingSpace / (itemCount + 1),
        remainingSpace / (itemCount + 1),
      ),
    };
  }

  @override
  void performLayout() {
    final parentConstraints = constraints;
    final nonFlexConstraints = _constraintsForNonFlexChild(parentConstraints);

    final maxMain = switch (direction) {
      Axis.horizontal => parentConstraints.maxWidth,
      Axis.vertical => parentConstraints.maxHeight,
    };
    final canFlex = maxMain.isFinite;

    var totalFlex = 0;
    var allocatedMain = 0.0;
    var maxCross = 0.0;

    for (
      RenderBox? child = firstChild;
      child != null;
      child = childAfter(child)
    ) {
      final childFlex = canFlex ? _getFlex(child) : 0;
      if (childFlex > 0) {
        totalFlex += childFlex;
        continue;
      }
      child.layout(nonFlexConstraints, parentUsesSize: true);
      allocatedMain += _getMainExtent(child.size);
      maxCross = math.max(maxCross, _getCrossExtent(child.size));
    }

    if (canFlex && totalFlex > 0) {
      var remainingFlex = totalFlex;
      var remainingSpace = math.max(0.0, maxMain - allocatedMain);
      for (
        RenderBox? child = firstChild;
        child != null;
        child = childAfter(child)
      ) {
        final childFlex = _getFlex(child);
        if (childFlex <= 0) continue;

        final maxChildMain = remainingSpace * childFlex / remainingFlex;
        remainingFlex -= childFlex;
        remainingSpace -= maxChildMain;

        final childConstraints = _constraintsForFlexChild(
          parentConstraints,
          maxChildMain,
          _getFit(child),
        );
        child.layout(childConstraints, parentUsesSize: true);

        allocatedMain += _getMainExtent(child.size);
        maxCross = math.max(maxCross, _getCrossExtent(child.size));
      }
    }

    final idealMain = switch (mainAxisSize) {
      MainAxisSize.max when maxMain.isFinite => maxMain,
      MainAxisSize.max || MainAxisSize.min => allocatedMain,
    };

    final idealSize = switch (direction) {
      Axis.horizontal => Size(idealMain, maxCross),
      Axis.vertical => Size(maxCross, idealMain),
    };
    size = parentConstraints.constrain(idealSize);

    final actualMain = _getMainExtent(size);
    final actualCross = _getCrossExtent(size);
    _overflow = math.max(0.0, allocatedMain - actualMain);

    final freeSpace = math.max(0.0, actualMain - allocatedMain);
    final (leadingSpace, betweenSpace) = _distributeSpace(
      freeSpace,
      childCount,
    );

    var childMainPosition = leadingSpace;
    for (
      RenderBox? child = firstChild;
      child != null;
      child = childAfter(child)
    ) {
      final childCross = _getCrossExtent(child.size);
      final crossFreeSpace = actualCross - childCross;
      final childCrossPosition = switch (crossAxisAlignment) {
        CrossAxisAlignment.start ||
        CrossAxisAlignment.stretch ||
        CrossAxisAlignment.baseline => 0.0,
        CrossAxisAlignment.center => crossFreeSpace / 2.0,
        CrossAxisAlignment.end => crossFreeSpace,
      };

      final childParentData = child.parentData! as FlexParentData;
      childParentData.offset = switch (direction) {
        Axis.horizontal => Offset(childMainPosition, childCrossPosition),
        Axis.vertical => Offset(childCrossPosition, childMainPosition),
      };
      childMainPosition += _getMainExtent(child.size) + betweenSpace;
    }
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
