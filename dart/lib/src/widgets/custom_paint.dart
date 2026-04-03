import 'package:barsource/dart_ui.dart';
import 'package:barsource/src/rendering/box.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/widgets/framework.dart';

abstract class CustomPainter {
  void paint(Canvas canvas, Size size);
}


class CustomPaint extends SingleChildRenderObjectWidget {
  const CustomPaint({
    super.key,
    required this.painter,
    super.child,
    this.foregroundPainter
  });

  final CustomPainter painter;
  final CustomPainter? foregroundPainter;

  @override
  RenderCustomPaint createRenderObject(BuildContext context) {
    return RenderCustomPaint(painter, foregroundPainter);
  }

  @override
  void updateRenderObject(BuildContext context, RenderCustomPaint renderObject) {
    renderObject.painter = painter;
    renderObject.foregroundPainter = foregroundPainter;
  }
}

class RenderCustomPaint extends RenderProxyBox {
  RenderCustomPaint(this._painter, this._foregroundPainter);

  CustomPainter _painter;
  CustomPainter? _foregroundPainter;

  set painter(CustomPainter value) {
    if (value == _painter) return;
    _painter = value;
    //markNeedsPaint();
  }

  set foregroundPainter(CustomPainter? value) {
    if (value == _foregroundPainter) return;
    _foregroundPainter = value;
    //markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _painter.paint(context.canvas, size);
    if (child!=null) context.paintChild(child!, offset);
    _foregroundPainter?.paint(context.canvas, size);
  }
}
