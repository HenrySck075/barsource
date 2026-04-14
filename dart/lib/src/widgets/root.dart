import 'package:barsource/src/elements/framework.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/widgets/framework.dart';

/// Wrapper widget that serves as the root of the element tree.
/// 
/// Accepts a [child] widget and a [container] render object. The container
/// is used as the root of the render object tree and delegates to the passed-in
/// render object container.
class RootWidget<T extends RenderObject> extends SingleChildRenderObjectWidget {
  const RootWidget({
    super.key,
    required super.child,
    required this.container,
  });

  final RenderObjectWithChildMixin<T> container;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return container as RenderObject;
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    // No-op: container is managed externally
  }

  @override
  SingleChildRenderObjectElement createElement() => RootElement(this);
}

/// Element for [RootWidget].
/// 
/// Specialized render object element that serves as the root of the render object tree.
/// Unlike regular RenderObjectElements, RootElement does not search for an ancestor
/// RenderObjectElement, as it IS the root ancestor that all render objects attach to.
class RootElement extends SingleChildRenderObjectElement {
  RootElement(super.widget);

  @override
  RootWidget get widget => super.widget as RootWidget;

  @override
  void attachRenderObject(Object? newSlot) {
    // RootElement is the root of the render object tree, so it has no ancestor.
    // Override to avoid searching for a parent RenderObjectElement.
  }

  @override
  void detachRenderObject() {
    // RootElement has no ancestor to notify, so skip the ancestor removal logic.
  }
}
