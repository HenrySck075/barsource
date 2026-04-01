import 'dart:io';

import 'package:tennoji/src/dart_ui/dart_ui.dart';
import 'package:tennoji/src/engine/engine.dart';
import 'package:tennoji/src/foundation/key.dart';
import 'package:tennoji/src/rendering/box.dart';
import 'package:tennoji/src/rendering/object.dart';
import 'package:tennoji/src/rendering/pipeline_owner.dart';
import 'package:tennoji/src/scheduler/ticker.dart';
import 'package:tennoji/src/widgets/framework.dart';
import 'package:tennoji/dart_ui.dart' as ui;

abstract class Image extends LeafRenderObjectWidget {
  const Image({super.key});

  factory Image.file(String src, {Key? key}) => _LocalImage(
    key: key,
    source: src
  );
}

class _LocalImage extends Image {
  final String source;

  const _LocalImage({
    super.key,
    required this.source
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLocalImage(source);
  }
}
class _RenderLocalImage extends RenderBox {
  String source;
  late ui.Codec codec;
  ui.FrameInfo? currentFrameInfo;
  Duration durationFromLastFrame = Duration.zero;

  late EngineStopwatch stopwatch;

  _RenderLocalImage(this.source) {
    // read the file content 
    final file = File(source);
    final bytes = file.readAsBytesSync();
    final descriptor = ImageDescriptor.encoded(bytes);
    codec = descriptor.instantiateCodec();

    currentFrameInfo = codec.getNextFrame();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    stopwatch.start();
  }

  @override
  void performLayout() {
    final image = currentFrameInfo?.image;
    size = image != null 
           ? Size(image.width.toDouble(), image.height.toDouble())
           : constraints.smallest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var frame = currentFrameInfo;
    while (
      frame != null && 
      frame.duration != Duration.zero && 
      frame.duration < stopwatch.elapsed - durationFromLastFrame
    ) {
      frame.image.dispose();
      currentFrameInfo = frame = codec.getNextFrame(); 
    }
    if (frame != null) {
      durationFromLastFrame = stopwatch.elapsed;

      context.canvas.drawImage(frame.image, offset, Paint());
    }
  }

  @override
  void dispose() {
    currentFrameInfo?.image.dispose();
    super.dispose();
  }
}
