// Copyright (c) 2026 HenrySck075. All Sogginess Reserved.
// 
// Part of the file contains source code Copyright 2014 The Flutter Authors,
// which is governed by a BSD-style license that can be
// found in the LICENSE.flutter file.

import 'package:barsource/src/elements/framework.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/rendering/table.dart';
import 'package:barsource/src/widgets/framework.dart';
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';

/// A horizontal group of cells in a [Table].
///
/// Every row in a table must have the same number of children, even if there's a spanned child (which covered cells must be annotated with `null`).
///
/// The alignment and spanning of individual cells in a row can be controlled using a
/// [TableCell].
class TableRow {

  /// The widgets that comprise the cells in this row.
  ///
  /// Children may be wrapped in [TableCell] widgets to provide per-cell
  /// configuration to the [Table], but children are not required to be wrapped
  /// in [TableCell] widgets.
  ///
  /// Some elements may require being null due to a TableCell span that covers the slot.
  /// It is an error if a null slot isn't covered, though.
  final List<Widget?> children;

  TableRow({this.children = const <Widget?>[]});
}



/// A widget that uses table layout algorithm on children.
class Table extends RenderObjectWidget {
  final List<TableRow> children;
  final Map<int, TableColumnWidth>? columnWidths;
  final TableColumnWidth defaultColumnWidth;

  Table({super.key, required this.children, required this.columnWidths, required this.defaultColumnWidth});

  @override
  Element createElement() => _TableElement(this); 
}

class _TableElement extends RenderObjectElement {
  _TableElement(Table super.widget);

  List<Element> children;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);

    final Map<(int, int), Widget?> layoutMap = Map.fromEntries(
      (widget as Table).children.mapIndexed(
        (row, rc)=>rc.children.mapIndexed(
          (col, w)=>MapEntry((row,col), w)
        )
      ).flattened
    );
  }

  @override
  void insertRenderObjectChild(covariant RenderObject child, covariant Object? slot) {
    // TODO: implement insertRenderObjectChild
  }

  @override
  void moveRenderObjectChild(covariant RenderObject child, covariant Object? oldSlot, covariant Object? newSlot) {
    // TODO: implement moveRenderObjectChild
  }

  @override
  void removeRenderObjectChild(covariant RenderObject child, covariant Object? slot) {
    // TODO: implement removeRenderObjectChild
  }

}
