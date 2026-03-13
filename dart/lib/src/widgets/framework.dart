import 'package:meta/meta.dart';

import '../foundation/key.dart';
import '../rendering/object.dart';
import '../elements/framework.dart' as elements;
import 'render_widget.dart';

export 'render_widget.dart' show BuildContext;

typedef VoidCallback = void Function();

@immutable
abstract class Widget {
  const Widget({this.key});
  final Key? key;
  elements.Element createElement();
}

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});
  Widget build(BuildContext context);
  @override
  elements.Element createElement() => elements.StatelessElement(this);
}

abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
  State createState();
  @override
  elements.Element createElement() => elements.StatefulElement(this);
}

abstract class State<T extends StatefulWidget> {
  T get widget => _widget!;
  T? _widget;
  BuildContext get context => _element!;
  elements.StatefulElement? _element;

  // Called by StatefulElement to wire up the state
  void bindElement(elements.StatefulElement element) {
    _element = element;
  }

  void bindWidget(T widget) {
    _widget = widget;
  }

  void initState() {}
  void didUpdateWidget(covariant T oldWidget) {}
  void dispose() {}
  Widget build(BuildContext context);

  void setState(VoidCallback fn) {
    fn();
    _element!.markNeedsBuild();
  }
}

abstract class RenderObjectWidget extends Widget {
  const RenderObjectWidget({super.key});
  RenderObject createRenderObject(BuildContext context);
  void updateRenderObject(
      BuildContext context, covariant RenderObject renderObject) {}
  @override
  elements.Element createElement() => elements.RenderObjectElement(this);
}

abstract class LeafRenderObjectWidget extends RenderObjectWidget {
  const LeafRenderObjectWidget({super.key});
}

abstract class SingleChildRenderObjectWidget extends RenderObjectWidget {
  const SingleChildRenderObjectWidget({super.key, this.child});
  final Widget? child;
}

abstract class MultiChildRenderObjectWidget extends RenderObjectWidget {
  const MultiChildRenderObjectWidget(
      {super.key, this.children = const []});
  final List<Widget> children;
}
