import 'package:barsource/src/foundation/listenable.dart';

import 'framework.dart';
import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:barsource/src/dart_ui/dart_ui.dart';
import 'package:barsource/src/rendering/box.dart';

import '../engine/engine.dart';
import 'package:barsource/src/rendering/object.dart';

// ---------------------------------------------------------------------------
// Media Controller
// ---------------------------------------------------------------------------

class MediaController extends ChangeNotifier {
  MediaController({
    required this.source,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.playbackSpeed = 1.0,
    this.volume = 1.0,
    this.repeatCount,
  }) : assert(repeatCount == null || repeatCount > 0),
       assert(volume >= 0.0 && volume <= 1.0) {
    _ticker = Ticker(_onTick);
    _currentPosition = trimStart;
  }

  final String source;
  Duration trimStart;
  Duration? trimEnd;
  double playbackSpeed;
  double volume;
  int? repeatCount;

  final _log = Logger('MediaController');

  // Playback State
  late final Ticker _ticker;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration? _lastTick;
  int _currentLoops = 0;

  // FFI State
  Pointer<TennojiDecoder>? _decoder;
  bool _isInitialized = false;
  int? _sourceDurationUs;
  bool _sourceDurationResolved = false;

  // Audio Buffers
  Pointer<Float>? _audioSampleBuffer;
  int _audioSampleBufferCapacity = 0;
  Float32List? _audioOutputBuffer;

  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Pointer<TennojiDecoder>? get decoderPtr => _decoder;

  void initialize() {
    if (_isInitialized) return;
    
    final uri = source.toNativeUtf8(allocator: calloc);
    _decoder = rina_decoder_open(
      Engine.instance.nativePtr,
      uri.cast(),
      TennojiHWAccel.TENNOJI_HW_ACCEL_AUTO,
    );
    calloc.free(uri);

    if (_decoder != null) {
      final durationUs = rina_decoder_duration(_decoder!);
      if (durationUs > 0) {
        _sourceDurationUs = durationUs;
        _sourceDurationResolved = true;
      }
    }
    _isInitialized = true;
  }

  int? get sourceDurationUs {
    if (_sourceDurationResolved) return _sourceDurationUs;

    final uri = source.toNativeUtf8(allocator: calloc);
    final durationUs = rina_media_source_duration(
      Engine.instance.nativePtr,
      uri.cast(),
    );
    calloc.free(uri);
    
    _sourceDurationResolved = true;
    if (durationUs > 0) {
      _sourceDurationUs = durationUs;
      return durationUs;
    }
    return null;
  }

  // --- Playback Controls ---

