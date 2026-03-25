import 'package:tennoji/src/widgets/framework.dart';
import 'engine.dart';

import 'package:logging/logging.dart';

export 'engine.dart';

void render(Widget root, RenderConfig config) {
  Logger.root.level = config.logLevel;
  Logger.root.onRecord.listen((record) {
    // print('${record.level.name}: ${record.time}: ${record.message}');
    print(record.message);
  });
  
  Engine.init(
    width: config.resolution.width.toInt(),
    height: config.resolution.height.toInt(),
    fps: config.fps,
  );
  
  Engine.instance.run(root, config);
  
  Engine.instance.shutdown();
}
