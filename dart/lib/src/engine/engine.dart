import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:tennoji/src/dart_ui/dart_ui.dart';
import 'package:tennoji/src/engine/bindings.dart';
import 'package:tennoji/src/foundation/binding_base.dart';
import 'package:tennoji/src/rendering/binding.dart';
import 'package:tennoji/src/scheduler/binding.dart';
import 'package:tennoji/src/widgets/binding.dart';
import 'package:tennoji/src/engine/audio_binding.dart';
import 'package:tennoji/src/engine/audio_contributor.dart';
import 'package:logging/logging.dart';
import 'package:tennoji/src/widgets/framework.dart';
import 'package:tennoji/src/rendering/view.dart';
import 'package:tennoji/src/rendering/object.dart';
import 'package:tennoji/src/scheduler/ticker.dart';

export 'bindings.dart';
export 'audio_binding.dart';
export 'audio_contributor.dart';
export '../scheduler/ticker.dart';

class RenderConfig {
  const RenderConfig({
    required this.output,
    required this.duration,
    required this.fps,
    required this.resolution,
    this.codec = const VideoCodec.h264(),
    this.audioCodec = const AudioCodec.aac(),
    this.logLevel = Level.INFO,
  });
  final String output;
  final Duration duration;
  final int fps;
  final Size resolution;
  final VideoCodec codec;
  final AudioCodec audioCodec;
  final Level logLevel;
}

class VideoCodec {
  const VideoCodec.h264() : name = 'h264';
  const VideoCodec.h265() : name = 'h265';
  final String name;
}

class AudioCodec {
  const AudioCodec.aac() : name = 'aac';
  const AudioCodec.opus() : name = 'opus';
  final String name;
}

class Engine extends BindingBase with SchedulerBinding, RendererBinding, WidgetsBinding, AudioBinding {
  Engine._(this._nativePtr);

  final Pointer<TennojiEngine> _nativePtr;
  static Engine? _instance;
  final _log = Logger('Engine');

  // Timers rely on Ticker via SchedulerBinding
  Duration _currentTime = Duration.zero;

  Duration get currentTime => _currentTime;

  static void init({
    int width = 1920,
    int height = 1080,
    int fps = 60,
    String gpuBackend = 'vulkan',
  }) {
    if (_instance != null) return;
    
    final config = calloc<TennojiEngineConfig>();
    final gpuBackendUtf8 = gpuBackend.toNativeUtf8(allocator: calloc);
    config.ref
      ..width = width
      ..height = height
      ..fps = fps
      ..gpu_backend = gpuBackendUtf8.cast();

    final ptr = rina_engine_create(config);
    calloc.free(gpuBackendUtf8);
    calloc.free(config);
    _instance = Engine._(ptr);
    _instance!.initInstances();
  }

  static Engine get instance => _instance!;

  Pointer<TennojiEngine> get nativePtr => _nativePtr;

  void shutdown() {
    rina_engine_destroy(_nativePtr);
    _instance = null;
  }

  int? _frameDuration;
  /// The duration in milliseconds of 1 single frame.
  ///
  /// This value is only valid when the engine is currently being [run]
  int get frameDuration => _frameDuration!;

