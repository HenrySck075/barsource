import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/rendering/timeline_parent_data.dart';

import '../rendering/sequence_render.dart';
import 'framework.dart';

class DurationConstraint extends ParentDataWidget<TimelineParentData> {
  DurationConstraint({required super.child, required this.duration});

  final Duration duration;

  @override
  void applyParentData(RenderObject renderObject) {
    final durationSeconds =
        duration.inMicroseconds / Duration.microsecondsPerSecond;
    if (renderObject.duration == durationSeconds) {
      return;
    }
    renderObject.duration = durationSeconds;
    renderObject.parent?.markNeedsLayout();
  }
}

class Sequence extends MultiChildRenderObjectWidget {
  const Sequence({super.key, required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderSequence();
}
