import 'package:barsource/src/dart_ui/dart_ui.dart';
import 'basic_types.dart';

/// Base class for [Alignment] and [AlignmentDirectional].
abstract class AlignmentGeometry {
  const AlignmentGeometry();

  /// Convert this instance into an [Alignment], which uses the top-left origin.
  Alignment resolve(TextDirection? direction);
  
  AlignmentGeometry add(AlignmentGeometry other);
  
  AlignmentGeometry operator -();
  
  AlignmentGeometry operator *(double other);
  
  AlignmentGeometry operator /(double other);
  
  AlignmentGeometry operator ~/(double other);
  
  AlignmentGeometry operator %(double other);
}

/// An alignment along both axes, where (0, 0) is center,
/// (-1, -1) is top-left, and (1, 1) is bottom-right.
class Alignment extends AlignmentGeometry {
  const Alignment(this.x, this.y);
  final double x;
  final double y;

  static const Alignment topLeft = Alignment(-1, -1);
  static const Alignment topCenter = Alignment(0, -1);
  static const Alignment topRight = Alignment(1, -1);
  static const Alignment centerLeft = Alignment(-1, 0);
  static const Alignment center = Alignment(0, 0);
  static const Alignment centerRight = Alignment(1, 0);
  static const Alignment bottomLeft = Alignment(-1, 1);
  static const Alignment bottomCenter = Alignment(0, 1);
  static const Alignment bottomRight = Alignment(1, 1);

  @override
  Alignment resolve(TextDirection? direction) => this;

  Offset alongSize(Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    return Offset(centerX + x * centerX, centerY + y * centerY);
  }
  Offset alongOffset(Offset other) {
    final double centerX = other.dx / 2;
    final double centerY = other.dy / 2;
    return Offset(centerX + x * centerX, centerY + y * centerY);
  }

  @override
  AlignmentGeometry add(AlignmentGeometry other) {
    if (other is Alignment) {
      return Alignment(x + other.x, y + other.y);
    }
    if (other is AlignmentDirectional) {
      return _MixedAlignment(
        x,
        y,
        other.start,
      );
    }
    return other.add(this); // Rely on other's implementation
  }
  
  @override
  Alignment operator -() => Alignment(-x, -y);
  
  @override
  Alignment operator *(double other) => Alignment(x * other, y * other);
  
  @override
  Alignment operator /(double other) => Alignment(x / other, y / other);
  
  @override
  Alignment operator ~/(double other) => Alignment((x ~/ other).toDouble(), (y ~/ other).toDouble());
  
  @override
  Alignment operator %(double other) => Alignment(x % other, y % other);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Alignment && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Alignment($x, $y)';
}

class AlignmentDirectional extends AlignmentGeometry {
  const AlignmentDirectional(this.start, this.y);
  
  final double start;
  final double y;
  
  static const AlignmentDirectional topStart = AlignmentDirectional(-1.0, -1.0);
  static const AlignmentDirectional topCenter = AlignmentDirectional(0.0, -1.0);
  static const AlignmentDirectional topEnd = AlignmentDirectional(1.0, -1.0);
  static const AlignmentDirectional centerStart = AlignmentDirectional(-1.0, 0.0);
  static const AlignmentDirectional center = AlignmentDirectional(0.0, 0.0);
  static const AlignmentDirectional centerEnd = AlignmentDirectional(1.0, 0.0);
  static const AlignmentDirectional bottomStart = AlignmentDirectional(-1.0, 1.0);
  static const AlignmentDirectional bottomCenter = AlignmentDirectional(0.0, 1.0);
  static const AlignmentDirectional bottomEnd = AlignmentDirectional(1.0, 1.0);

  @override
  Alignment resolve(TextDirection? direction) {
    assert(direction != null, 'Cannot resolve AlignmentDirectional without a TextDirection.');
    switch (direction!) {
      case TextDirection.rtl:
        return Alignment(-start, y);
      case TextDirection.ltr:
        return Alignment(start, y);
    }
  }

  @override
  AlignmentGeometry add(AlignmentGeometry other) {
    if (other is AlignmentDirectional) {
      return AlignmentDirectional(start + other.start, y + other.y);
    }
    if (other is Alignment) {
      return _MixedAlignment(
        other.x,
        other.y,
        start,
      );
    }
    return other.add(this);
  }
  
  @override
  AlignmentDirectional operator -() => AlignmentDirectional(-start, -y);
  
  @override
  AlignmentDirectional operator *(double other) => AlignmentDirectional(start * other, y * other);
  
  @override
  AlignmentDirectional operator /(double other) => AlignmentDirectional(start / other, y / other);
  
  @override
  AlignmentDirectional operator ~/(double other) => AlignmentDirectional((start ~/ other).toDouble(), (y ~/ other).toDouble());
  
  @override
  AlignmentDirectional operator %(double other) => AlignmentDirectional(start % other, y % other);
  
  @override
  String toString() => 'AlignmentDirectional($start, $y)';
}

class _MixedAlignment extends AlignmentGeometry {
  const _MixedAlignment(this._x, this._y, this._start);
  
  final double _x;
  final double _y;
  final double _start;
  
  @override
  Alignment resolve(TextDirection? direction) {
    assert(direction != null, 'Cannot resolve mixed AlignmentGeometry without a TextDirection.');
    switch (direction!) {
      case TextDirection.rtl:
        return Alignment(_x - _start, _y);
      case TextDirection.ltr:
        return Alignment(_x + _start, _y);
    }
  }
  
  @override
  AlignmentGeometry add(AlignmentGeometry other) {
     if (other is Alignment) {
       return _MixedAlignment(_x + other.x, _y + other.y, _start);
     }
     if (other is AlignmentDirectional) {
       return _MixedAlignment(_x, _y + other.y, _start + other.start);
     }
     if (other is _MixedAlignment) {
       return _MixedAlignment(_x + other._x, _y + other._y, _start + other._start);
     }
     return this;
  }
  
  @override
  _MixedAlignment operator -() => _MixedAlignment(-_x, -_y, -_start);
  
  @override
  _MixedAlignment operator *(double other) => _MixedAlignment(_x * other, _y * other, _start * other);
  
  @override
  _MixedAlignment operator /(double other) => _MixedAlignment(_x / other, _y / other, _start / other);
  
  @override
  _MixedAlignment operator ~/(double other) => _MixedAlignment((_x ~/ other).toDouble(), (_y ~/ other).toDouble(), (_start ~/ other).toDouble());
  
  @override
  _MixedAlignment operator %(double other) => _MixedAlignment(_x % other, _y % other, _start % other);
}
