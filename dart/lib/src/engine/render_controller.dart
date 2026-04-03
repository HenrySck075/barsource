import 'package:barsource/src/widgets/framework.dart';
import 'engine.dart';

import 'package:logging/logging.dart';

export 'engine.dart';

Future<void> render(Widget root, RenderConfig config) async {
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
  
  await Engine.instance.run(root, config);
  
  Engine.instance.shutdown();
}
