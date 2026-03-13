import 'package:meta/meta.dart';

@immutable
class Size {
  const Size(this.width, this.height);
  final double width;
  final double height;
  static const Size zero = Size(0, 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Size && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'Size($width, $height)';
}

@immutable
class Offset {
  const Offset(this.dx, this.dy);
  final double dx;
  final double dy;
  static const Offset zero = Offset(0, 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Offset && other.dx == dx && other.dy == dy;

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'Offset($dx, $dy)';
}

@immutable
class Rect {
  const Rect.fromLTWH(this.left, this.top, this.width, this.height);
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rect &&
          other.left == left &&
          other.top == top &&
          other.width == width &&
          other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'Rect.fromLTWH($left, $top, $width, $height)';
}