  void play() {
    if (_isPlaying) return;
    initialize();
    _isPlaying = true;
    _lastTick = null; // Reset tick delta
    _ticker.start();
    notifyListeners();
  }

  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _ticker.stop();
    notifyListeners();
  }

  void seekTo(Duration position) {
    // Clamp to bounds
    int posUs = position.inMicroseconds;
    final startUs = trimStart.inMicroseconds;
    final endUs = trimEnd?.inMicroseconds ?? sourceDurationUs ?? posUs;
    
    posUs = math.max(startUs, math.min(posUs, endUs));
    _currentPosition = Duration(microseconds: posUs);
    notifyListeners(); // Force a frame update immediately
  }

  // --- Ticker (Advances Time Before Paint) ---

  void _onTick(Duration elapsed) {
    if (!_isPlaying) return;

    if (_lastTick == null) {
      _lastTick = elapsed;
      return;
    }

    final deltaUs = (elapsed.inMicroseconds - _lastTick!.inMicroseconds) * playbackSpeed;
    _lastTick = elapsed;

    int nextPositionUs = _currentPosition.inMicroseconds + deltaUs.round();
    
    final startUs = trimStart.inMicroseconds;
    final endUs = trimEnd?.inMicroseconds ?? sourceDurationUs;

    // Boundary & Loop Checking
    if (endUs != null && nextPositionUs >= endUs) {
      if (repeatCount != null && _currentLoops >= repeatCount! - 1) {
        // Finished final loop
        nextPositionUs = endUs;
        _currentPosition = Duration(microseconds: nextPositionUs);
        pause(); 
        return;
      } else {
        // Loop back
        _currentLoops++;
        nextPositionUs = startUs + (nextPositionUs - endUs);
      }
    }

    _currentPosition = Duration(microseconds: nextPositionUs);
    notifyListeners(); // Signals RenderObject to paint
  }

  // --- FFI Interop Wrappers ---

  Pointer<TennojiCanvasImage>? getCurrentTexture() {
    if (_decoder == null) return null;
    _log.fine(_currentPosition);
    return rina_decoder_get_texture(_decoder!, _currentPosition.inMicroseconds);
  }

  Float32List? getAudioSamples(int sampleCount, int sampleRate) {
    if (_decoder == null || !_isPlaying) return null;

    final adjustedSampleCount = (sampleCount * playbackSpeed).round();
    final timeUs = _currentPosition.inMicroseconds;
    
    final outputBufferSize = sampleCount * 2; // Stereo
    final nativeBufferSize = adjustedSampleCount * 2;
    
    _ensureAudioBuffers(nativeBufferFloats: nativeBufferSize, outputBufferFloats: outputBufferSize);

    final samplesRead = rina_decoder_read_audio_samples(
      _decoder!,
      timeUs,
      _audioSampleBuffer!,
      adjustedSampleCount,
      sampleRate,
    );

    if (samplesRead <= 0) return null;

    final output = _audioOutputBuffer!;
    final copiedFloats = math.min(samplesRead * 2, outputBufferSize);
    final inputView = _audioSampleBuffer!.asTypedList(copiedFloats);
    
    // Apply Volume
    if (volume <= 0.0) {
      output.fillRange(0, copiedFloats, 0.0);
    } else if (volume >= 1.0) {
      output.setRange(0, copiedFloats, inputView);
    } else {
      for (int i = 0; i < copiedFloats; i++) {
        output[i] = inputView[i] * volume;
      }
    }

    if (copiedFloats < outputBufferSize) {
      output.fillRange(copiedFloats, outputBufferSize, 0.0);
    }
    
    return output;
  }

  void _ensureAudioBuffers({required int nativeBufferFloats, required int outputBufferFloats}) {
    if (_audioSampleBufferCapacity < nativeBufferFloats) {
      if (_audioSampleBuffer != null) calloc.free(_audioSampleBuffer!);
      _audioSampleBuffer = calloc<Float>(nativeBufferFloats);
      _audioSampleBufferCapacity = nativeBufferFloats;
    }
    if (_audioOutputBuffer == null || _audioOutputBuffer!.length != outputBufferFloats) {
      _audioOutputBuffer = Float32List(outputBufferFloats);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (_decoder != null) {
      rina_decoder_close(_decoder!);
      _decoder = null;
    }
    if (_audioSampleBuffer != null) {
      calloc.free(_audioSampleBuffer!);
      _audioSampleBuffer = null;
    }
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Unified Widget
// ---------------------------------------------------------------------------

class MediaClip extends LeafRenderObjectWidget {
  const MediaClip({
    super.key,
    required this.controller,
  });

  final MediaController controller;

  @override
  RenderMediaClip createRenderObject(BuildContext context) => RenderMediaClip(
    controller: controller,
  );

  @override
  void updateRenderObject(BuildContext context, RenderMediaClip renderObject) {
    renderObject.controller = controller;
  }
}

// ---------------------------------------------------------------------------
// Unified Render Object (Dumb Pipe)
// ---------------------------------------------------------------------------

class RenderMediaClip extends RenderBox with AudioContributor {
  RenderMediaClip({
    required this._controller,
  });

  MediaController _controller;
  MediaController get controller => _controller;
  
  set controller(MediaController value) {
    if (_controller == value) return;
    if (attached) _controller.removeListener(markNeedsPaint);
    _controller = value;
    if (attached) _controller.addListener(markNeedsPaint);
    markNeedsLayout();
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.initialize();
    _controller.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _controller.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    size = Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final texture = _controller.getCurrentTexture();
    if (texture != null && texture != nullptr) {
      context.canvas.drawImageNative(texture, offset, Paint());
    }
  }

  @override
  Float32List? getOwnAudioForFrame(
    Duration frameTime,
    int sampleCount,
    int sampleRate,
  ) {
    // The engine's frameTime isn't needed for playback sync anymore, 
    // because the Controller's Ticker manages exact playback position.
    return _controller.getAudioSamples(sampleCount, sampleRate);
  }
}
