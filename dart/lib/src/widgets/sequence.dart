import 'package:tennoji/src/engine/engine.dart';
import 'package:tennoji/src/rendering/object.dart';
import 'package:tennoji/src/rendering/timeline_parent_data.dart';

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

class Sequence extends StatefulWidget {
  const Sequence({super.key, required this.children});

  final List<Widget> children;

  @override
  State<StatefulWidget> createState() => _SequenceState();
}


class _SequenceState extends State<Sequence> {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(onTick);
  }

  void onTick(Duration d) {}

  @override
  void dispose() {
    _ticker.stop();
    super.dispose();
  }
}
