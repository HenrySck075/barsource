import 'package:barsource/tennoji.dart';

class ClipRect extends SingleChildRenderObjectWidget {
  const ClipRect({
    super.key,
    this.clipBehavior = Clip.hardEdge,
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
    if (child != null) {
      if (_clipBehavior == Clip.none) {
        context.paintChild(child!, offset);
      } else {
        context.canvas.save();
        context.canvas.clipRect(offset & size, _clipBehavior == .antiAlias);
        context.paintChild(child!, offset);
        context.canvas.restore();
      }
    }
  }
}

