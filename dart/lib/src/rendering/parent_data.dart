import 'package:meta/meta.dart';
import 'package:tennoji/src/dart_ui/dart_ui.dart';

class ParentData {
  @protected
  void detach() {}//idk
}


class BoxParentData extends ParentData {
  Offset offset = Offset.zero;

  @override
  String toString() => "offset=$offset";
}


