import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:tennoji/src/engine/bindings.dart';
import 'package:tennoji/src/foundation/binding_base.dart';
import 'package:tennoji/src/scheduler/binding.dart';

export 'bindings.dart';

class Engine extends BindingBase with SchedulerBinding {
  Engine._(this._nativePtr);

  final Pointer<TennojiEngine> _nativePtr;
  static Engine? _instance;

  static void init({
    int width = 1920,
    int height = 1080,
    int fps = 60,
    String gpuBackend = 'vulkan',
  }) {
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
  }

  static Engine get instance => _instance!;

  Pointer<TennojiEngine> get nativePtr => _nativePtr;

  void shutdown() {
    rina_engine_destroy(_nativePtr);
    _instance = null;
  }
}

/// A [Timer] that runs on the [Engine]'s clock.
class EngineTimer implements Timer {
  EngineTimer(Duration duration, void Function() callback) {
    _scheduled = _ScheduledTimer(duration, callback);
    Engine.instance._registerTimer(_scheduled);
  }

  /// Creates a periodic timer.
  EngineTimer.periodic(Duration duration, void Function(Timer) callback) {
    _scheduled = _ScheduledTimer(
      duration,
      () => callback(this),
      isPeriodic: true,
    );
    Engine.instance._registerTimer(_scheduled);
  }

  late final _ScheduledTimer _scheduled;

  @override
  void cancel() {
    Engine.instance._cancelTimer(_scheduled);
  }

  @override
  bool get isActive => Engine.instance._timers.contains(_scheduled);

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

