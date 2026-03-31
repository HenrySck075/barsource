import 'package:meta/meta.dart';
import 'package:tennoji/src/painting/basic_types.dart';
import 'package:tennoji/src/rendering/parent_data.dart';

import '../foundation/key.dart';
import '../rendering/object.dart';
import '../elements/framework.dart' as elements;

export '../elements/framework.dart' show BuildContext;


@immutable
abstract class Widget {
  const Widget({this.key});
  final Key? key;
  elements.Element createElement();

  static bool canUpdate(Widget oldWidget, Widget newWidget) {
    return oldWidget.runtimeType == newWidget.runtimeType && oldWidget.key == newWidget.key;
  }
}

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});
  Widget build(elements.BuildContext context);
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
  elements.BuildContext get context => _element!;
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
  Widget build(elements.BuildContext context);

  void setState(VoidCallback fn) {
    print("e");
    fn();
    _element!.markNeedsBuild();
  }
}

abstract class RenderObjectWidget extends Widget {
  const RenderObjectWidget({super.key});
  RenderObject createRenderObject(elements.BuildContext context);
  void updateRenderObject(
      elements.BuildContext context, covariant RenderObject renderObject) {}
  void didUnmountRenderObject(covariant RenderObject object) {}
}

abstract class LeafRenderObjectWidget extends RenderObjectWidget {
  const LeafRenderObjectWidget({super.key});
  @override
  elements.LeafRenderObjectElement createElement() => elements.LeafRenderObjectElement(this);
}

abstract class SingleChildRenderObjectWidget extends RenderObjectWidget {
  const SingleChildRenderObjectWidget({super.key, this.child});
  final Widget? child;
  @override
  elements.SingleChildRenderObjectElement createElement() => elements.SingleChildRenderObjectElement(this);
}

abstract class MultiChildRenderObjectWidget extends RenderObjectWidget {
  const MultiChildRenderObjectWidget(
      {super.key, this.children = const []});
  final List<Widget> children;
  @override
  elements.MultiChildRenderObjectElement createElement() => elements.MultiChildRenderObjectElement(this);
}
abstract class ProxyWidget extends Widget {
  /// Creates a widget that has exactly one child widget.
  const ProxyWidget({super.key, required this.child});
  final Widget child;
}
abstract class ParentDataWidget<T extends ParentData> extends ProxyWidget {
  ParentDataWidget({super.key, required super.child});

  @protected
  void applyParentData(RenderObject renderObject);

  @override
  elements.Element createElement() => elements.ParentDataElement<T>(this); 
}
abstract class InheritedWidget extends ProxyWidget {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const InheritedWidget({super.key, required super.child});

  @override
  elements.InheritedElement createElement() => elements.InheritedElement(this);

  /// Whether the framework should notify widgets that inherit from this widget.
  ///
  /// When this widget is rebuilt, sometimes we need to rebuild the widgets that
  /// inherit from this widget but sometimes we do not. For example, if the data
  /// held by this widget is the same as the data held by `oldWidget`, then we
  /// do not need to rebuild the widgets that inherited the data held by
  /// `oldWidget`.
  ///
  /// The framework distinguishes these cases by calling this function with the
  /// widget that previously occupied this location in the tree as an argument.
  /// The given widget is guaranteed to have the same [runtimeType] as this
  /// object.
  @protected
  bool updateShouldNotify(covariant InheritedWidget oldWidget);
}
