import 'dart:collection';

import '../painting/canvas.dart';
import 'object.dart';

class PipelineOwner {
  final List<RenderObject> _nodesNeedingLayout = [];
  final Queue<RenderObject> _nodesNeedingPaint = Queue();

  void requestLayout(RenderObject node) {
    _nodesNeedingLayout.add(node);
  }

  void requestPaint(RenderObject node) {
    _nodesNeedingPaint.addLast(node);
  }

  void flushLayout() {
    while (_nodesNeedingLayout.isNotEmpty) {
      final node = _nodesNeedingLayout.removeAt(0);
      if (node.needsLayout) {
        node.layout(const BoxConstraints());
      }
    }
  }

  void flushPaint() {
    while (_nodesNeedingPaint.isNotEmpty) {
      final node = _nodesNeedingPaint.removeFirst();
      if (node.needsPaint) {
        node.paint(context, Offset.zero);
      }
    }
  }
}
