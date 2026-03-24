import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:tennoji/src/engine/bindings.dart';

export 'bindings.dart';

class Engine {
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

  // Internal class for timer scheduling
}

class _ScheduledTimer {
  _ScheduledTimer(this.duration, this.callback, {this.isPeriodic = false});
  final Duration duration;
  final void Function() callback;
  final bool isPeriodic;
  
  late Duration targetTime;
  Duration? lastFireTime;
}

// Re-open Engine class to close it properly since I messed up the edit block structure slightly in thought
// Wait, I inserted inside Engine class but left the closing brace of Engine in the old_str.
// The new_str ends with "}", so the class is closed.
// But I added _ScheduledTimer outside.
// I need to be careful with the brace matching.
// The old_str ends with `shutdown() { ... }` then `}`.
// My new_str ends with `shutdown() {` (opening of shutdown).
// I removed the body of shutdown and the closing brace of class.
// Let me correct the edit.


  static Engine get instance => _instance!;

  Pointer<TennojiEngine> get nativePtr => _nativePtr;

  Duration _currentTime = Duration.zero;
  Duration get currentTime => _currentTime;

  final List<_ScheduledTimer> _timers = [];

  void updateTime(Duration time) {
    _currentTime = time;
    
    // Process timers
    _timers.removeWhere((timer) {
      if (timer.targetTime <= time) {
        timer.callback();
        return !timer.isPeriodic; // Remove if not periodic
      }
      return false;
    });

    // Reschedule periodic timers
    // (Simpler implementation: just let them re-add themselves or handle periodic logic here)
    // Actually, standard Timer.periodic re-schedules.
    // For this engine-bound timer, we can just keep it in the list if it's periodic, 
    // but update its targetTime.
    
    for (final timer in _timers) {
        if (timer.isPeriodic && timer.lastFireTime != null && time >= timer.targetTime) {
             // It fired in the removeWhere block above, now update target
             timer.lastFireTime = time;
             timer.targetTime = time + timer.duration;
        }
    }
  }

  void _registerTimer(_ScheduledTimer timer) {
    timer.targetTime = _currentTime + timer.duration;
    _timers.add(timer);
    _timers.sort((a, b) => a.targetTime.compareTo(b.targetTime));
  }
  
  void _cancelTimer(_ScheduledTimer timer) {
    _timers.remove(timer);
  }

  void shutdown() {
    rina_engine_destroy(_nativePtr);
    _instance = null;
  }
}
