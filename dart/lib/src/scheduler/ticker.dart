import 'package:tennoji/src/scheduler/binding.dart';

typedef TickerCallback = void Function(Duration elapsed);

class Ticker {
  Ticker(this._onTick);

  final TickerCallback _onTick;
  bool _isTicking = false;
  Duration? _startTime;

  bool get isTicking => _isTicking;

  void start() {
    if (_isTicking) return;
    _isTicking = true;
    _scheduleTick();
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
       _scheduleTick();
    }
  }

  void _scheduleTick() {
    SchedulerBinding.instance.scheduleFrameCallback(_tick);
  }
}

abstract class TickerProvider {
  Ticker createTicker(TickerCallback onTick);
}
