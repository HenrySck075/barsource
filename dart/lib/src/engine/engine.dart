import 'dart:async';
import 'dart:developer';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:isolate' as isolate;

import 'package:ffi/ffi.dart';
import 'package:barsource/src/dart_ui/dart_ui.dart';
import 'package:barsource/src/engine/bindings.dart';
import 'package:barsource/src/foundation/binding_base.dart';
import 'package:barsource/src/rendering/binding.dart';
import 'package:barsource/src/scheduler/binding.dart';
import 'package:barsource/src/widgets/binding.dart';
import 'package:barsource/src/widgets/root.dart';
import 'package:barsource/src/engine/audio_binding.dart';
import 'package:barsource/src/engine/audio_contributor.dart';
import 'package:logging/logging.dart';
import 'package:barsource/src/widgets/framework.dart';
import 'package:barsource/src/rendering/view.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/scheduler/ticker.dart';

import 'package:console_bars/console_bars.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

export 'bindings.dart';
export 'audio_binding.dart';
export 'audio_contributor.dart';
export '../scheduler/ticker.dart';

class RenderConfig {
  const RenderConfig({
    required this.output,
    this.duration,
    required this.fps,
    required this.resolution,
    this.codec = .h265,
    this.audioCodec = .aac,
    this.outputMode = .local,
    this.logLevel = Level.INFO,
    this.showProgressBar = true,
    this.throttleRenderTime = false,
  });
  final String output;
  final Duration? duration;
  final int fps;

  /// Canvas size
  final Size resolution;

  final VideoCodec codec;
  final AudioCodec audioCodec;
  final OutputMode outputMode;
  final Level logLevel;
  final bool showProgressBar;

  final bool throttleRenderTime;
}

enum VideoCodec { h264, h265 }

enum AudioCodec { aac, opus }

enum OutputMode { local, youtubeStream }

