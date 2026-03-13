import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

DynamicLibrary _openBindings2(String libname) {
  final uri = Uri.parse('package:tennoji/blob/$libname');
  final resolved = Isolate.resolvePackageUriSync(uri);
  if (resolved == null) {
    throw Exception('Failed to resolve bindings library path for $libname');
  }
  return DynamicLibrary.open(resolved.toFilePath());
}

TennojiBindings _openBindings() {
  if (Platform.isLinux) return TennojiBindings(_openBindings2('libtennoji.so'));
  if (Platform.isMacOS) return TennojiBindings(_openBindings2('libtennoji.dylib'));
  if (Platform.isWindows) return TennojiBindings(_openBindings2('tennoji.dll'));
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

TennojiBindings? _bindingsInstance;

/// Global accessor for the initialized [TennojiBindings] singleton.
/// Call [Engine.init] before using this.
TennojiBindings get bindings => _bindingsInstance!;

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
    _bindingsInstance ??= _openBindings();
    final config = calloc<TennojiEngineConfig>();
    final gpuBackendUtf8 = gpuBackend.toNativeUtf8(allocator: calloc);
    config.ref
      ..width = width
      ..height = height
      ..fps = fps
      ..gpu_backend = gpuBackendUtf8.cast();

    final ptr = bindings.engine_create(config);
    calloc.free(gpuBackendUtf8);
    calloc.free(config);
    _instance = Engine._(ptr);
  }

  static Engine get instance => _instance!;

  Pointer<TennojiEngine> get nativePtr => _nativePtr;

  void shutdown() {
    bindings.engine_destroy(_nativePtr);
    _instance = null;
  }
}
