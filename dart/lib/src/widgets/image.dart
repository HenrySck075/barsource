import 'dart:io';

import 'package:tennoji/src/dart_ui/dart_ui.dart';
import 'package:tennoji/src/elements/framework.dart';
import 'package:tennoji/src/engine/engine.dart';
import 'package:tennoji/src/foundation/key.dart';
import 'package:tennoji/src/rendering/box.dart';
import 'package:tennoji/src/rendering/object.dart';
import 'package:tennoji/src/rendering/pipeline_owner.dart';
import 'package:tennoji/src/widgets/framework.dart';
import 'package:tennoji/dart_ui.dart' as ui;

// like flutter
enum ResizeImagePolicy {exact, fit}

abstract class Image extends LeafRenderObjectWidget {
  const Image({
    super.key,
    this.targetWidth,
    this.targetHeight,
    this.resizePolicy = .exact,
  });
  final int? targetWidth;
  final int? targetHeight;
  final ResizeImagePolicy resizePolicy;

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
    return _RenderLocalImage(source)
      ..targetWidth = targetWidth
      ..targetHeight = targetHeight
      ..resizePolicy = resizePolicy;
  }
  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    if (renderObject is _RenderLocalImage) {
      renderObject
        ..targetWidth = targetWidth
        ..targetHeight = targetHeight
        ..resizePolicy = resizePolicy;
    }
  }
}
class _RenderLocalImage extends RenderBox {
  String source;
  late ui.Codec codec;
  ui.FrameInfo? currentFrameInfo;
  Duration durationFromLastFrame = Duration.zero;
  int? targetWidth;
  int? targetHeight;
  ResizeImagePolicy resizePolicy = .exact;

  /// This is NOT `size`, but for the size of the rendering image itself.
  int renderWidth = 0;
  int renderHeight = 0;

  void computeRenderDimension() {
    if (resizePolicy == ResizeImagePolicy.exact) {
      renderWidth = targetWidth ?? currentFrameInfo!.image.width;
      renderHeight = targetHeight ?? currentFrameInfo!.image.height;
    } else if (resizePolicy == ResizeImagePolicy.fit) {
      final imageAspectRatio = currentFrameInfo!.image.width / currentFrameInfo!.image.height;
      final targetAspectRatio = (targetWidth ?? currentFrameInfo!.image.width) / (targetHeight ?? currentFrameInfo!.image.height);

      if (imageAspectRatio > targetAspectRatio) {
        // Image is wider than target, fit to width
        renderWidth = targetWidth ?? currentFrameInfo!.image.width;
        renderHeight = (renderWidth / imageAspectRatio).round();
      } else {
        // Image is taller than target, fit to height
        renderHeight = targetHeight ?? currentFrameInfo!.image.height;
        renderWidth = (renderHeight * imageAspectRatio).round();
      }
    }
  }

  late Ticker ticker;

  _RenderLocalImage(this.source) {
    // read the file content 
    final file = File(source);
    final bytes = file.readAsBytesSync();
    final descriptor = ImageDescriptor.encoded(bytes);
    codec = descriptor.instantiateCodec();

    currentFrameInfo = codec.getNextFrame();

    ticker = Ticker(_tick);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    ticker.start();
  }
  @override
  void performLayout() {
    final image = currentFrameInfo?.image;
    size = image != null 
           ? Size(image.width.toDouble(), image.height.toDouble())
           : constraints.smallest;
    computeRenderDimension();
  }
  void _tick(Duration elapsed) {
    if (currentFrameInfo == null) return;

    if (durationFromLastFrame + currentFrameInfo!.duration < elapsed) {
      currentFrameInfo = codec.getNextFrame();
      markNeedsLayout();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var frame = currentFrameInfo;
    if (frame != null) {
      // we would like to place the image at the center of the box
      final imageOffset = Offset(
        offset.dx + (size.width - renderWidth) / 2,
        offset.dy + (size.height - renderHeight) / 2,
      );
    }
  }

  @override
  void dispose() {
    currentFrameInfo?.image.dispose();
    ticker.stop();
    ticker.dispose();
    super.dispose();
  }
}