class Engine extends BindingBase
    with SchedulerBinding, RendererBinding, WidgetsBinding, AudioBinding {
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
  bool _stopRequested = false;

  /// The duration in milliseconds of 1 single frame.
  ///
  /// This value is only valid when the engine is currently being [run]
  int get frameDuration => _frameDuration!;

  void stopRendering() {
    _stopRequested = true;
  }

  bool _devtoolsEnabled = false;
  VmService? _vmService;

  Completer<void>? _reassembleCompleter;

  // idc
  // runs only if the Engine is rendering and devtools extensions is enabled
  Future<ServiceExtensionResponse> _serviceMethodHandler(String method, Map<String, String> parameters) {
    if (!_rendering || !_devtoolsEnabled) {
      return Future.value(
        ServiceExtensionResponse.error(
          ServiceExtensionResponse.extensionError,
          'Service extension called when not rendering or devtools not enabled',
        ),
      );
    }

    if (method == "ext.barsource.reassemble") {
      // cancel if _reassembleCompleter != null (a reload is happening)
      if (_reassembleCompleter != null) {
        _log.warning("Received reassemble request while another reassemble is in progress, ignoring");
        return Future.value(
          ServiceExtensionResponse.error(
            ServiceExtensionResponse.extensionError,
            'Reassemble already in progress',
          ),
        );
      }
      _log.info("Received reassemble request from DevTools");
      _reassembleCompleter = Completer();
      return _reassembleCompleter!.future.then((_)=>ServiceExtensionResponse.result("{}"));
    }

    return Future.value(
      ServiceExtensionResponse.error(
        ServiceExtensionResponse.invalidParams,
        'Unimplemented service extension method: $method',
      ),
    );
  }


  bool _rendering = false;

  /// Render the video.
  /// The entire operation is designed to be synchronous. The function was set to async to give room for event queues
  /// (otherwise all of them will run after the loop ends)
  Future<void> run(Widget app, RenderConfig config) async {
    final useYouTubeStreaming = config.outputMode == OutputMode.youtubeStream;
    if (!useYouTubeStreaming && config.duration == null) {
      throw ArgumentError(
        'duration is required when outputMode is OutputMode.local',
      );
    }
    _stopRequested = false;
    final renderResolution = config.resolution;
    final renderDuration = config.duration;
    final frameDuration = Duration(microseconds: 1000000 ~/ config.fps);
    _frameDuration = frameDuration.inMilliseconds;
    _currentTime = Duration.zero;
    final durationLabel = renderDuration?.toString() ?? 'streaming (unbounded)';

    _log.info(
      'Starting render run. Resolution: ${config.resolution}, FPS: ${config.fps}, Duration: $durationLabel',
    );
    // 1. Initialize RenderView
    initRenderView(ViewConfiguration(size: renderResolution));

    // Layers removed - no longer need replaceRootLayer

    // 2. Attach Root Widget
    attachRootWidget(RootWidget(child: app, container: renderView));

    // 3. Create Encoder
    final encConfig = calloc<TennojiEncoderConfig>();
    final resolvedVideoCodec = useYouTubeStreaming
        ? VideoCodec.h264
        : config.codec;
    final resolvedAudioCodec = useYouTubeStreaming
        ? AudioCodec.aac
        : config.audioCodec;
    final outputPathUtf8 = config.output.toNativeUtf8(allocator: calloc);
    final videoCodecUtf8 = resolvedVideoCodec.name.toNativeUtf8(
      allocator: calloc,
    );
    final audioCodecUtf8 = resolvedAudioCodec.name.toNativeUtf8(
      allocator: calloc,
    );

    encConfig.ref
      ..output_path = outputPathUtf8.cast()
      ..width = renderResolution.width.toInt()
      ..height = renderResolution.height.toInt()
      ..fps = config.fps
      ..video_codec = videoCodecUtf8.cast()
      ..audio_codec = audioCodecUtf8.cast()
      ..audio_sample_rate = 44100
      ..audio_channels = 2
      ..output_mode = config.outputMode.index;

    final encoder = rina_encoder_create(_nativePtr, encConfig);
    if (encoder == nullptr) {
      calloc.free(outputPathUtf8);
      calloc.free(videoCodecUtf8);
      calloc.free(audioCodecUtf8);
      calloc.free(encConfig);
      throw StateError(
        'Failed to create native encoder for output: ${config.output}',
      );
    }

    final progressBar = (config.showProgressBar && config.outputMode == .local)
        ? FillingBar(
            desc: "r",
            time: true,
            percentage: true,
            total: (renderDuration!.inMilliseconds / 1000 * config.fps).toInt(),
          )
        : null;

    // This canvas is a special one, and thus does not experience the same lifecycle as every other canvas inside PaintingContext
    final canvas = Canvas(
      renderResolution.width.toInt(),
      renderResolution.height.toInt(),
    );
    renderView.layout(
      BoxConstraints(
        minWidth: renderResolution.width,
        minHeight: renderResolution.height,
        maxWidth: renderResolution.width,
        maxHeight: renderResolution.height,
      ),
    );
    const sampleRate = 44100;
    final samplesPerFrame = (sampleRate / config.fps).round();
    final expectedStereoSamples = samplesPerFrame * 2;
    final sampleBuffer = calloc<Float>(expectedStereoSamples);
    final sampleBufferView = sampleBuffer.asTypedList(expectedStereoSamples);
    final mixedAudioBuffer = Float32List(expectedStereoSamples);
    final streamWallClock = (useYouTubeStreaming || config.throttleRenderTime)
        ? (Stopwatch()..start())
        : null;
    String? exitReason;

    _devtoolsEnabled = useYouTubeStreaming;
    if (_devtoolsEnabled) {
      // try to connect to the vm service
      final info = await Service.getInfo();
      final url = info.serverWebSocketUri;

      if (url != null) {
        _vmService = await vmServiceConnectUri(url.toString());
      } else {
        _devtoolsEnabled = false;
      }
    }
    if (_devtoolsEnabled) {
      registerExtension("ext.barsource.reassemble", _serviceMethodHandler);
    }
    _rendering = true;
    try {
      while (!_stopRequested &&
          (useYouTubeStreaming || _currentTime < renderDuration!)) {
        handleBeginFrame(_currentTime);

        // Trigger microtasks / futures
        // no, really, this is how you do it
        await Future(() {});

        // Draw frame (Build + Layout)
        _log.fine('Drawing frame at $_currentTime');
        handleDrawFrame();

        // Paint phase
        // ignore: invalid_use_of_protected_member
        final nativeCanvas = canvas.nativePtr;
        rina_canvas_draw_color(
          nativeCanvas,
          0xFF000000,
          BlendMode.dstOver.index,
        );

        // Paint directly without layers
        try {
          final context = PaintingContext(
            canvas,
            Rect.fromLTWH(
              0,
              0,
              renderResolution.width,
              renderResolution.height,
            ),
          );
          renderView.paint(context, Offset.zero);
        } catch (e, st) {
          _log.severe('Error during painting at $_currentTime: $e', e, st);
          _log.severe(st);
          exitReason = 'paint failed at $_currentTime';
          break;
        }

        // Encode video
        final videoWriteResult = rina_encoder_write_frame(
          encoder,
          nativeCanvas,
        );
        if (videoWriteResult < 0) {
          exitReason =
              'native video write failed (code=$videoWriteResult) at $_currentTime';
          break;
        }

        // NEW Audio Submission System: ALWAYS write audio for every video frame
        // to maintain sync (even if it's silence)
        mixedAudioBuffer.fillRange(0, expectedStereoSamples, 0.0);
        bool hasAudio = false;
        bool hasInvalidSamples = false;

        _visitRootAudioContributors((AudioContributor contributor) {
          final samples = contributor.getAudioForFrame(
            _currentTime,
            samplesPerFrame,
            sampleRate,
          );
          if (samples != null && samples.isNotEmpty) {
            hasAudio = true;
            final limit = samples.length < expectedStereoSamples
                ? samples.length
                : expectedStereoSamples;
            for (int i = 0; i < limit; i++) {
              final sample = samples[i];
              if (sample.isFinite) {
                mixedAudioBuffer[i] += sample;
              } else {
                hasInvalidSamples = true;
              }
            }
          }
        });

        // Clamp and write directly into the FFI buffer.
        for (int i = 0; i < expectedStereoSamples; i++) {
          final mixed = hasAudio ? mixedAudioBuffer[i] : 0.0;
          if (!mixed.isFinite) {
            hasInvalidSamples = true;
            sampleBufferView[i] = 0.0;
            continue;
          }
          if (mixed > 1.0) {
            sampleBufferView[i] = 1.0;
          } else if (mixed < -1.0) {
            sampleBufferView[i] = -1.0;
          } else {
            sampleBufferView[i] = mixed;
          }
        }

        if (hasInvalidSamples) {
          _log.warning(
            'Invalid audio samples detected at $_currentTime, replaced with silence',
          );
        }

        final audioWriteResult = rina_encoder_write_audio_samples(
          encoder,
          sampleBuffer,
          samplesPerFrame, // Always write the expected frame size
          sampleRate,
          2, // stereo
        );
        if (audioWriteResult < 0) {
          exitReason =
              'native audio write failed (code=$audioWriteResult) at $_currentTime';
          break;
        }

        // reassemble
        if (_reassembleCompleter != null) {
          _log.info("Performing hot reload reassemble");
          final isolateId = Service.getIsolateId(isolate.Isolate.current)!;
          await _vmService!.reloadSources(isolateId);
          reassembleApplication();
          _reassembleCompleter!.complete();
          _reassembleCompleter = null;
        }

        _currentTime += frameDuration;
        progressBar?.increment();
        if (streamWallClock != null) {
          final behindBy = _currentTime - streamWallClock.elapsed;
          if (behindBy > Duration.zero) {
            await Future.delayed(behindBy);
          }
        }
      }
      if (exitReason == null) {
        if (_stopRequested) {
          exitReason = 'stop requested';
        } else if (!useYouTubeStreaming) {
          exitReason = 'duration reached';
        } else {
          exitReason = 'stream loop ended';
        }
      }
      _log.info('Render loop exit reason: $exitReason');
    } catch (e, st) {
      print('Error during render run: $e\n$st');
    } finally {
      // this function crashes on literally any exceptions ever
      rina_encoder_finalize(encoder);
      rina_encoder_destroy(encoder);

      calloc.free(outputPathUtf8);
      calloc.free(videoCodecUtf8);
      calloc.free(audioCodecUtf8);
      calloc.free(encConfig);
      calloc.free(sampleBuffer);

      detachRootWidget();
      _log.info('Render run completed.');
      _frameDuration = null;
      _rendering = false;
    }
  }

  void _visitRootAudioContributors(void Function(AudioContributor) visitor) {
    void walk(RenderObject node, {required bool hasContributorAncestor}) {
      final isContributor = node is AudioContributor;
      if (isContributor && !hasContributorAncestor) {
        visitor(node);
      }
      final nextHasContributorAncestor =
          hasContributorAncestor || isContributor;
      node.visitChildren((RenderObject child) {
        walk(child, hasContributorAncestor: nextHasContributorAncestor);
      });
    }

    walk(renderView, hasContributorAncestor: false);
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
