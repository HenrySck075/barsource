import 'package:logging/logging.dart';

import 'package:barsource/src/foundation/binding_base.dart';

enum SchedulerPhase {
  idle,
  transientCallbacks,
  midFrameMicrotasks,
  persistentCallbacks,
  postFrameCallbacks,
}

typedef FrameCallback = void Function(Duration);

class _FrameCallbackEntry {
  _FrameCallbackEntry(this.callback, {bool rescheduling = false}) {
    assert((){
      if (rescheduling) {
        debugStack = debugCurrentCallbackStack;
      } else {
        debugStack = StackTrace.current;
      }
      return true;
    }());
  }
  final FrameCallback callback;
  StackTrace? debugStack;
  static StackTrace? debugCurrentCallbackStack;
}

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

  final Map<int, _FrameCallbackEntry> _transientCallbacks = {};
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
  int scheduleFrameCallback(FrameCallback callback, {bool rescheduling = false}) {
    _transientCallbackId++;
    _transientCallbacks[_transientCallbackId] = _FrameCallbackEntry(
      callback,
      rescheduling: rescheduling
    );
    return _transientCallbackId;
  }
  void cancelFrameCallbackWithId(int id) {
    _transientCallbacks.remove(id);
  }

  void handleBeginFrame(Duration? timestamp) {
    //_log.fine('handleBeginFrame $timestamp');
    assert(_schedulerPhase == SchedulerPhase.idle);
    _schedulerPhase = .transientCallbacks;
    _hasScheduledFrame = false;   
    _currentFrameTimestamp = timestamp ?? _currentFrameTimestamp;
    //_log.fine("Calling transient callbacks ${_transientCallbacks.values}");
    final localTransientCallbacks = Map<int, _FrameCallbackEntry>.of(_transientCallbacks);
    _transientCallbacks.clear();
    for (final cb in localTransientCallbacks.values) {
      _FrameCallbackEntry.debugCurrentCallbackStack = cb.debugStack;
      cb.callback(_currentFrameTimestamp);
      // TODO: report the stack, i'm just putting it here though dart devtools will pick it up
      // the fuck do you mean
    }
    _schedulerPhase = .midFrameMicrotasks;
  }
  void handleDrawFrame() {
    //_log.fine('handleDrawFrame');
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
