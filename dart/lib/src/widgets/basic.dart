import 'package:barsource/src/dart_ui/dart_ui.dart';
import 'package:barsource/src/painting/box_decoration.dart';
import 'package:barsource/src/painting/decoration.dart';
import 'package:barsource/src/painting/edge_insets.dart';
import 'package:barsource/src/painting/alignment.dart';
import 'package:vector_math/vector_math.dart' show Matrix4;

import '../rendering/object.dart';
import '../rendering/box.dart';
import '../rendering/align_render.dart' show RenderAlign;
import 'framework.dart';

export 'package:barsource/src/painting/edge_insets.dart';
export 'package:barsource/src/painting/alignment.dart';

class Directionality extends InheritedWidget {
  const Directionality({
    super.key,
    required this.textDirection,
    required super.child,
  });

  final TextDirection textDirection;

  static TextDirection of(BuildContext context) {
    final TextDirection? direction = maybeOf(context);
    assert(direction != null, 'No Directionality widget found.');
    return direction!;
  }

  static TextDirection? maybeOf(BuildContext context) {
    final Directionality? widget = context.dependOnInheritedWidgetOfExactType<Directionality>();
    return widget?.textDirection;
  }

  @override
  bool updateShouldNotify(Directionality oldWidget) => textDirection != oldWidget.textDirection;
}

class Container extends StatelessWidget {
  Container({
    super.key,
    this.alignment,
    this.padding,
    this.color,
    this.isAntiAlias = true,
    this.decoration,
    this.foregroundDecoration,
    this.width,
    this.height,
    this.constraints,
    this.margin,
    this.transform,
    this.child,
  }) : assert(margin == null || margin.isNonNegative),
       assert(padding == null || padding.isNonNegative),
       assert(decoration == null || decoration.debugAssertIsValid()),
       assert(constraints == null || constraints.debugAssertIsValid()),
       assert(color == null || decoration == null,
         'Cannot provide both a color and a decoration\n'
         'To provide both, use "decoration: BoxDecoration(color: color)".'
       );

  final Widget? child;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final bool isAntiAlias;
  final Decoration? decoration;
  final Decoration? foregroundDecoration;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? margin;
  final Matrix4? transform;

  EdgeInsetsGeometry? get _paddingIncludingDecoration {
    return switch ((padding, decoration?.padding)) {
      (null, final EdgeInsetsGeometry? padding) => padding,
      (final EdgeInsetsGeometry? padding, null) => padding,
      (_) => padding!.add(decoration!.padding),
    };
  }

  @override
  Widget build(BuildContext context) {
    Widget? current = child;

    if (child == null && (constraints == null || !constraints!.isTight)) {
      current = LimitedBox(
        maxWidth: 0.0,
        maxHeight: 0.0,
        child: ConstrainedBox(constraints: const BoxConstraints.expand()),
      );
    } else if (alignment != null) {
      current = Align(alignment: alignment!, child: current);
    }

    final EdgeInsetsGeometry? effectivePadding = _paddingIncludingDecoration;
    if (effectivePadding != null) {
      current = Padding(padding: effectivePadding, child: current);
    }

    if (color != null) {
      current = ColoredBox(color: color!, isAntiAlias: isAntiAlias, child: current);
    }

/*
    if (clipBehavior != Clip.none) {
      assert(decoration != null);
      current = ClipPath(
        clipper: _DecorationClipper(
          textDirection: Directionality.maybeOf(context),
          decoration: decoration!,
        ),
        clipBehavior: clipBehavior,
        child: current,
      );
    }
*/
    if (decoration != null) {
      current = DecoratedBox(decoration: decoration!, child: current);
    }

    if (foregroundDecoration != null) {
      current = DecoratedBox(
        decoration: foregroundDecoration!,
        position: DecorationPosition.foreground,
        child: current,
      );
    }

    if (constraints != null) {
      current = ConstrainedBox(constraints: constraints!, child: current);
    }

    if (margin != null) {
      current = Padding(padding: margin!, child: current);
    }

    /*
    if (transform != null) {
      current = Transform(transform: transform!, alignment: transformAlignment, child: current);
    }
    */

    return current!;
  }
}

