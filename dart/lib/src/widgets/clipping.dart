import 'package:barsource/src/painting/basic_types.dart';
import 'package:barsource/src/painting/border_radius.dart';
import 'package:barsource/src/rendering/box.dart';
import 'package:barsource/src/rendering/custom_clipper.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/widgets/framework.dart';


abstract class _RenderCustomClip<T> extends RenderProxyBox {
  _RenderCustomClip({
    RenderBox? child,
    this._clipper,
    this._clipBehavior = .antiAlias,
  }) : super(child);

  T get _defaultClip;
  T? _clip;

  CustomClipper<T>? _clipper;
  CustomClipper<T>? get clipper => _clipper;
  set clipper(CustomClipper<T>? newClipper) {
    if (_clipper == newClipper) return;
    
    final oldClipper = _clipper;
    _clipper = newClipper;

    assert(newClipper != null || oldClipper != null);
    if (newClipper == null ||
        oldClipper == null ||
        newClipper.runtimeType != oldClipper.runtimeType ||
        newClipper.shouldReclip(oldClipper)) {
      _markNeedsClip();
    }
  }

  Clip _clipBehavior;
  Clip get clipBehavior => _clipBehavior;
  set clipBehavior(Clip value) {
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _clipper?.addListener(_markNeedsClip);
  }

  @override
  void detach() {
    _clipper?.removeListener(_markNeedsClip);
    super.detach();
  }

  void _markNeedsClip() {
    _clip = null;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    final Size? oldSize = hasSize ? size : null;
    super.performLayout();
    if (oldSize != size) {
      _clip = null;
    }
  }

  void _updateClip() {
    _clip ??= _clipper?.getClip(size) ?? _defaultClip;
  }
}


class ClipRect extends SingleChildRenderObjectWidget {
  const ClipRect({
    super.key,
    this.clipBehavior = .hardEdge,
    this.clipper,
    super.child,
  });

  final Clip clipBehavior;
  final CustomClipper<Rect>? clipper;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderClipRect(
      clipper: clipper, 
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    if (renderObject is _RenderClipRect) {
      renderObject
        ..clipBehavior = clipBehavior
        ..clipper = clipper;
    }
  }
}

class _RenderClipRect extends _RenderCustomClip<Rect> {
  _RenderClipRect({super.clipBehavior, super.clipper});

  @override
  Rect get _defaultClip => Offset.zero & size;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_clipBehavior != .none) {
      context.canvas.save();
      _updateClip();
      context.canvas.clipRect(_clip!, _clipBehavior == .antiAlias);
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
    this.borderRadius = .zero,
    this.clipBehavior = .hardEdge,
    this.clipper,
    super.child,
  });

  final BorderRadius borderRadius;
  final Clip clipBehavior;
  final CustomClipper<RRect>? clipper;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderClipRRect(
      borderRadius: borderRadius, 
      clipBehavior: clipBehavior,
      clipper: clipper,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    if (renderObject is _RenderClipRRect) {
      renderObject
        ..borderRadius = borderRadius
        ..clipBehavior = clipBehavior
        ..clipper = clipper;
    }
  }
}

class _RenderClipRRect extends _RenderCustomClip<RRect> {
  BorderRadius _borderRadius;

  _RenderClipRRect({
    super.child,
    this._borderRadius = .zero, 
    super.clipBehavior,
    super.clipper,
  });

  set borderRadius(BorderRadius value) {
    if (_borderRadius != value) {
      _borderRadius = value;
    }
  }

  @override
  RRect get _defaultClip => _borderRadius/*.resolve(textDirection)*/.toRRect(Offset.zero & size);

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


class ClipPath extends SingleChildRenderObjectWidget {
  const ClipPath({super.key, this.clipper, this.clipBehavior = Clip.antiAlias, super.child});

  final CustomClipper<Path>? clipper;
  final Clip clipBehavior;

  @override
  RenderClipPath createRenderObject(BuildContext context) {
    return RenderClipPath(clipper: clipper, clipBehavior: clipBehavior);
  }

  @override
  void updateRenderObject(BuildContext context, RenderClipPath renderObject) {
    renderObject
      ..clipper = clipper
      ..clipBehavior = clipBehavior;
  }

  @override
  void didUnmountRenderObject(RenderClipPath renderObject) {
    renderObject.clipper = null;
  }
}

class RenderClipPath extends _RenderCustomClip<Path> {
  /// Creates a path clip.
  ///
  /// If [clipper] is null, the clip will be a rectangle that matches the layout
  /// size and location of the child. However, rather than use this default,
  /// consider using a [RenderClipRect], which can achieve the same effect more
  /// efficiently.
  ///
  /// If [clipBehavior] is [Clip.none], no clipping will be applied.
  RenderClipPath({super.child, super.clipper, super.clipBehavior});

  @override
  Path get _defaultClip => Path()..addRect(Offset.zero & size);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      if (clipBehavior != Clip.none) {
        _updateClip();
        context.canvas.clipPath(
          offset,
          Offset.zero & size,
          _clip!,
          super.paint,
          clipBehavior: clipBehavior,
          oldLayer: layer as ClipPathLayer?,
        );
      } else {
        context.paintChild(child!, offset);
      }
    } 
  }
