import 'dart:ffi';
import 'package:tennoji/src/engine/bindings.dart';
import 'package:tennoji/src/foundation/binding_base.dart';

mixin AudioBinding on BindingBase {
  final Map<Pointer<TennojiDecoder>, bool> _audioDecoders = {};

  void registerAudioDecoder(Pointer<TennojiDecoder> decoder, {bool needsManualRead = false}) {
    _audioDecoders[decoder] = needsManualRead;
  }

  void unregisterAudioDecoder(Pointer<TennojiDecoder> decoder) {
    _audioDecoders.remove(decoder);
  }

  Iterable<Pointer<TennojiDecoder>> get allAudioDecoders => _audioDecoders.keys;
  
  Iterable<Pointer<TennojiDecoder>> get manualReadAudioDecoders => 
      _audioDecoders.entries.where((e) => e.value).map((e) => e.key);
}
