import '../rendering/media_render.dart';
import 'framework.dart';

class VideoClip extends LeafRenderObjectWidget {
  const VideoClip({
    super.key,
    required this.source,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.playbackSpeed = 1.0,
  });
  final String source;
  final Duration trimStart;
  final Duration? trimEnd;
  final double playbackSpeed;

  @override
  RenderVideoClip createRenderObject(BuildContext context) => RenderVideoClip(
        source: source,
        trimStart: trimStart,
        trimEnd: trimEnd,
        playbackSpeed: playbackSpeed,
      );

  @override
  void updateRenderObject(BuildContext context, RenderVideoClip renderObject) {
    // Update properties if changed
  }
}

class AudioClip extends LeafRenderObjectWidget {
  const AudioClip({
    super.key,
    required this.source,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.volume = 1.0,
  });
  final String source;
  final Duration trimStart;
  final Duration? trimEnd;
  final double volume;

  @override
  RenderAudioClip createRenderObject(BuildContext context) => RenderAudioClip(
        source: source,
        trimStart: trimStart,
        trimEnd: trimEnd,
        volume: volume,
      );
}
