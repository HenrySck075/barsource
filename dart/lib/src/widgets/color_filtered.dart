import 'package:barsource/src/rendering/box.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/widgets/framework.dart';
import 'package:barsource/dart_ui.dart';

class ColorFiltered extends SingleChildRenderObjectWidget {
  const ColorFiltered({
    super.key,
    required this.colorFilter,
    super.child,
  });

  final ColorFilter colorFilter;

  @override
  RenderColorFiltered createRenderObject(BuildContext context) {
    return RenderColorFiltered(colorFilter: colorFilter);
  }
  
  @override
  void updateRenderObject(BuildContext context, RenderColorFiltered renderObject) {
    renderObject.colorFilter = colorFilter;
  }
}

class RenderColorFiltered extends RenderProxyBox {
  RenderColorFiltered({
    required ColorFilter colorFilter,
  }) : _colorFilter = colorFilter;

  ColorFilter get colorFilter => _colorFilter;
  ColorFilter _colorFilter;
  set colorFilter(ColorFilter value) {
    if (value == _colorFilter) return;
    _colorFilter = value;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.canvas.saveLayer(
        Paint()
        ..colorFilter = _colorFilter 
      );
      context.paintChild(child!, offset);
      context.canvas.restore();
    }
  }
}
