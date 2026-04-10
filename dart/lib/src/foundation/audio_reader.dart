import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../engine/engine.dart';

/// Handles reading audio samples from a decoder with trim bounds and volume control.
class AudioReader {
  AudioReader({
    required this.source,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.volume = 1.0,
  });

  final String source;
  final Duration trimStart;
  final Duration? trimEnd;
  final double volume;

  Pointer<TennojiDecoder>? _decoder;

  Pointer<TennojiDecoder>? get decoder => _decoder;

  /// Opens the decoder for the audio source.
  void open() {
    final uri = source.toNativeUtf8(allocator: calloc);
    _decoder = rina_decoder_open(
      Engine.instance.nativePtr,
      uri.cast(),
      TennojiHWAccel.TENNOJI_HW_ACCEL_AUTO,
    );
    calloc.free(uri);
  }

  /// Closes and releases the decoder.
  void close() {
    if (_decoder != null) {
      rina_decoder_close(_decoder!);
      _decoder = null;
    }
  }

  /// Reads audio samples for the given frame time.
  ///
  /// Returns null if:
  /// - decoder is not available
  /// - frame time is outside trim bounds
  /// - no audio samples were read
  Float32List? readSamples({
    required Duration frameTime,
    required int sampleCount,
    required int sampleRate,
  }) {
    if (decoder == null) return null;

    final clipTime = frameTime - trimStart;

    // Check if we're within the clip bounds
    if (clipTime < Duration.zero) return null;
    if (trimEnd != null && clipTime > trimEnd!) return null;

    final timeUs = clipTime.inMicroseconds;

    // Allocate buffer for interleaved stereo samples
    final sampleBufferSize = sampleCount * 2; // stereo
    final sampleBuffer = calloc<Float>(sampleBufferSize);

    try {
      final samplesRead = rina_decoder_read_audio_samples(
        decoder!,
        timeUs,
        sampleBuffer,
        sampleCount,
        sampleRate,
      );

      if (samplesRead <= 0) {
        return null;
      }

      // Copy to Float32List and apply volume
      final result = Float32List(samplesRead * 2);
      for (int i = 0; i < samplesRead * 2; i++) {
        result[i] = sampleBuffer[i] * volume;
      }

      return result;
    } finally {
      calloc.free(sampleBuffer);
    }
  }
}
