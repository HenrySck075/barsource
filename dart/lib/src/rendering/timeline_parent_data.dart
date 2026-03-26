import 'package:tennoji/src/rendering/box.dart';
import 'package:tennoji/src/rendering/object.dart';
import 'package:tennoji/src/rendering/parent_data.dart';

class TimelineParentData extends ParentData with ContainerParentDataMixin<RenderBox> {
  Duration duration = Duration.zero; // means infinite
  Duration delay = Duration.zero;
}
