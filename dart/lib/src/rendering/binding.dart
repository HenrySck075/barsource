import 'package:barsource/src/foundation/binding_base.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/rendering/view.dart';

mixin RendererBinding on BindingBase {
  PipelineOwner? _pipelineOwner;
  RenderView? _renderView;

  PipelineOwner get pipelineOwner => _pipelineOwner!;
  RenderView get renderView => _renderView!;

  @override
  void initInstances() {
    super.initInstances();
    _pipelineOwner = PipelineOwner();
  }

  void initRenderView(ViewConfiguration configuration) {
    _renderView = RenderView(configuration: configuration);
    _renderView!.attach(_pipelineOwner!);
  }

  void drawFrame() {
    assert(_renderView != null);
    pipelineOwner.flushLayout();
    // Painting is handled by Engine manually for now due to canvas requirement
  }
}
