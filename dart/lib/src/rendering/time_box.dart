import 'box.dart';
import 'object.dart';

class TimeBoxConstraints extends BoxConstraints {
  const TimeBoxConstraints({
    required this.currentTime,
    super.minWidth,
    super.maxWidth,
    super.minHeight,
    super.maxHeight,
  });
  final Duration currentTime;
}

abstract class RenderTimeBox extends RenderBox {
  late TimeBoxConstraints _constraints;

  TimeBoxConstraints get constraints => _constraints;

  @override
  void layout(covariant TimeBoxConstraints constraints,
      {bool parentUsesSize = false}) {
    _constraints = constraints;
    performLayout();
    clearNeedsLayout();
  }
}
