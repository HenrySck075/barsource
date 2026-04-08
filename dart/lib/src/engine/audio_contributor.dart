import 'dart:collection';
import 'dart:typed_data';

/// Interface for RenderObjects that contribute audio to the mix.
/// 
/// Objects implementing this interface can provide audio samples for each frame,
/// allowing the engine to collect and mix audio from multiple sources.
/// This enables proper audio synchronization with variable playback speeds,
/// reverse playback, and per-clip audio processing.
abstract class AudioContributor {
  /// Returns audio samples for the given frame time.
  /// 
  /// Returns `null` if no audio is available for this frame (e.g., the clip
  /// hasn't started yet, has ended, or is trimmed at this time).
  /// 
  /// Parameters:
  /// - [frameTime]: Current engine time for this frame
  /// - [sampleCount]: Number of samples requested per channel (stereo = 2 channels)
  /// - [sampleRate]: Sample rate in Hz (typically 44100 or 48000)
  /// 
  /// Returns interleaved stereo float32 samples in range [-1.0, 1.0].
  /// For stereo, samples are interleaved: [L, R, L, R, L, R, ...]
  /// Buffer length should be `sampleCount * 2` (stereo channels).
  /// 
  /// Example:
  /// ```dart
  /// // For 735 samples at 44100 Hz (one frame at 60 FPS):
  /// final samples = getAudioForFrame(currentTime, 735, 44100);
  /// // samples.length == 1470 (735 samples × 2 channels)
  /// ```
  Float32List? getAudioForFrame(
    Duration frameTime,
    int sampleCount,
    int sampleRate,
  );
}


final class AudioContributorEntry extends LinkedListEntry<AudioContributorEntry> {
  AudioContributor theActualValue;
  AudioContributorEntry(this.theActualValue);

  @override
  String toString() => theActualValue.toString();
}
