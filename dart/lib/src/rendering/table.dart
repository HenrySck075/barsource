import 'package:barsource/dart_ui.dart';
import 'package:barsource/src/foundation/object.dart';
import 'package:barsource/src/rendering/box.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:meta/meta.dart';
import 'dart:math' as math;

/// Parent data used by [RenderTable] for its children.
class TableCellParentData extends ContainerBoxParentData<RenderBox> {
  /// Where this cell should be placed vertically.
  ///
  /// When using [TableCellVerticalAlignment.baseline], the text baseline must be set as well.
  //TableCellVerticalAlignment? verticalAlignment;

  /// The column that the child was in the last time it was laid out.
  int? x;

  /// The row that the child was in the last time it was laid out.
  int? y;

  /// The column span that the child has the last time it was laid out.
  int? colSpan;
  /// The row span that the child has the last time it was laid out.
  int? rowSpan;

/*
  @override
  String toString() =>
      '${super.toString()}; ${verticalAlignment == null ? "default vertical alignment" : "$verticalAlignment"}';
*/
}


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

/// Sizes the column according to the intrinsic dimensions of all the
/// cells in that column.
///
/// This is a very expensive way to size a column.
///
/// A flex value can be provided. If specified (and non-null), the
/// column will participate in the distribution of remaining space
/// once all the non-flexible columns have been sized.
class IntrinsicColumnWidth extends TableColumnWidth {
  /// Creates a column width based on intrinsic sizing.
  ///
  /// This sizing algorithm is very expensive.
  ///
  /// The `flex` argument specifies the flex factor to apply to the column if
  /// there is any room left over when laying out the table. If `flex` is
  /// null (the default), the table will not distribute any extra space to the
  /// column.
  const IntrinsicColumnWidth({this._flex});

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    var result = 0.0;
    for (final cell in cells) {
      result = math.max(result, cell.getMinIntrinsicWidth(double.infinity));
    }
    return result;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    var result = 0.0;
    for (final cell in cells) {
      result = math.max(result, cell.getMaxIntrinsicWidth(double.infinity));
    }
    return result;
  }

  final double? _flex;

  @override
  double? flex(Iterable<RenderBox> cells) => _flex;

  @override
  String toString() =>
      '${objectRuntimeType(this, 'IntrinsicColumnWidth')}(flex: ${_flex?.toStringAsFixed(1)})';
}

/// Sizes the column to a specific number of pixels.
///
/// This is the cheapest way to size a column.
class FixedColumnWidth extends TableColumnWidth {
  /// Creates a column width based on a fixed number of logical pixels.
  const FixedColumnWidth(this.value);

  /// The width the column should occupy in logical pixels.
  final double value;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return value;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return value;
  }

  @override
  String toString() =>
      '${objectRuntimeType(this, 'FixedColumnWidth')}($value)';
}

/// Sizes the column to a fraction of the table's constraints' maxWidth.
///
/// This is a cheap way to size a column.
class FractionColumnWidth extends TableColumnWidth {
  /// Creates a column width based on a fraction of the table's constraints'
  /// maxWidth.
  const FractionColumnWidth(this.value);

  /// The fraction of the table's constraints' maxWidth that this column should
  /// occupy.
  final double value;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    if (!containerWidth.isFinite) {
      return 0.0;
    }
    return value * containerWidth;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    if (!containerWidth.isFinite) {
      return 0.0;
    }
    return value * containerWidth;
  }

  @override
  String toString() => '${objectRuntimeType(this, 'FractionColumnWidth')}($value)';
}

/// Sizes the column by taking a part of the remaining space once all
/// the other columns have been laid out.
///
/// For example, if two columns have a [FlexColumnWidth], then half the
/// space will go to one and half the space will go to the other.
///
/// This is a cheap way to size a column.
class FlexColumnWidth extends TableColumnWidth {
  /// Creates a column width based on a fraction of the remaining space once all
  /// the other columns have been laid out.
  const FlexColumnWidth([this.value = 1.0]);

  /// The fraction of the remaining space once all the other columns have
  /// been laid out that this column should occupy.
  final double value;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return 0.0;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return 0.0;
  }

  @override
  double flex(Iterable<RenderBox> cells) {
    return value;
  }

  @override
  String toString() => '${objectRuntimeType(this, 'FlexColumnWidth')}(value)';
}

