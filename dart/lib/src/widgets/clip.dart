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

class AudioClip extends SingleChildRenderObjectWidget {
  const AudioClip({
    super.key,
    super.child,
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

  @override
  void updateRenderObject(BuildContext context, RenderAudioClip renderObject) {
    // Audio clip properties are immutable after decoder creation.
  }
}

class AudioRepeat extends SingleChildRenderObjectWidget {
  AudioRepeat({super.key, super.child, this.repeatCount})
    : assert(repeatCount == null || repeatCount > 0);
  /// How many loops to play. `null` means infinite repeat.
  final int? repeatCount;

  @override
  RenderRepeatAudio createRenderObject(BuildContext context) {
    return RenderRepeatAudio(repeatCount: repeatCount);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderRepeatAudio renderObject,
  ) {
    renderObject
      ..repeatCount = repeatCount;
  }
}

class AudioFade extends SingleChildRenderObjectWidget {
  AudioFade({
    super.key,
    super.child,
    this.fadeInDuration = Duration.zero,
    this.fadeOutDuration = Duration.zero,
    this.duration = double.infinity,
  }) : assert(!fadeInDuration.isNegative),
       assert(!fadeOutDuration.isNegative);

  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  final double duration;

  @override
  RenderFadeAudio createRenderObject(BuildContext context) {
    return RenderFadeAudio(
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
      duration: duration,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderFadeAudio renderObject) {
    renderObject
      ..fadeInDuration = fadeInDuration
      ..fadeOutDuration = fadeOutDuration
      ..duration = duration;
  }
}
