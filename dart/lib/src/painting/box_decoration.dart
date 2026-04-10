import 'package:barsource/src/painting/basic_types.dart';
import 'package:barsource/src/painting/border_radius.dart';
import 'package:barsource/src/painting/decoration.dart';
import 'package:barsource/src/painting/edge_insets.dart';

class BoxDecoration extends Decoration {
  const BoxDecoration({
    this.color,
    this.image,
    this.border,
    this.borderRadius,
    this.boxShadow,
    this.gradient,
    this.backgroundBlendMode,
    this.shape = BoxShape.rectangle,
  });

  final Color? color;
  final DecorationImage? image;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  final BlendMode? backgroundBlendMode;
  final BoxShape shape;

  @override
  EdgeInsetsGeometry get padding => border?.dimensions ?? EdgeInsets.zero;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    assert(onChanged != null || image == null);
    return _BoxDecorationPainter(this, onChanged);
  }
}

class _BoxDecorationPainter extends BoxPainter {
  _BoxDecorationPainter(this._decoration, VoidCallback? onChanged)
      : super(onChanged);

  final BoxDecoration _decoration;

  Paint? _paint;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    // Basic rectangle painting implementation for now
    if (_decoration.color != null) {
      final Paint paint = Paint()..color = _decoration.color!;
      final Rect rect = offset & (configuration.size ?? Size.zero);
      canvas.drawRect(rect, paint);
    }
    // TODO: Implement other properties (border, borderRadius, etc.)
  }
}

// Minimal placeholder classes for properties
class BoxBorder {
  const BoxBorder();
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
}
class DecorationImage {}
class BoxShadow {}
class Gradient {}
enum BoxShape { rectangle, circle }
