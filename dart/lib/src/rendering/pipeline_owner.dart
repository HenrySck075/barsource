import '../painting/canvas.dart';
import 'object.dart';

class PipelineOwner {
  final List<RenderObject> _nodesNeedingLayout = [];
  final List<RenderObject> _nodesNeedingPaint = [];

  void requestLayout(RenderObject node) {
    _nodesNeedingLayout.add(node);
  }

  void requestPaint(RenderObject node) {
    _nodesNeedingPaint.add(node);
  }

  void flushLayout() {
    while (_nodesNeedingLayout.isNotEmpty) {
      final node = _nodesNeedingLayout.removeAt(0);
      if (node.needsLayout) {
        node.layout(const BoxConstraints());
      }
    }
  }

  void flushPaint(Canvas canvas) {
    //final context = PaintingContext(canvas);
    /*
    while (_nodesNeedingPaint.isNotEmpty) {
      final node = _nodesNeedingPaint.removeAt(0);
      if (node.needsPaint) {
        node.paint(context, Offset.zero);
      }
    }
    */
  }
}
