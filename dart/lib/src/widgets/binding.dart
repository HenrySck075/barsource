import 'package:tennoji/src/foundation/binding_base.dart';
import 'package:tennoji/src/rendering/binding.dart';
import 'package:tennoji/src/scheduler/binding.dart';
import 'package:tennoji/src/elements/framework.dart';
import 'package:tennoji/src/widgets/framework.dart';
import 'package:tennoji/src/rendering/box.dart';

mixin WidgetsBinding on BindingBase, RendererBinding, SchedulerBinding {
  BuildOwner? _buildOwner;
  Element? _renderViewElement;

  BuildOwner get buildOwner => _buildOwner!;

  @override
  void initInstances() {
    super.initInstances();
    _buildOwner = BuildOwner();
  }

  void attachRootWidget(Widget app) {
    _renderViewElement = app.createElement();
    _renderViewElement!.assignOwner(_buildOwner!);
    _renderViewElement!.mount(null, null);
    
    // Attach render object
    final renderObject = _renderViewElement!.renderObject;
    if (renderObject is RenderBox) {
      renderView.child = renderObject;
    }
  }

  @override
  void drawFrame() {
    _buildOwner!.buildScope(_renderViewElement!);
    super.drawFrame();
  }

  void detachRootWidget() {
    _renderViewElement?.unmount();
    _renderViewElement = null;
  }
}

