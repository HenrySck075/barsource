import 'dart:ffi';
import 'package:barsource/src/engine/bindings.dart';
import 'package:barsource/src/foundation/binding_base.dart';

/// @deprecated Legacy audio binding for packet-based audio system.
/// 
/// This mixin is no longer used in the new AudioContributor submission system.
/// Audio is now collected directly from RenderObjects implementing AudioContributor.
/// This mixin is kept for backwards compatibility but will be removed in a future version.
@Deprecated('Use AudioContributor interface instead')
mixin AudioBinding on BindingBase {
  final Map<Pointer<TennojiDecoder>, bool> _audioDecoders = {};

  @Deprecated('No longer needed with AudioContributor system')
  void registerAudioDecoder(Pointer<TennojiDecoder> decoder, {bool needsManualRead = false}) {
    _audioDecoders[decoder] = needsManualRead;
  }

  @Deprecated('No longer needed with AudioContributor system')
  void unregisterAudioDecoder(Pointer<TennojiDecoder> decoder) {
    _audioDecoders.remove(decoder);
  }

  @Deprecated('No longer needed with AudioContributor system')
  Iterable<Pointer<TennojiDecoder>> get allAudioDecoders => _audioDecoders.keys;
  
  @Deprecated('No longer needed with AudioContributor system')
  Iterable<Pointer<TennojiDecoder>> get manualReadAudioDecoders => 
      _audioDecoders.entries.where((e) => e.value).map((e) => e.key);
}
