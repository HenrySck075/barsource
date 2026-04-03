import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/rendering/timeline_parent_data.dart';

import '../rendering/sequence_render.dart'; 
import 'framework.dart';

class DurationConstraint extends ParentDataWidget<TimelineParentData> {
  DurationConstraint({
    required super.child,
    required this.duration
  });

  final Duration duration;

  @override
  void applyParentData(RenderObject renderObject) {
    (renderObject.parentData! as TimelineParentData).duration = duration;
  }
}

class Sequence extends MultiChildRenderObjectWidget {
  const Sequence({super.key, required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderSequence(); 
}

