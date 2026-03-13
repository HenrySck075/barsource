import 'package:meta/meta.dart';

@immutable
abstract class Key {
  const Key();
}

class ValueKey<T> extends Key {
  const ValueKey(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValueKey<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class ObjectKey extends Key {
  const ObjectKey(this.value);
  final Object value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectKey && identical(other.value, value);

  @override
  int get hashCode => identityHashCode(value);
}
