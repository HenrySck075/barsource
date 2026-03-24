import 'package:tennoji/src/dart_ui/dart_ui.dart';
import 'package:tennoji/src/elements/framework.dart';
import 'package:tennoji/src/painting/box_decoration.dart';
import 'package:tennoji/src/painting/decoration.dart';
import 'package:tennoji/src/painting/edge_insets.dart';
import 'package:tennoji/src/painting/alignment.dart';
import 'package:vector_math/vector_math.dart' show Matrix4;

import '../rendering/object.dart';
import '../rendering/box.dart';
import '../rendering/align_render.dart' show RenderAlign;
import 'framework.dart';

export 'package:tennoji/src/painting/edge_insets.dart';
export 'package:tennoji/src/painting/alignment.dart';

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
    this.decoration,
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
  final Decoration? decoration;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? margin;
  final Matrix4? transform;

  @override
  Widget build(BuildContext context) {
    Widget? current = child;

    if (child == null && (width == null || height == null)) {
      current = SizedBox(width: width, height: height); 
    } else {
      current = Align(alignment: alignment ?? Alignment.center, child: current);
    }

    EdgeInsetsGeometry? effectivePadding = padding;
    if (decoration != null) {
      if (effectivePadding == null) {
        effectivePadding = decoration!.padding;
      } else {
        effectivePadding = effectivePadding.add(decoration!.padding);
      }
    }

    if (effectivePadding != null) {
      current = Padding(padding: effectivePadding, child: current);
    }

    if (color != null) {
      current = DecoratedBox(decoration: BoxDecoration(color: color), child: current);
    } else if (decoration != null) {
      current = DecoratedBox(decoration: decoration!, child: current);
    }

    if (width != null || height != null) {
      current = SizedBox(width: width, height: height, child: current);
    }

    if (margin != null) {
      current = Padding(padding: margin as EdgeInsets, child: current);
    }

    return current!;
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

class RenderDecoratedBox extends RenderBox with ContainerRenderObjectMixin {
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
    markNeedsPaint();
  }

  DecorationPosition _position;
  DecorationPosition get position => _position;
  set position(DecorationPosition value) {
    if (_position == value) return;
    _position = value;
    markNeedsPaint();
  }

  ImageConfiguration _configuration;
  ImageConfiguration get configuration => _configuration;
  set configuration(ImageConfiguration value) {
    if (_configuration == value) return;
    _configuration = value;
    markNeedsPaint();
  }

  BoxPainter? _painter;

  @override
  void performLayout() {
    if (children.isEmpty) {
      size = constraints.constrain(Size.zero);
    } else {
      final child = children.first;
      child.layout(constraints, parentUsesSize: true);
      size = child.size;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _painter ??= _decoration.createBoxPainter(markNeedsPaint);
    final ImageConfiguration filledConfiguration = configuration.copyWith(size: size);
    
    if (position == DecorationPosition.background) {
      _painter!.paint(context.canvas, offset, filledConfiguration);
    }
    
    if (children.isNotEmpty) {
      context.paintChild(children.first, offset);
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

// Render objects for basic widgets

class RenderSizedBox extends RenderBox with ContainerRenderObjectMixin {
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

    if (children.isNotEmpty) {
      final child = children.first;
      child.layout(childConstraints, parentUsesSize: true);
      size = constraints.constrain(Size(
        width ?? child.size.width,
        height ?? child.size.height,
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
    if (children.isNotEmpty) {
      context.paintChild(children.first, offset);
    }
  }
}

class RenderPadding extends RenderBox with ContainerRenderObjectMixin {
  RenderPadding({
    required EdgeInsetsGeometry padding,
    TextDirection? textDirection,
  }) : _padding = padding, _textDirection = textDirection;

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
    final EdgeInsets resolvedPadding = padding.resolve(textDirection);
    final innerConstraints = constraints.deflate(resolvedPadding);
    if (children.isNotEmpty) {
      final child = children.first;
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
    if (children.isNotEmpty) {
      final EdgeInsets resolvedPadding = padding.resolve(textDirection);
      context.paintChild(children.first, offset + resolvedPadding.topLeft);
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
