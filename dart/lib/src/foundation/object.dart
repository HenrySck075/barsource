
String objectRuntimeType(Object? obj, String optimizedValue) {
  assert(() {
    optimizedValue = obj.runtimeType.toString();
    return true;
  }());
  return optimizedValue;
}
