import 'object.dart';

abstract class RenderBox extends RenderObject {
  late BoxConstraints _constraints;

  BoxConstraints get constraints => _constraints;

  @override
  void layout(covariant BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    _constraints = constraints;
    performLayout();
    clearNeedsLayout();
  }

  void performLayout();
}
