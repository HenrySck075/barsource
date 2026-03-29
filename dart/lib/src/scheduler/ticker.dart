import 'dart:async';

import 'package:meta/meta.dart';
import 'package:tennoji/src/painting/basic_types.dart';
import 'package:tennoji/src/scheduler/binding.dart';

typedef TickerCallback = void Function(Duration elapsed);

class TickerCanceled implements Exception {
  const TickerCanceled([this.ticker]);

  final Ticker? ticker;

  @override
  String toString() => ticker == null ? 'Ticker was canceled' : 'Ticker $ticker was canceled';
}

class TickerFuture implements Future<void> {
  TickerFuture._();

  /// Creates a [TickerFuture] instance that represents an already-complete
  /// [Ticker] sequence.
  ///
  /// This is useful for implementing objects that normally defer to a [Ticker]
  /// but sometimes can skip the ticker because the animation is of zero
  /// duration, but which still need to represent the completed animation in the
  /// form of a [TickerFuture].
  TickerFuture.complete() {
    _complete();
  }

  final Completer<void> _primaryCompleter = Completer<void>();
  Completer<void>? _secondaryCompleter;
  bool? _completed; // null means unresolved, true means complete, false means canceled

  void _complete() {
    assert(_completed == null);
    _completed = true;
    _primaryCompleter.complete();
    _secondaryCompleter?.complete();
  }

  void _cancel(Ticker ticker) {
    assert(_completed == null);
    _completed = false;
    _secondaryCompleter?.completeError(TickerCanceled(ticker));
  }

  /// Calls `callback` either when this future resolves or when the ticker is
  /// canceled.
  ///
  /// Calling this method registers an exception handler for the [orCancel]
  /// future, so even if the [orCancel] property is accessed, canceling the
  /// ticker will not cause an uncaught exception in the current zone.
  void whenCompleteOrCancel(VoidCallback callback) {
    void thunk(dynamic value) {
      callback();
    }

    orCancel.then<void>(thunk, onError: thunk);
  }

  /// A future that resolves when this future resolves or throws when the ticker
  /// is canceled.
  ///
  /// If this property is never accessed, then canceling the ticker does not
  /// throw any exceptions. Once this property is accessed, though, if the
  /// corresponding ticker is canceled, then the [Future] returned by this
  /// getter will complete with an error, and if that error is not caught, there
  /// will be an uncaught exception in the current zone.
  Future<void> get orCancel {
    if (_secondaryCompleter == null) {
      _secondaryCompleter = Completer<void>();
      if (_completed != null) {
        if (_completed!) {
          _secondaryCompleter!.complete();
        } else {
          _secondaryCompleter!.completeError(const TickerCanceled());
        }
      }
    }
    return _secondaryCompleter!.future;
  }

  @override
  Stream<void> asStream() {
    return _primaryCompleter.future.asStream();
  }

  @override
  Future<void> catchError(Function onError, {bool Function(Object)? test}) {
    return _primaryCompleter.future.catchError(onError, test: test);
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(void value) onValue, {Function? onError}) {
    return _primaryCompleter.future.then<R>(onValue, onError: onError);
  }

  @override
  Future<void> timeout(Duration timeLimit, {FutureOr<void> Function()? onTimeout}) {
    return _primaryCompleter.future.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<void> whenComplete(dynamic Function() action) {
    return _primaryCompleter.future.whenComplete(action);
  }

  @override
  String toString() =>
      '$this(${_completed == null
          ? "active"
          : _completed!
          ? "complete"
          : "canceled"})';
}
class Ticker {
  Ticker(this._onTick);

  final TickerCallback _onTick;
  Duration? _startTime;
  int? _tickId;
  TickerFuture? _future;
  bool _muted = false;
  bool get muted => _muted;
  set muted(bool value) {
    if (value == muted) {
      return;
    }
    _muted = value;
    if (value) {
      unscheduleTick();
    } else /*if (shouldScheduleTick)*/ {
      scheduleTick();
    }
  }

  bool get isTicking {
    if (_future == null) {
      return false;
    }
    if (muted) {
      return false;
    }
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      return true;
    } // for example, we might be in a warm-up frame or forced frame
    return false;
  } 
  bool get isActive => _future != null;

  TickerFuture start() {
    assert(!isTicking, "nuh uh you arent starting this twice");
    _future = TickerFuture._();
    scheduleTick();
    return _future!;
  }

  void stop({bool canceled = false}) {
    if (!isTicking) return;
    final fut = _future!;
    _future = null;
    _startTime = null;
    unscheduleTick();
    if (canceled) {
      fut._cancel(this);
    } else {
      fut._complete();
    }
  }

  void _tick(Duration timeStamp) {
    if (!isTicking) return;
    _startTime ??= timeStamp;
    _onTick(timeStamp - _startTime!);
    // We request the next tick
    if (isTicking) {
       scheduleTick();
    }
  }

  void scheduleTick() {
    _tickId = SchedulerBinding.instance.scheduleFrameCallback(_tick);
  }
  void unscheduleTick() {
    if (_tickId != null) SchedulerBinding.instance.cancelFrameCallbackWithId(_tickId!);
  }

  @mustCallSuper
  void dispose() {
    unscheduleTick();
  }
}

abstract class TickerProvider {
  Ticker createTicker(TickerCallback onTick);
}
