import 'dart:async';

import 'package:barsource/src/engine/engine.dart';

// ignore: use_function_type_syntax_for_parameters
Future<T> futureDelayedE<T>(Duration duration, [FutureOr<T> computation()?]) {
  if (computation == null && null is! T) {
    throw ArgumentError.value(
      null,
      "computation",
      "The type parameter is not nullable",
    );
  }
  final completer = Completer<T>();

  EngineTimer(duration, (){
    if (computation == null) {
      completer.complete(null as T);
    } else {
      FutureOr<T> computationResult;
      try {
        computationResult = computation();
      } catch (e, s) {
        //_completeWithErrorCallback(result, e, s);
        completer.completeError(e, s);
        return;
      }
      completer.complete(computationResult);
    }
  });

  return completer.future;
}
