import 'package:barsource/src/foundation/binding_base.dart';
import 'package:barsource/src/rendering/binding.dart';
import 'package:barsource/src/scheduler/binding.dart';
import 'package:barsource/src/elements/framework.dart';
import 'package:barsource/src/widgets/framework.dart';
import 'package:barsource/src/rendering/box.dart';

mixin WidgetsBinding on BindingBase, RendererBinding, SchedulerBinding {
  BuildOwner? _buildOwner;
  Element? _renderViewElement;

  BuildOwner get buildOwner => _buildOwner!;

  static WidgetsBinding? _instance;
  static WidgetsBinding get instance => BindingBase.checkInstance(_instance);

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    _buildOwner = BuildOwner();
  }

  void attachRootWidget(Widget app) {
    _renderViewElement = app.createElement();
    _renderViewElement!.assignOwner(_buildOwner!);
    _buildOwner!.buildScope(_renderViewElement!, (){
      _renderViewElement!.mount(null, null);
    });
    
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

