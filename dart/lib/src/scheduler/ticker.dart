import 'package:meta/meta.dart';
import 'package:tennoji/src/scheduler/binding.dart';

typedef TickerCallback = void Function(Duration elapsed);

class Ticker {
  Ticker(this._onTick);

  final TickerCallback _onTick;
  bool _isTicking = false;
  Duration? _startTime;
  int? _tickId;

  bool get isTicking => _isTicking;

  void start() {
    if (_isTicking) return;
    _isTicking = true;
    scheduleTick();
  }

  void stop({bool canceled = false}) {
    if (!_isTicking) return;
    _isTicking = false;
    _startTime = null;
  }

  void _tick(Duration timeStamp) {
    if (!_isTicking) return;
    _startTime ??= timeStamp;
    _onTick(timeStamp - _startTime!);
    // We request the next tick
    if (_isTicking) {
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
