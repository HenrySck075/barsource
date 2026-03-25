import 'package:tennoji/src/widgets/framework.dart';
import 'engine.dart';

export 'engine.dart';

void render(Widget root, RenderConfig config) {
  Engine.init(
    width: config.resolution.width.toInt(),
    height: config.resolution.height.toInt(),
    fps: config.fps,
  );
  
  Engine.instance.run(root, config);
  
  Engine.instance.shutdown();
}
