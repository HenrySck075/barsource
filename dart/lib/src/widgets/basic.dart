import '../painting/paint.dart';
import '../rendering/object.dart';
import '../rendering/box.dart';
import '../rendering/align_render.dart';
import '../foundation/geometry.dart';
import 'framework.dart';

class Container extends SingleChildRenderObjectWidget {
  const Container({
    super.key,
    this.width,
    this.height,
    this.color,
    super.child,
  });
  final double? width;
  final double? height;
  final Color? color;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderContainer(
        width: width,
        height: height,
        color: color,
      );
}

class SizedBox extends SingleChildRenderObjectWidget {
  const SizedBox({super.key, this.width, this.height, super.child});
  final double? width;
  final double? height;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderSizedBox(
        width: width,
        height: height,
      );
}

class Padding extends SingleChildRenderObjectWidget {
  const Padding({super.key, required this.padding, super.child});
  final EdgeInsets padding;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderPadding();
}

class EdgeInsets {
  const EdgeInsets.all(double value)
      : left = value,
        top = value,
        right = value,
        bottom = value;

  const EdgeInsets.only({
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

// Render objects for basic widgets

class RenderContainer extends RenderBox {
  RenderContainer({this.width, this.height, this.color});
  final double? width;
  final double? height;
  final Color? color;

  @override
  void performLayout() {
    size = Size(
      width ?? constraints.maxWidth,
      height ?? constraints.maxHeight,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (color != null) {
      context.canvas.drawRect(
        Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
        Paint()..color = color!,
      );
    }
  }
}

class RenderSizedBox extends RenderBox {
  RenderSizedBox({this.width, this.height});
  final double? width;
  final double? height;

  @override
  void performLayout() {
    size = Size(
      width ?? constraints.maxWidth,
      height ?? constraints.maxHeight,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {}
}

class RenderPadding extends RenderBox {
  @override
  void performLayout() {
    size = Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {}
}

class Align extends SingleChildRenderObjectWidget {
  const Align({
    super.key,
    this.alignment = Alignment.center,
    this.widthFactor,
    this.heightFactor,
    super.child,
  });

  final Alignment alignment;
  final double? widthFactor;
  final double? heightFactor;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderAlign(
        alignment: alignment,
        widthFactor: widthFactor,
        heightFactor: heightFactor,
      );
}

class Center extends Align {
  const Center({
    super.key,
    super.widthFactor,
    super.heightFactor,
    super.child,
  });
}
