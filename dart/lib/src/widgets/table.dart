import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/rendering/table.dart';
import 'package:barsource/src/widgets/framework.dart';

class TableCell extends ParentDataWidget<TableCellParentData> {
  final int row;
  final int col;
  final int colSpan;
  final int rowSpan;

  const TableCell({
    super.key,
    required this.row,
    required this.col,
    this.colSpan = 1,
    this.rowSpan = 1,
    required super.child,
  }) : assert(row >= 0 && col >= 0 && colSpan > 0 && rowSpan > 0);

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as TableCellParentData;
    if (parentData.colSpan != colSpan || parentData.rowSpan != rowSpan || parentData.x != col || parentData.y != row) {
      parentData.x = col;
      parentData.y = row;
      parentData.colSpan = colSpan;
      parentData.rowSpan = rowSpan;
      // flutter apparently doesnt care
      renderObject.parent?.markNeedsLayout();
    }
  }
}

/// A widget that lays out children as a table.
///
/// Laying out children of this widget is an ungodly EXPENSIVE* operation at the moment so don't do fancy animations on this pls thx.
/// 
/// *i think so
class Table extends MultiChildRenderObjectWidget {
  Table({
    super.key,
    required List<TableCell> super.children,
    this.columnWidths,
    this.defaultColumnWidth = const FlexColumnWidth(),
  }) {_debugValidateGridPlacement();}

  final Map<int, TableColumnWidth>? columnWidths;
  final TableColumnWidth defaultColumnWidth;

  void _debugValidateGridPlacement() {
    assert(() {
      // Start with a truly dynamic 2D list
      final List<List<TableCell?>> occupied = [];

      for (final child in (children as List<TableCell>)) {
        final int rMax = child.row + child.rowSpan;
        final int cMax = child.col + child.colSpan;

        // 1. Expand vertically if needed (add new rows)
        while (occupied.length < rMax) {
          occupied.add([]);
        }

        // 2. Expand horizontally for ALL rows up to rMax
        // (Mismatched row lengths will cause RangeErrors during the overlap check)
        for (int r = 0; r < rMax; r++) {
          while (occupied[r].length < cMax) {
            occupied[r].add(null);
          }
        }

        // 3. Scan and check for overlaps
        for (int r = child.row; r < rMax; r++) {
          for (int c = child.col; c < cMax; c++) {
            final existing = occupied[r][c];
            if (existing != null) {
              throw ArgumentError(
                'Grid collision detected at [$r, $c]!\n'
                'New child at (${child.row}, ${child.col}) with span of (${child.rowSpan}, ${child.colSpan}) conflicts with '
                'existing child at (${existing.row}, ${existing.col}) with span of (${existing.rowSpan}, ${existing.colSpan}).',
              );
            }
            occupied[r][c] = child;
          }
        }
      }
      return true;
    }());
  }

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderTable(
      columnWidths: columnWidths,
      defaultColumnWidth: defaultColumnWidth,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderTable renderObject) {
    renderObject
    ..columnWidths = columnWidths
    ..defaultColumnWidth = defaultColumnWidth
    ;
  }
}
