import 'dart:async';
import 'package:logging/logging.dart';

import 'package:tennoji/tennoji.dart';

import 'package:example/example.1.dart';


Future<void> main() async {
 await render(bomb(), RenderConfig(
    output: "out.mp4", 
    duration: Duration(seconds: 4, milliseconds: 500), 
    fps: 30, 
    resolution: Size(1280,720),
    logLevel: Level.OFF
  ));
}
