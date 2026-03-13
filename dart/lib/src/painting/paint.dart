class Color {
  const Color(this.value);
  final int value;

  int get alpha => (value >> 24) & 0xFF;
  int get red => (value >> 16) & 0xFF;
  int get green => (value >> 8) & 0xFF;
  int get blue => value & 0xFF;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Color && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Color(0x${value.toRadixString(16).padLeft(8, '0')})';
}

class Paint {
  Color color = const Color(0xFF000000);
  double strokeWidth = 1.0;
  bool isAntiAlias = true;
}
