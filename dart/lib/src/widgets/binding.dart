import 'package:barsource/src/foundation/binding_base.dart';
import 'package:barsource/src/rendering/binding.dart';
import 'package:barsource/src/scheduler/binding.dart';
import 'package:barsource/src/elements/framework.dart';
import 'package:barsource/src/widgets/framework.dart';
import 'package:barsource/src/widgets/root.dart';
import 'package:barsource/src/rendering/box.dart';
import 'package:meta/meta.dart';

mixin WidgetsBinding on BindingBase, SchedulerBinding, RendererBinding {
  BuildOwner? _buildOwner;
  Element? _renderViewElement;

  @protected
  Element get renderViewElement => _renderViewElement!;

  BuildOwner get buildOwner => _buildOwner!;

  static WidgetsBinding? _instance;
  static WidgetsBinding get instance => BindingBase.checkInstance(_instance);

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    _buildOwner = BuildOwner();
  }

  void attachRootWidget(RootWidget app) {
    _renderViewElement = app.createElement();
    _renderViewElement!.assignOwner(_buildOwner!);
    _buildOwner!.buildScope(_renderViewElement!, (){
      _renderViewElement!.mount(null, null);
    });
    
    /*
    // Attach render object
    final renderObject = _renderViewElement!.renderObject;
    if (renderObject is RenderBox) {
      renderView.child = renderObject;
    }
    */
  }

  @override
  void drawFrame() {
    _buildOwner!.buildScope(_renderViewElement!);
    super.drawFrame();
  }

  void detachRootWidget() {
    // ignore: invalid_use_of_visible_for_overriding_member
    _renderViewElement?.deactivate();
    _renderViewElement?.unmount();
    _renderViewElement = null;
  }

  @override
  void reassembleApplication() {
    if (_renderViewElement != null) {
      _renderViewElement!.reassemble();
    }

    super.reassembleApplication();
  }
}

