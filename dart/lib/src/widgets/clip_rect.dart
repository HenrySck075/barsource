import 'package:barsource/src/painting/basic_types.dart';
import 'package:barsource/src/rendering/box.dart';
import 'package:barsource/src/rendering/layer.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/widgets/framework.dart';

class ClipRect extends SingleChildRenderObjectWidget {
  const ClipRect({
    super.key,
    this.clipBehavior = .hardEdge,
    super.child,
  });

  final Clip clipBehavior;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderClipRect(clipBehavior);
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    if (renderObject is _RenderClipRect) {
      renderObject.clipBehavior = clipBehavior;
    }
  }
}

class _RenderClipRect extends RenderProxyBox {
  Clip _clipBehavior;

  _RenderClipRect(this._clipBehavior);

  set clipBehavior(Clip value) {
    if (_clipBehavior != value) {
      _clipBehavior = value;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    layer = context.pushClipRect(offset, offset & size, (c, o){
      if (child != null) context.paintChild(child!, offset);
    }, oldLayer: layer as ClipRectLayer?);
  }
}

