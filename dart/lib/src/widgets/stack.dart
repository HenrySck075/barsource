import '../rendering/stack_render.dart';
import 'framework.dart';

class Stack extends MultiChildRenderObjectWidget {
  const Stack({super.key, super.children});

  @override
  RenderStack createRenderObject(BuildContext context) => RenderStack();
}