/// Sizes the column such that it is the size that is the maximum of
/// two column width specifications.
///
/// For example, to have a column be 10% of the container width or
/// 100px, whichever is bigger, you could use:
///
///     const MaxColumnWidth(const FixedColumnWidth(100.0), FractionColumnWidth(0.1))
///
/// Both specifications are evaluated, so if either specification is
/// expensive, so is this.
class MaxColumnWidth extends TableColumnWidth {
  /// Creates a column width that is the maximum of two other column widths.
  const MaxColumnWidth(this.a, this.b);

  /// A lower bound for the width of this column.
  final TableColumnWidth a;

  /// Another lower bound for the width of this column.
  final TableColumnWidth b;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return math.max(
      a.minIntrinsicWidth(cells, containerWidth),
      b.minIntrinsicWidth(cells, containerWidth),
    );
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return math.max(
      a.maxIntrinsicWidth(cells, containerWidth),
      b.maxIntrinsicWidth(cells, containerWidth),
    );
  }

  @override
  double? flex(Iterable<RenderBox> cells) {
    final double? aFlex = a.flex(cells);
    final double? bFlex = b.flex(cells);
    if (aFlex == null) {
      return bFlex;
    } else if (bFlex == null) {
      return aFlex;
    }
    return math.max(aFlex, bFlex);
  }

  @override
  String toString() => '${objectRuntimeType(this, 'MaxColumnWidth')}($a, $b)';
}

/// Sizes the column such that it is the size that is the minimum of
/// two column width specifications.
///
/// For example, to have a column be 10% of the container width but
/// never bigger than 100px, you could use:
///
///     const MinColumnWidth(const FixedColumnWidth(100.0), FractionColumnWidth(0.1))
///
/// Both specifications are evaluated, so if either specification is
/// expensive, so is this.
class MinColumnWidth extends TableColumnWidth {
  /// Creates a column width that is the minimum of two other column widths.
  const MinColumnWidth(this.a, this.b);

  /// An upper bound for the width of this column.
  final TableColumnWidth a;

  /// Another upper bound for the width of this column.
  final TableColumnWidth b;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return math.min(
      a.minIntrinsicWidth(cells, containerWidth),
      b.minIntrinsicWidth(cells, containerWidth),
    );
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return math.min(
      a.maxIntrinsicWidth(cells, containerWidth),
      b.maxIntrinsicWidth(cells, containerWidth),
    );
  }

  @override
  double? flex(Iterable<RenderBox> cells) {
    final double? aFlex = a.flex(cells);
    final double? bFlex = b.flex(cells);
    if (aFlex == null) {
      return bFlex;
    } else if (bFlex == null) {
      return aFlex;
    }
    return math.min(aFlex, bFlex);
  }

  @override
  String toString() => '${objectRuntimeType(this, 'MinColumnWidth')}($a, $b)';
}