  void run(Widget app, RenderConfig config) {
    final frameDuration = Duration(microseconds: 1000000 ~/ config.fps);
    _frameDuration = frameDuration.inMilliseconds;
    _currentTime = Duration.zero;

    _log.info('Starting render run. Resolution: ${config.resolution}, FPS: ${config.fps}, Duration: ${config.duration}');
    // 1. Initialize RenderView
    initRenderView(ViewConfiguration(
      size: config.resolution,
      currentTime: Duration.zero,
    ));

    // 2. Attach Root Widget
    attachRootWidget(app);

    // 3. Create Encoder
    final encConfig = calloc<TennojiEncoderConfig>();
    final outputPathUtf8 = config.output.toNativeUtf8(allocator: calloc);
    final videoCodecUtf8 = config.codec.name.toNativeUtf8(allocator: calloc);
    final audioCodecUtf8 = config.audioCodec.name.toNativeUtf8(allocator: calloc);
    
    encConfig.ref
      ..output_path = outputPathUtf8.cast()
      ..width = config.resolution.width.toInt()
      ..height = config.resolution.height.toInt()
      ..fps = config.fps
      ..video_codec = videoCodecUtf8.cast()
      ..audio_codec = audioCodecUtf8.cast()
      ..audio_sample_rate = 44100
      ..audio_channels = 2;

    final encoder = rina_encoder_create(_nativePtr, encConfig);
    
    // 4. Create Canvas
    final nativeCanvas = rina_canvas_create(
      _nativePtr,
      config.resolution.width.toInt(),
      config.resolution.height.toInt(),
    );

    try {
      while (_currentTime < config.duration) {
        handleBeginFrame(_currentTime);
        
        // Update view time
        renderView.configuration = ViewConfiguration(
          size: config.resolution,
          currentTime: _currentTime,
        );
        
        // Draw frame (Build + Layout)
        _log.fine('Drawing frame at $_currentTime');
        drawFrame();
        
        // Paint phase
        rina_canvas_draw_color(nativeCanvas, 0xFF000000, BlendMode.dstOver.index);
        final canvas = Canvas(nativeCanvas);
        pipelineOwner.flushPaint(canvas);
        renderView.paint(PaintingContext(canvas), Offset.zero);

        // Encode video
        rina_encoder_write_frame(encoder, nativeCanvas);

        // NEW Audio Submission System: ALWAYS write audio for every video frame
        // to maintain sync (even if it's silence)
        const sampleRate = 44100;
        final samplesPerFrame = (sampleRate / config.fps).round();
        
        final audioBuffers = <Float32List>[];
        
        for (final contributor in _contributors) {
          final samples = contributor.theActualValue.getAudioForFrame(
            _currentTime,
            samplesPerFrame,
            sampleRate,
          );
          if (samples != null && samples.isNotEmpty) {
            audioBuffers.add(samples);
          }
        }
        
        Float32List audioToWrite;
        if (audioBuffers.isNotEmpty) {
          audioToWrite = _mixAudioSamples(audioBuffers);
        } else {
          // No audio available - write silence to maintain sync
          audioToWrite = Float32List(samplesPerFrame * 2); // stereo, initialized to 0
        }
        
        // Ensure we always have exactly the right number of samples for this frame
        // Pad with silence if needed to maintain perfect A/V sync
        if (audioToWrite.length < samplesPerFrame * 2) {
          final padded = Float32List(samplesPerFrame * 2);
          for (int i = 0; i < audioToWrite.length; i++) {
            padded[i] = audioToWrite[i];
          }
          // Rest is already zero-initialized
          audioToWrite = padded;
        } else if (audioToWrite.length > samplesPerFrame * 2) {
          // Truncate if somehow we got too many samples
          audioToWrite = Float32List.sublistView(audioToWrite, 0, samplesPerFrame * 2);
        }
        
        // Validate no NaN/Inf values
        bool hasInvalidSamples = false;
        for (int i = 0; i < audioToWrite.length; i++) {
          if (!audioToWrite[i].isFinite) {
            hasInvalidSamples = true;
            audioToWrite[i] = 0.0; // Replace with silence
          }
        }
        
        if (hasInvalidSamples) {
          _log.warning('Invalid audio samples detected at $_currentTime, replaced with silence');
        }
        
        // Write audio to encoder
        final sampleBuffer = calloc<Float>(audioToWrite.length);
        try {
          for (int i = 0; i < audioToWrite.length; i++) {
            sampleBuffer[i] = audioToWrite[i];
          }
          
          rina_encoder_write_audio_samples(
            encoder,
            sampleBuffer,
            samplesPerFrame,  // Always write the expected frame size
            sampleRate,
            2, // stereo
          );
        } finally {
          calloc.free(sampleBuffer);
        }

        _currentTime += frameDuration;
      }
    } finally {
      rina_encoder_finalize(encoder);
      rina_encoder_destroy(encoder);
      rina_canvas_destroy(nativeCanvas);
      
      calloc.free(outputPathUtf8);
      calloc.free(videoCodecUtf8);
      calloc.free(audioCodecUtf8);
      calloc.free(encConfig);
      
      detachRootWidget();
      _log.info('Render run completed.');
      _frameDuration = null;
    }
  }

