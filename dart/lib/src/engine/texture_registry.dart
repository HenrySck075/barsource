import 'engine.dart';

/// Manages GPU texture handles allocated by the native engine.
class TextureRegistry {
  final Map<int, int> _textures = {}; // id -> native handle

  int register(int nativeHandle) {
    final id = _textures.length;
    _textures[id] = nativeHandle;
    return id;
  }

  int? lookup(int id) => _textures[id];

  void release(int id) {
    final handle = _textures.remove(id);
    if (handle != null) {
      bindings.texture_release(Engine.instance.nativePtr, handle);
    }
  }

  void releaseAll() {
    for (final id in _textures.keys.toList()) {
      release(id);
    }
  }
}
