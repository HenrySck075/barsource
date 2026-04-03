import 'package:barsource/src/painting/basic_types.dart';

abstract class EdgeInsetsGeometry {
  const EdgeInsetsGeometry();

  bool get isNonNegative => true;

  EdgeInsets resolve(TextDirection? direction);
  
  EdgeInsetsGeometry add(EdgeInsetsGeometry other);
}

class EdgeInsets extends EdgeInsetsGeometry {
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

  const EdgeInsets.symmetric({
    double vertical = 0.0,
    double horizontal = 0.0,
  }) : left = horizontal,
       top = vertical,
       right = horizontal,
       bottom = vertical;

  static const EdgeInsets zero = EdgeInsets.only();

  final double left;
  final double top;
  final double right;
  final double bottom;

  @override
  bool get isNonNegative =>
      left >= 0.0 && top >= 0.0 && right >= 0.0 && bottom >= 0.0;

  Offset get topLeft => Offset(left, top);

  @override
  EdgeInsets resolve(TextDirection? direction) => this;

  @override
  EdgeInsetsGeometry add(EdgeInsetsGeometry other) {
    if (other is EdgeInsets) {
      return EdgeInsets.only(
        left: left + other.left,
        top: top + other.top,
        right: right + other.right,
        bottom: bottom + other.bottom,
      );
    }
    throw UnimplementedError("idk what did gemini think to call an abstract function like its the tool from their creator but yeah its unimplemented");
    //return super.add(other); // Should implement proper addition for other types
  }
}
