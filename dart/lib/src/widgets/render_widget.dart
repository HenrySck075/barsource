abstract class BuildContext {
  // Returns the widget that this context is associated with.
  // Typed as dynamic here to avoid circular import with framework.dart.
  // framework.dart provides the concrete Widget type.
  dynamic get widget;

  T? dependOnInheritedWidgetOfExactType<T>();
}
