import 'dart:typed_data';

import 'package:barsource/src/rendering/object.dart';

/// Tree-based audio contributor for render objects.
///
/// Contributors mix audio from descendant contributors, optionally add their own
/// source audio, then post-process the mixed result. This allows parent render
/// objects to implement audio effects on top of child audio.
mixin AudioContributor on RenderObject {
  /// Returns this node's own source audio for the frame.
  ///
  /// Override for leaf sources (e.g. decoded clip audio). Return `null` when
  /// this node has no source audio at [frameTime].
  Float32List? getOwnAudioForFrame(
    Duration frameTime,
    int sampleCount,
    int sampleRate,
  ) => null;

  /// Applies processing to the mixed subtree audio for this contributor.
  ///
  /// Override to implement effects (gain, filters, etc). The default behavior
  /// returns [mixedSamples] unchanged.
  Float32List processMixedAudioForFrame(
    Duration frameTime,
    int sampleCount,
    int sampleRate,
    Float32List mixedSamples,
  ) => mixedSamples;

  /// Returns this contributor's final audio for the frame.
  ///
  /// This is the subtree mix for this contributor: descendant contributor audio
  /// + own source audio, then [processMixedAudioForFrame].
  Float32List? getAudioForFrame(
    Duration frameTime,
    int sampleCount,
    int sampleRate,
  ) {
    final expectedStereoSamples = sampleCount * 2;
    Float32List? mixedSamples;

    void mixInto(Float32List samples) {
      mixedSamples ??= Float32List(expectedStereoSamples);
      final limit = samples.length < expectedStereoSamples
          ? samples.length
          : expectedStereoSamples;
      for (int i = 0; i < limit; i++) {
        mixedSamples![i] += samples[i];
      }
    }

    void collectDescendantContributorAudio(RenderObject node) {
      node.visitChildren((RenderObject child) {
        if (child is AudioContributor) {
          final childSamples = child.getAudioForFrame(
            frameTime,
            sampleCount,
            sampleRate,
          );
          if (childSamples != null && childSamples.isNotEmpty) {
            mixInto(childSamples);
          }
          return;
        }
        collectDescendantContributorAudio(child);
      });
    }

    collectDescendantContributorAudio(this);
    final ownSamples = getOwnAudioForFrame(frameTime, sampleCount, sampleRate);
    if (ownSamples != null && ownSamples.isNotEmpty) {
      mixInto(ownSamples);
    }
    if (mixedSamples == null) {
      return null;
    }

    return processMixedAudioForFrame(
      frameTime,
      sampleCount,
      sampleRate,
      mixedSamples!,
    );
  }
}
