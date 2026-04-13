import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:barsource/src/dart_ui/dart_ui.dart';
import 'package:barsource/src/engine/bindings.dart';
import 'package:barsource/src/foundation/binding_base.dart';
import 'package:barsource/src/rendering/binding.dart';
import 'package:barsource/src/scheduler/binding.dart';
import 'package:barsource/src/widgets/binding.dart';
import 'package:barsource/src/engine/audio_binding.dart';
import 'package:barsource/src/engine/audio_contributor.dart';
import 'package:logging/logging.dart';
import 'package:barsource/src/widgets/framework.dart';
import 'package:barsource/src/rendering/view.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/scheduler/ticker.dart';

import 'package:console_bars/console_bars.dart';

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
    this.renderResolution,
    this.codec = .h265,
    this.audioCodec = .aac,
    this.logLevel = Level.INFO,
    this.showProgressBar = true,
  });
  final String output;
  final Duration duration;
  final int fps;
  /// Canvas size
  final Size resolution;
  /// The actual video resolution, defaults to [resolution]
  /// Don't use this though, it works but it fucks up rendering for some reason
  final Size? renderResolution;
  final VideoCodec codec;
  final AudioCodec audioCodec;
  final Level logLevel;
  final bool showProgressBar;
}

enum VideoCodec {
  h264,
  h265;
}

enum AudioCodec {
  aac,
  opus;
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

  /// Render the video.
  /// The entire operation is designed to be synchronous. The function was set to async to give room for event queues
  /// (otherwise all of them will run after the loop ends)
  Future<void> run(Widget app, RenderConfig config) async {
    final renderResolution = config.renderResolution ?? config.resolution;
    final frameDuration = Duration(microseconds: 1000000 ~/ config.fps);
    _frameDuration = frameDuration.inMilliseconds;
    _currentTime = Duration.zero;

    _log.info('Starting render run. Resolution: ${config.resolution}, FPS: ${config.fps}, Duration: ${config.duration}');
    // 1. Initialize RenderView
    initRenderView(ViewConfiguration(
      size: renderResolution,
    ));

    // Layers removed - no longer need replaceRootLayer

    // 2. Attach Root Widget
    attachRootWidget(app);

    // 3. Create Encoder
    final encConfig = calloc<TennojiEncoderConfig>();
    final outputPathUtf8 = config.output.toNativeUtf8(allocator: calloc);
    final videoCodecUtf8 = config.codec.name.toNativeUtf8(allocator: calloc);
    final audioCodecUtf8 = config.audioCodec.name.toNativeUtf8(allocator: calloc);
    
    encConfig.ref
      ..output_path = outputPathUtf8.cast()
      ..width = renderResolution.width.toInt()
      ..height = renderResolution.height.toInt()
      ..fps = config.fps
      ..video_codec = videoCodecUtf8.cast()
      ..audio_codec = audioCodecUtf8.cast()
      ..audio_sample_rate = 44100
      ..audio_channels = 2;

    final encoder = rina_encoder_create(_nativePtr, encConfig); 

    final progressBar = FillingBar(
      desc: "r", time: true, percentage: true,
      total:(config.duration.inMilliseconds/1000*config.fps).toInt()
    );

    // This canvas is a special one, and thus does not experience the same lifecycle as every other canvas inside PaintingContext
    final canvas = Canvas(
      renderResolution.width.toInt(),
      renderResolution.height.toInt(),
    );
    renderView.layout(BoxConstraints(
      minWidth: renderResolution.width, minHeight: renderResolution.height,
      maxWidth: renderResolution.width,
      maxHeight: renderResolution.height
    ));
    bool doScale = config.renderResolution != null && config.resolution != config.renderResolution;
    try {
      while (_currentTime < config.duration) {
        if (doScale) {
          final scaleX = config.renderResolution!.width / config.resolution.width;
          final scaleY = config.renderResolution!.height / config.resolution.height;
          canvas.scale(scaleX, scaleY);
        }
        handleBeginFrame(_currentTime);

        // execute microtasks
        await Future.delayed(Duration.zero);
        
        // Update view time
        /*
        renderView.configuration = ViewConfiguration(
          size: renderResolution,
          currentTime: _currentTime,
        );
        */
        
        // Draw frame (Build + Layout)
        _log.fine('Drawing frame at $_currentTime');
        handleDrawFrame();
        
        // Paint phase
        // ignore: invalid_use_of_protected_member
        final nativeCanvas = canvas.nativePtr;
        rina_canvas_draw_color(nativeCanvas, 0xFF000000, BlendMode.dstOver.index);
        
        // Paint directly without layers
        try {
          final context = PaintingContext(canvas, Rect.fromLTWH(0, 0, renderResolution.width, renderResolution.height));
          renderView.paint(context, Offset.zero);
        } catch (e, st) {
          _log.severe('Error during painting at $_currentTime: $e', e, st);
        }

        if (doScale) {
          canvas.restore();
        }
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
        progressBar.increment();
      }
    } on Exception catch (e, st) {
      _log.severe('Error during render run: $e', e, st);
    } finally {
      // this function crashes on literally any exceptions ever
      rina_encoder_finalize(encoder);
      rina_encoder_destroy(encoder);
      
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

