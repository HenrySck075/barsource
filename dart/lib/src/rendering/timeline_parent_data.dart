import 'package:barsource/src/rendering/box.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/rendering/parent_data.dart';

class TimelineParentData extends ParentData with ContainerParentDataMixin<RenderBox> {
  Duration duration = Duration.zero; // means infinite
  Duration delay = Duration.zero;
}