class ColoredBox extends SingleChildRenderObjectWidget {
  const ColoredBox({
    super.key,
    required this.color,
    this.isAntiAlias = false,
    super.child,
  });

  final Color color;
  final bool isAntiAlias;

  @override
  RenderColoredBox createRenderObject(BuildContext context) => RenderColoredBox(color: color, isAntiAlias: isAntiAlias);

  @override
  void updateRenderObject(BuildContext context, RenderColoredBox renderObject) {
    renderObject
      ..color = color
      ..isAntiAlias = isAntiAlias;
  }
}

class RenderColoredBox extends RenderProxyBox {
  RenderColoredBox({
    required Color color,
    bool isAntiAlias = false,
  }) : _color = color, _isAntiAlias = isAntiAlias;

  Color get color => _color;
  Color _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  bool get isAntiAlias => _isAntiAlias;
  bool _isAntiAlias;
  set isAntiAlias(bool value) {
    if (_isAntiAlias == value) return;
    _isAntiAlias = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = isAntiAlias;
    context.canvas.drawRect(offset & size, paint);
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }
}

// A widget that imposes additional constraints to its child
class ConstrainedBox extends SingleChildRenderObjectWidget {
  const ConstrainedBox({super.key, required this.constraints, super.child});
  final BoxConstraints constraints;

  @override
  RenderConstrainedBox createRenderObject(BuildContext context) => RenderConstrainedBox(constraints: constraints);

  @override
  void updateRenderObject(BuildContext context, RenderConstrainedBox renderObject) {
    renderObject.additionalConstraints = constraints;
  }
}

class RenderConstrainedBox extends RenderProxyBox {
  RenderConstrainedBox({
    required BoxConstraints constraints,
  }) : _constraints = constraints;

  BoxConstraints get additionalConstraints => _constraints;
  BoxConstraints _constraints;
  set additionalConstraints(BoxConstraints value) {
    if (_constraints == value) return;
    _constraints = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    if (child != null) {
      child!.layout(additionalConstraints.enforce(constraints), parentUsesSize: true);
      size = constraints.constrain(child!.size);
    } else {
      size = constraints.constrain(Size.zero);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }
}


class DecoratedBox extends SingleChildRenderObjectWidget {
  const DecoratedBox({
    super.key,
    required this.decoration,
    this.position = DecorationPosition.background,
    super.child,
  });

  final Decoration decoration;
  final DecorationPosition position;

  @override
  RenderDecoratedBox createRenderObject(BuildContext context) {
    return RenderDecoratedBox(
      decoration: decoration,
      position: position,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderDecoratedBox renderObject) {
    renderObject
      ..decoration = decoration
      ..position = position;
  }
}

enum DecorationPosition { background, foreground }

class RenderDecoratedBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  RenderDecoratedBox({
    required Decoration decoration,
    DecorationPosition position = DecorationPosition.background,
    ImageConfiguration configuration = ImageConfiguration.empty,
  }) : _decoration = decoration,
       _position = position,
       _configuration = configuration;

  Decoration _decoration;
  Decoration get decoration => _decoration;
  set decoration(Decoration value) {
    if (_decoration == value) return;
    _painter?.dispose();
    _painter = null;
    _decoration = value;
    //markNeedsPaint();
  }

  DecorationPosition _position;
  DecorationPosition get position => _position;
  set position(DecorationPosition value) {
    if (_position == value) return;
    _position = value;
    //markNeedsPaint();
  }

  ImageConfiguration _configuration;
  ImageConfiguration get configuration => _configuration;
  set configuration(ImageConfiguration value) {
    if (_configuration == value) return;
    _configuration = value;
    //markNeedsPaint();
  }

