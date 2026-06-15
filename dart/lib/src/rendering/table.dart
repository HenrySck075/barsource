// Copyright (c) 2026 HenrySck075. All Sogginess Reserved.
// 
// Part of the file contains source code Copyright 2014 The Flutter Authors,
// which is governed by a BSD-style license that can be
// found in the LICENSE.flutter file.

import 'package:barsource/src/foundation/object.dart';
import 'package:barsource/src/rendering/box.dart';
import 'package:barsource/src/rendering/parent_data.dart';
import 'package:meta/meta.dart';

/// Base class to describe how wide a column in a [RenderTable] should be.
///
/// To size a column to a specific number of pixels, use a [FixedColumnWidth].
/// This is the cheapest way to size a column.
///
/// Other algorithms that are relatively cheap include [FlexColumnWidth], which
/// distributes the space equally among the flexible columns,
/// [FractionColumnWidth], which sizes a column based on the size of the
/// table's container.
@immutable
abstract class TableColumnWidth {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const TableColumnWidth();

  /// The smallest width that the column can have.
  ///
  /// The `cells` argument is an iterable that provides all the cells
  /// in the table for this column. Walking the cells is by definition
  /// O(N), so algorithms that do that should be considered expensive.
  ///
  /// The `containerWidth` argument is the `maxWidth` of the incoming
  /// constraints for the table, and might be infinite.
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth);

  /// The ideal width that the column should have. This must be equal
  /// to or greater than the [minIntrinsicWidth]. The column might be
  /// bigger than this width, e.g. if the column is flexible or if the
  /// table's width ends up being forced to be bigger than the sum of
  /// all the maxIntrinsicWidth values.
  ///
  /// The `cells` argument is an iterable that provides all the cells
  /// in the table for this column. Walking the cells is by definition
  /// O(N), so algorithms that do that should be considered expensive.
  ///
  /// The `containerWidth` argument is the `maxWidth` of the incoming
  /// constraints for the table, and might be infinite.
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth);

  /// The flex factor to apply to the cell if there is any room left
  /// over when laying out the table. The remaining space is
  /// distributed to any columns with flex in proportion to their flex
  /// value (higher values get more space).
  ///
  /// The `cells` argument is an iterable that provides all the cells
  /// in the table for this column. Walking the cells is by definition
  /// O(N), so algorithms that do that should be considered expensive.
  double? flex(Iterable<RenderBox> cells) => null;

  @override
  String toString() => objectRuntimeType(this, 'TableColumnWidth');
}


/// Parent data used by [RenderTable] for its children.
class TableCellParentData extends BoxParentData {
  /// Where this cell should be placed vertically.
  ///
  /// When using [TableCellVerticalAlignment.baseline], the text baseline must be set as well.
  // TableCellVerticalAlignment? verticalAlignment;

  /// The column that the child was in the last time it was laid out.
  int? x;

  /// The row that the child was in the last time it was laid out.
  int? y;

  int? spanX;
  int? spanY;
}
