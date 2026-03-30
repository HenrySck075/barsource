import 'package:logging/logging.dart';

import 'package:tennoji/src/foundation/binding_base.dart';

enum SchedulerPhase {
  idle,
  transientCallbacks,
  midFrameMicrotasks,
  persistentCallbacks,
  postFrameCallbacks,
}

typedef FrameCallback = void Function(Duration);

mixin SchedulerBinding on BindingBase {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  static SchedulerBinding? _instance;
  static SchedulerBinding get instance => BindingBase.checkInstance(_instance);

  Duration _currentFrameTimestamp = Duration.zero;
  SchedulerPhase _schedulerPhase = .idle;
  SchedulerPhase get schedulerPhase => _schedulerPhase;
  bool _hasScheduledFrame = false;

  final Map<int, FrameCallback> _transientCallbacks = {};
  int _transientCallbackId = 0;
  final List<FrameCallback> _persistentCallbacks = [];
  final List<FrameCallback> _postFrameCallbacks = [];
  
  final _log = Logger('SchedulerBinding');

  void addPersistentFrameCallback(FrameCallback callback) {
    _persistentCallbacks.add(callback);
  }
  void addPostFrameCallback(FrameCallback callback) {
    _postFrameCallbacks.add(callback);
  }
  int scheduleFrameCallback(FrameCallback callback) {
    _transientCallbacks[_transientCallbackId++] = callback;
    return _transientCallbackId;
  }
  void cancelFrameCallbackWithId(int id) {
    _transientCallbacks.remove(id);
  }

  void handleBeginFrame(Duration? timestamp) {
    _log.fine('handleBeginFrame $timestamp');
    assert(_schedulerPhase == SchedulerPhase.idle);
    _hasScheduledFrame = false;   
    _currentFrameTimestamp = timestamp ?? _currentFrameTimestamp;
    for (final cb in _transientCallbacks.values) {
      cb(_currentFrameTimestamp);
    }
    _transientCallbacks.clear();
    _schedulerPhase = .midFrameMicrotasks;
  }
  void handleDrawFrame() {
    _log.fine('handleDrawFrame');
    assert(_schedulerPhase == SchedulerPhase.midFrameMicrotasks);
    try {
      // PERSISTENT FRAME CALLBACKS
      _schedulerPhase = SchedulerPhase.persistentCallbacks;
      for (final callback in _persistentCallbacks) {
        callback(_currentFrameTimestamp);
      }

      // POST-FRAME CALLBACKS
      _schedulerPhase = SchedulerPhase.postFrameCallbacks;
      final localPostFrameCallbacks = List<FrameCallback>.of(_postFrameCallbacks);
      _postFrameCallbacks.clear();
      try {
        for (final callback in localPostFrameCallbacks) {
          callback(_currentFrameTimestamp);
        }
      } finally {
      }
    } finally {
      _schedulerPhase = SchedulerPhase.idle;
      /*
      assert(() {
        if (debugPrintEndFrameBanner) {
          debugPrint('▀' * _debugBanner!.length);
        }
        _debugBanner = null;
        return true;
      }());
      _currentFrameTimeStamp = null;
      */
    }
  }
}
