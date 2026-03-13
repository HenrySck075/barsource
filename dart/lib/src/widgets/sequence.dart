import '../rendering/sequence_render.dart';
import 'framework.dart';

class Sequence extends MultiChildRenderObjectWidget {
  const Sequence({super.key, super.children});

  @override
  RenderSequence createRenderObject(BuildContext context) => RenderSequence();
}