// grid validation happens in [Table] so we don't have to do anything here. preferably so.
class RenderTable extends RenderBox with ContainerRenderObjectMixin<RenderBox, TableCellParentData>, RenderBoxContainerDefaultsMixin<RenderBox, TableCellParentData> {
  RenderTable({
    this._columnWidths,
    this._defaultColumnWidth = const FlexColumnWidth(),
  });

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! TableCellParentData) {
      child.parentData = TableCellParentData();
    }
  }

  Map<int, TableColumnWidth>? _columnWidths;
  TableColumnWidth _defaultColumnWidth;

  Map<int, TableColumnWidth>? get columnWidths => _columnWidths;
  set columnWidths(Map<int, TableColumnWidth>? value) {
    if (_columnWidths == value) return;
    _columnWidths = value;
    markNeedsLayout();
  }

  TableColumnWidth get defaultColumnWidth => _defaultColumnWidth;
  set defaultColumnWidth(TableColumnWidth value) {
    if (_defaultColumnWidth == value) return;
    _defaultColumnWidth = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    if (firstChild == null) {
      size = constraints.smallest;
      return;
    }

    int maxRow = 0;
    int maxCol = 0;

    final List<RenderBox> singleCells = [];
    final List<RenderBox> spannedCells = [];
    final Map<int, List<RenderBox>> columnSingleCells = {};

    // PASS 1: Calculate Grid Dimensions & Categorize Cells
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData as TableCellParentData;
      
      // Determine absolute boundaries of the table grid
      maxRow = math.max(maxRow, parentData.y! + parentData.rowSpan! - 1);
      maxCol = math.max(maxCol, parentData.x! + parentData.colSpan! - 1);

      if (parentData.rowSpan! == 1 && parentData.colSpan! == 1) {
        singleCells.add(child);
        columnSingleCells.putIfAbsent(parentData.x!, () => []).add(child);
      } else {
        spannedCells.add(child);
      }
      
      child = parentData.nextSibling;
    }

    final int rowCount = maxRow + 1;
    final int colCount = maxCol + 1;

    final List<double> widths = List.filled(colCount, 0.0);
    final List<double> heights = List.filled(rowCount, 0.0);

    // PASS 2: Calculate Fixed and Intrinsic Column Widths
    double remainingWidth = constraints.maxWidth;
    if (remainingWidth.isInfinite) remainingWidth = 0.0;
    double totalFlex = 0.0;

    for (int c = 0; c < colCount; c++) {
      final TableColumnWidth delegate = columnWidths?[c] ?? defaultColumnWidth;
      final Iterable<RenderBox> cellsInColumn = columnSingleCells[c] ?? const [];
      
      if (delegate is FlexColumnWidth) {
        totalFlex += delegate.value;
      } else {
        final double w = delegate.maxIntrinsicWidth(cellsInColumn, constraints.maxWidth);
        widths[c] = w;
        remainingWidth -= w;
      }
    }

    // PASS 3: Distribute Remaining Width to Flex Columns
    remainingWidth = math.max(0.0, remainingWidth);
    for (int c = 0; c < colCount; c++) {
      final TableColumnWidth delegate = columnWidths?[c] ?? defaultColumnWidth;
      if (delegate is FlexColumnWidth) {
        widths[c] = (delegate.value / totalFlex) * remainingWidth;
      }
    }

    // PASS 4: Layout 1x1 Cells & Establish Base Row Heights
    // Spanned cells are completely ignored when dictating row heights.
    for (final singleCell in singleCells) {
      final parentData = singleCell.parentData as TableCellParentData;
      final int r = parentData.y!;
      final int c = parentData.x!;

      singleCell.layout(
        BoxConstraints.tightFor(width: widths[c]), 
        parentUsesSize: true,
      );
      heights[r] = math.max(heights[r], singleCell.size.height);
    }

    // PASS 5: Layout Spanned Cells
    for (final spannedCell in spannedCells) {
      final parentData = spannedCell.parentData as TableCellParentData;
      
      double spanWidth = 0.0;
      for (int i = 0; i < parentData.colSpan!; i++) {
        final int colIndex = parentData.x! + i;
        if (colIndex < colCount) spanWidth += widths[colIndex];
      }
      
      double spanHeight = 0.0;
      for (int i = 0; i < parentData.rowSpan!; i++) {
        final int rowIndex = parentData.y! + i;
        if (rowIndex < rowCount) spanHeight += heights[rowIndex];
      }
      
      spannedCell.layout(
        BoxConstraints.tightFor(width: spanWidth, height: spanHeight), 
        parentUsesSize: true,
      );
    }

    // PASS 6: Calculate Offsets & Set Total Table Size
    final List<double> xOffsets = List.filled(colCount, 0.0);
    final List<double> yOffsets = List.filled(rowCount, 0.0);

    double currentX = 0.0;
    for (int c = 0; c < colCount; c++) {
      xOffsets[c] = currentX;
      currentX += widths[c];
    }

    double currentY = 0.0;
    for (int r = 0; r < rowCount; r++) {
      yOffsets[r] = currentY;
      currentY += heights[r];
    }

    child = firstChild;
    while (child != null) {
      final parentData = child.parentData as TableCellParentData;
      parentData.offset = Offset(xOffsets[parentData.x!], yOffsets[parentData.y!]);
      child = parentData.nextSibling;
    }

    size = constraints.constrain(Size(currentX, currentY));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}
