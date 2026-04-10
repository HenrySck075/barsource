import 'package:barsource/src/painting/basic_types.dart';
import 'package:barsource/src/painting/border_radius.dart';
import 'package:barsource/src/rendering/box.dart';
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
    if (_clipBehavior != .none) {
      context.canvas.save();
      context.canvas.clipRect(offset & size, _clipBehavior == .antiAlias);
    }
    if (child != null) {
      context.paintChild(child!, offset);
    }

    if (_clipBehavior != .none) {
      context.canvas.restore();
    }
  }
}

class ClipRRect extends SingleChildRenderObjectWidget {
  const ClipRRect({
    super.key,
    this.borderRadius = BorderRadius.zero,
    this.clipBehavior = .hardEdge,
    super.child,
  });

  final BorderRadius borderRadius;
  final Clip clipBehavior;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderClipRRect(borderRadius, clipBehavior);
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    if (renderObject is _RenderClipRRect) {
      renderObject
        ..borderRadius = borderRadius
        ..clipBehavior = clipBehavior;
    }
  }
}

class _RenderClipRRect extends RenderProxyBox {
  BorderRadius _borderRadius;
  Clip _clipBehavior;

  _RenderClipRRect(this._borderRadius, this._clipBehavior);

  set borderRadius(BorderRadius value) {
    if (_borderRadius != value) {
      _borderRadius = value;
    }
  }

  set clipBehavior(Clip value) {
    if (_clipBehavior != value) {
      _clipBehavior = value;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_clipBehavior != .none) {
      context.canvas.save();
      context.canvas.clipRRect(
        _borderRadius.toRRect(offset & size),
        _clipBehavior == .antiAlias,
      );
    }
    context.paintChild(child!, offset);
    if (_clipBehavior != .none) {
      context.canvas.restore();
    }
  }
} 