  BoxPainter? _painter;

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.constrain(Size.zero);
    } else {
      c.layout(constraints, parentUsesSize: true);
      size = c.size;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _painter ??= _decoration.createBoxPainter(/*markNeedsPaint*/(){});
    final ImageConfiguration filledConfiguration = configuration.copyWith(size: size);
    
    if (position == DecorationPosition.background) {
      _painter!.paint(context.canvas, offset, filledConfiguration);
    }
    
    if (child != null) {
      context.paintChild(child!, offset);
    }

    if (position == DecorationPosition.foreground) {
      _painter!.paint(context.canvas, offset, filledConfiguration);
    }
  }
}

class SizedBox extends SingleChildRenderObjectWidget {
  const SizedBox({super.key, this.width, this.height, super.child});
  const SizedBox.shrink({super.key}) : width = 0, height = 0;
  final double? width;
  final double? height;

  @override
  RenderSizedBox createRenderObject(BuildContext context) => RenderSizedBox(
        width: width,
        height: height,
      );

  @override
  void updateRenderObject(BuildContext context, RenderSizedBox renderObject) {
    renderObject
      ..width = width
      ..height = height;
  }
}

class RenderSizedBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  RenderSizedBox({
    double? width,
    double? height,
  }) : _width = width, _height = height;

  double? get width => _width;
  double? _width;
  set width(double? value) {
    if (_width == value) return;
    _width = value;
    markNeedsLayout();
  }

  double? get height => _height;
  double? _height;
  set height(double? value) {
    if (_height == value) return;
    _height = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    BoxConstraints childConstraints = constraints;
    if (width != null) {
      childConstraints = childConstraints.tighten(width: width);
    }
    if (height != null) {
      childConstraints = childConstraints.tighten(height: height);
    }

    if (child != null) {
      child!.layout(childConstraints, parentUsesSize: true);
      size = constraints.constrain(Size(
        width ?? child!.size.width,
        height ?? child!.size.height,
      ));
    } else {
      size = constraints.constrain(Size(
        width ?? 0.0,
        height ?? 0.0,
      ));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }
}

class Padding extends SingleChildRenderObjectWidget {
  const Padding({super.key, required this.padding, super.child});
  final EdgeInsetsGeometry padding;

  @override
  RenderPadding createRenderObject(BuildContext context) {
    return RenderPadding(
      padding: padding,
      textDirection: Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderPadding renderObject) {
    renderObject
      ..padding = padding
      ..textDirection = Directionality.maybeOf(context);
  }
}

class RenderPadding extends RenderProxyBox {
  RenderPadding({
    required EdgeInsetsGeometry padding,
    TextDirection? textDirection,
  }) : _padding = padding, _textDirection = textDirection;

  EdgeInsets? _resolvedPaddingCache;

  EdgeInsetsGeometry _padding;
  EdgeInsetsGeometry get padding => _padding;
  set padding(EdgeInsetsGeometry value) {
    if (_padding == value) return;
    _padding = value;
    markNeedsLayout();
  }

  TextDirection? _textDirection;
  TextDirection? get textDirection => _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final EdgeInsets resolvedPadding = (_resolvedPaddingCache ??= padding.resolve(textDirection));
    final innerConstraints = constraints.deflate(resolvedPadding);
    if (child != null) {
      final child = this.child!;
      child.layout(innerConstraints, parentUsesSize: true);
      final childSize = child.size;
      size = constraints.constrain(Size(
        resolvedPadding.left + childSize.width + resolvedPadding.right,
        resolvedPadding.top + childSize.height + resolvedPadding.bottom,
      ));
    } else {
      size = constraints.constrain(Size(
        resolvedPadding.left + resolvedPadding.right,
        resolvedPadding.top + resolvedPadding.bottom,
      ));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      final EdgeInsets resolvedPadding = _resolvedPaddingCache!;
      context.paintChild(child!, offset + resolvedPadding.topLeft);
    }
  }

