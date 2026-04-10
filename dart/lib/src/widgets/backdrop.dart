import 'package:barsource/src/dart_ui/dart_ui.dart';
import 'package:barsource/src/rendering/box.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/widgets/framework.dart';

class BackdropFilter extends SingleChildRenderObjectWidget {
  const BackdropFilter({
    super.key,
    required this.filter,
    required super.child,
  });

  final ImageFilter filter;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderBackdropFilter(filter);
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    if (renderObject is _RenderBackdropFilter) {
      renderObject.filter = filter;
    }
  }
}

class _RenderBackdropFilter extends RenderProxyBox {
  _RenderBackdropFilter(this._filter);

  ImageFilter _filter;

  set filter(ImageFilter value) {
    if (value == _filter) return;
    _filter = value;
    //markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayerWithBackdrop(_filter);
    context.paintChild(child!, offset);
    context.canvas.restore();
  }
}
