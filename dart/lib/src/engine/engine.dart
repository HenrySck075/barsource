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

    final ptr = tennoji_engine_create(config);
    calloc.free(gpuBackendUtf8);
    calloc.free(config);
    _instance = Engine._(ptr);
  }

  static Engine get instance => _instance!;

  Pointer<TennojiEngine> get nativePtr => _nativePtr;

  void shutdown() {
    tennoji_engine_destroy(_nativePtr);
    _instance = null;
  }
}
