import 'package:barsource/src/foundation/binding_base.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/rendering/view.dart';
import 'package:barsource/src/scheduler/binding.dart';

mixin RendererBinding on BindingBase, SchedulerBinding {
  PipelineOwner? _pipelineOwner;
  RenderView? _renderView;

  PipelineOwner get pipelineOwner => _pipelineOwner!;
  RenderView get renderView => _renderView!;

  @override
  void initInstances() {
    super.initInstances();
    _pipelineOwner = PipelineOwner();
    print("adding drawFrame to persistent callback");
    addPersistentFrameCallback((_)=>drawFrame());
  }

  void initRenderView(ViewConfiguration configuration) {
    _renderView = RenderView(configuration: configuration);
    _renderView!.attach(_pipelineOwner!);
  }

  void drawFrame() {
    assert(_renderView != null);
    pipelineOwner.flushLayout();
    pipelineOwner.flushPaint();
    // Painting is handled by Engine manually for now due to canvas requirement
  }
}