  final LinkedList<AudioContributorEntry> _contributors = LinkedList();
  void registerAudioContributor(AudioContributor contributor) {
    _contributors.add(AudioContributorEntry(contributor));
  }
  void unregisterAudioContributor(AudioContributor contributor) {
    for (final entry in _contributors) {
      if (entry.theActualValue == contributor) {
        entry.unlink();
        break;
      }
    }
  }

  /// Mixes multiple audio buffers into one
  Float32List _mixAudioSamples(List<Float32List> buffers) {
    if (buffers.isEmpty) return Float32List(0);
    if (buffers.length == 1) return buffers[0];
    
    final result = Float32List(buffers[0].length);
    for (int i = 0; i < result.length; i++) {
      double sum = 0.0;
      for (var buffer in buffers) {
        if (i < buffer.length) {
          sum += buffer[i];
        }
      }
      // Clamp to prevent clipping
      result[i] = sum.clamp(-1.0, 1.0);
    }
    return result;
  }
}

/// A [Timer] that runs on the [Engine]'s clock via [Ticker].
class EngineTimer implements Timer {
  EngineTimer(Duration duration, void Function() callback) {
    _duration = duration;
    _callback = callback;
    _startTicker();
  }

  /// Creates a periodic timer.
  EngineTimer.periodic(Duration duration, void Function(Timer) callback) {
    _duration = duration;
    _callback = () => callback(this);
    _isPeriodic = true;
    _startTicker();
  }

  late final Duration _duration;
  late final void Function() _callback;
  bool _isPeriodic = false;
  Ticker? _ticker;
  Duration _accumulated = Duration.zero;

  void _startTicker() {
    _ticker = Ticker(_handleTick);
    _ticker!.start();
  }

  void _handleTick(Duration elapsed) {    
    if (elapsed >= _accumulated + _duration) {
      _callback();
      if (_isPeriodic) {
        _accumulated += _duration;
        // Catch up if multiple durations passed in one frame?
        // user input: no.
        while (elapsed >= _accumulated + _duration) {
          _callback();
          _accumulated += _duration;
        }
      } else {
        cancel();
      }
    }
  }

  @override
  void cancel() {
    _ticker?.stop();
    _ticker = null;
  }

  @override
  bool get isActive => _ticker?.isTicking ?? false;

  @override
  int get tick => 0; // Not fully implemented
}

/// A [Stopwatch] that runs on the [Engine]'s clock.
class EngineStopwatch implements Stopwatch {
  EngineStopwatch();

  Duration _elapsed = Duration.zero;
  Duration? _startTime;
  bool _isRunning = false;

  @override
  int get frequency => 1000000; // microseconds

  @override
  bool get isRunning => _isRunning;

  @override
  void start() {
    if (!_isRunning) {
      _startTime = Engine.instance.currentTime;
      _isRunning = true;
    }
  }

  @override
  void stop() {
    if (_isRunning) {
      _elapsed += Engine.instance.currentTime - _startTime!;
      _startTime = null;
      _isRunning = false;
    }
  }

  @override
  void reset() {
    _elapsed = Duration.zero;
    if (_isRunning) {
      _startTime = Engine.instance.currentTime;
    } else {
      _startTime = null;
    }
  }

  @override
  Duration get elapsed {
    if (_isRunning) {
      return _elapsed + (Engine.instance.currentTime - _startTime!);
    }
    return _elapsed;
  }

  @override
  int get elapsedMicroseconds => elapsed.inMicroseconds;

  @override
  int get elapsedMilliseconds => elapsed.inMilliseconds;

  @override
  int get elapsedTicks => elapsedMicroseconds;
}