  void _debugDrawDoubleRect(Canvas canvas, Rect outerRect, Rect innerRect, Color color) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(outerRect)
      ..addRect(innerRect);
    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }
  void debugPaintPadding(
    Canvas canvas,
    Rect outerRect,
    Rect? innerRect, {
    double outlineWidth = 2.0,
  }) {
    if (innerRect != null && !innerRect.isEmpty) {
      _debugDrawDoubleRect(canvas, outerRect, innerRect, const Color(0x900090FF));
      _debugDrawDoubleRect(
        canvas,
        innerRect.inflate(outlineWidth).intersect(outerRect),
        innerRect,
        const Color(0xFF0090FF),
      );
    } else {
      final paint = Paint()..color = const Color(0x90909090);
      canvas.drawRect(outerRect, paint);
    }
  }
  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    super.debugPaintSize(context, offset);
    assert(() {
      final Rect outerRect = offset & size;
      debugPaintPadding(
        context.canvas,
        outerRect,
        child != null ? _resolvedPaddingCache!.deflateRect(outerRect) : null,
      );
      return true;
    }());
  }

}

// a box that limits its size only when unconstrained
class LimitedBox extends SingleChildRenderObjectWidget {
  const LimitedBox({
    super.key,
    this.maxWidth = double.infinity,
    this.maxHeight = double.infinity,
    super.child,
  });

  final double maxWidth;
  final double maxHeight;

  @override
  RenderLimitedBox createRenderObject(BuildContext context) => RenderLimitedBox(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

  @override
  void updateRenderObject(BuildContext context, RenderLimitedBox renderObject) {
    renderObject
      ..maxWidth = maxWidth
      ..maxHeight = maxHeight;
  }
}

class RenderLimitedBox extends RenderProxyBox {
  RenderLimitedBox({
    double maxWidth = double.infinity,
    double maxHeight = double.infinity,
  }) : _maxWidth = maxWidth, _maxHeight = maxHeight;

  double get maxWidth => _maxWidth;
  double _maxWidth;
  set maxWidth(double value) {
    if (_maxWidth == value) return;
    _maxWidth = value;
    markNeedsLayout();
  }

  double get maxHeight => _maxHeight;
  double _maxHeight;
  set maxHeight(double value) {
    if (_maxHeight == value) return;
    _maxHeight = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    final BoxConstraints limitedConstraints = BoxConstraints(
      minWidth: constraints.minWidth,
      maxWidth: constraints.hasBoundedWidth ? constraints.maxWidth : maxWidth,
      minHeight: constraints.minHeight,
      maxHeight: constraints.hasBoundedHeight ? constraints.maxHeight : maxHeight,
    );
    if (child != null) {
      child!.layout(limitedConstraints, parentUsesSize: true);
      size = constraints.constrain(child!.size);
    } else {
      size = constraints.constrain(Size.zero);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }
}

class Align extends SingleChildRenderObjectWidget {
  const Align({
    super.key,
    this.alignment = Alignment.center,
    this.widthFactor,
    this.heightFactor,
    super.child,
  });

  final AlignmentGeometry alignment;
  final double? widthFactor;
  final double? heightFactor;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderAlign(
        alignment: alignment,
        widthFactor: widthFactor,
        heightFactor: heightFactor,
        textDirection: Directionality.maybeOf(context),
      );

  @override
  void updateRenderObject(BuildContext context, RenderAlign renderObject) {
    renderObject
      ..alignment = alignment
      ..widthFactor = widthFactor
      ..heightFactor = heightFactor
      ..textDirection = Directionality.maybeOf(context);
  }
}

class Center extends Align {
  const Center({
    super.key,
    super.widthFactor,
    super.heightFactor,
    super.child,
  });
}
