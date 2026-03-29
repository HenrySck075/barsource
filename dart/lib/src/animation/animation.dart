import 'dart:math' as math;

import 'package:tennoji/src/animation/listener_helpers.dart';
import 'package:tennoji/src/dart_ui/dart_ui.dart';
import 'package:tennoji/src/engine/render_controller.dart';
import 'package:tennoji/src/foundation/listenable.dart';
import 'package:tennoji/src/painting/basic_types.dart';
import 'package:tennoji/src/physics/simulation.dart';

/// The status of an animation at a given point in time.
enum AnimationStatus {
  /// The animation is stopped at the beginning.
  dismissed,

  /// The animation is running from beginning to end.
  forward,

  /// The animation is running from end to beginning.
  reverse,

  /// The animation is stopped at the end.
  completed,
}
enum _AnimationDirection {
  forward,
  reverse,
}

abstract class Animation<T> extends Listenable implements ValueListenable<T> {
  const Animation();
  @override
  T get value;
  AnimationStatus get status;

  void addStatusListener(AnimationStatusListener listener);
  void removeStatusListener(AnimationStatusListener listener);
}

class _AlwaysCompleteAnimation extends Animation<double> {
  const _AlwaysCompleteAnimation();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  AnimationStatus get status => AnimationStatus.completed;

  @override
  double get value => 1.0;

  @override
  String toString() => 'kAlwaysCompleteAnimation';
}

/// An animation that is always complete.
///
/// Using this constant involves less overhead than building an
/// [AnimationController] with an initial value of 1.0. This is useful when an
/// API expects an animation but you don't actually want to animate anything.
const Animation<double> kAlwaysCompleteAnimation = _AlwaysCompleteAnimation();

/// A value that changes over a [Duration].
class AnimationController extends Animation<double> 
  with AnimationEagerListenerMixin, AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  AnimationController({
    required this.duration,
    this.reverseDuration,
    //required TickerProvider vsync,
    this.lowerBound = 0.0,
    this.upperBound = 1.0,
    double? value
  }) {
    _ticker = Ticker(_tick);//vsync.createTicker(_tick);
    _value = value ?? lowerBound;
  }

  final Duration duration;
  final Duration? reverseDuration;
  final double lowerBound;
  final double upperBound;
  
  Ticker? _ticker;
  Simulation? _simulation;

  double _value = 0.0;
  @override double get value => _value;
  set value(double val) {
    stop();
    _internalSetValue(val);
    _notify();
    _notifyStatus();
  }
  void _internalSetValue(double newValue) {
    _value = clampDouble(newValue, lowerBound, upperBound);
    if (_value == lowerBound) {
      _status = AnimationStatus.dismissed;
    } else if (_value == upperBound) {
      _status = AnimationStatus.completed;
    } else {
      _status = switch (_direction) {
        _AnimationDirection.forward => AnimationStatus.forward,
        _AnimationDirection.reverse => AnimationStatus.reverse,
      };
    }
  }

  AnimationStatus _status = AnimationStatus.dismissed;
  @override AnimationStatus get status => _status;

  _AnimationDirection _direction = .forward;

  @override
  bool get isAnimating => _ticker != null && _ticker!.isActive;

  /// The amount of time that has passed between the time the animation started
  /// and the most recent tick of the animation.
  ///
  /// If the controller is not animating, the last elapsed duration is null.
  Duration? get lastElapsedDuration => _lastElapsedDuration;
  Duration? _lastElapsedDuration;

  // --- Core Logic ---
  TickerFuture _startSimulation(Simulation simulation) {
    assert(!isAnimating);
    _simulation = simulation;
    _lastElapsedDuration = Duration.zero;
    _value = clampDouble(simulation.x(0.0), lowerBound, upperBound);
    final TickerFuture result = _ticker!.start();
    _status = (_direction == _AnimationDirection.forward)
        ? AnimationStatus.forward
        : AnimationStatus.reverse;
    _notifyStatus();
    return result;
  }
  void _tick(Duration elapsed) {
    _lastElapsedDuration = elapsed;
    final double elapsedInSeconds =
        elapsed.inMicroseconds.toDouble() / Duration.microsecondsPerSecond;
    assert(elapsedInSeconds >= 0.0);
    _value = clampDouble(_simulation!.x(elapsedInSeconds), lowerBound, upperBound);
    if (_simulation!.isDone(elapsedInSeconds)) {
      _status = (_direction == _AnimationDirection.forward)
          ? AnimationStatus.completed
          : AnimationStatus.dismissed;
      stop(canceled: false);
    }
    _notify();
    _notifyStatus();
  }  
  TickerFuture forward() {
    _status = AnimationStatus.forward;
    return _ticker.start();
  }

  TickerFuture reverse() {
    _status = AnimationStatus.reverse;
    return _ticker.start();
  }

  void stop({bool canceled = true}) => _ticker.stop(canceled: canceled);

  void _complete() {
    _status = (_status == AnimationStatus.forward) ? AnimationStatus.completed : AnimationStatus.dismissed;
    _ticker.stop();
    notifyStatusListeners(status);
  }

  // --- Boilerplate Minimization ---

  void dispose() {
    _ticker?.dispose();
  }
}

class _InterpolationSimulation extends Simulation {
  _InterpolationSimulation(this._begin, this._end, Duration duration, this._curve, double scale)
    : assert(duration.inMicroseconds > 0),
      _durationInSeconds = (duration.inMicroseconds * scale) / Duration.microsecondsPerSecond;

  final double _durationInSeconds;
  final double _begin;
  final double _end;
  final Curve _curve;

  @override
  double x(double timeInSeconds) {
    final double t = clampDouble(timeInSeconds / _durationInSeconds, 0.0, 1.0);
    return switch (t) {
      0.0 => _begin,
      1.0 => _end,
      _ => _begin + (_end - _begin) * _curve.transform(t),
    };
  }

  @override
  double dx(double timeInSeconds) {
    final double epsilon = tolerance.time;
    return (x(timeInSeconds + epsilon) - x(timeInSeconds - epsilon)) / (2 * epsilon);
  }

  @override
  bool isDone(double timeInSeconds) => timeInSeconds > _durationInSeconds;
}



mixin AnimationWithParentMixin<T> {
  /// The animation whose value this animation will proxy.
  ///
  /// This animation must remain the same for the lifetime of this object. If
  /// you wish to proxy a different animation at different times, consider using
  /// [ProxyAnimation].
  Animation<T> get parent;

  // keep these next five dartdocs in sync with the dartdocs in Animation<T>

  /// Calls the listener every time the value of the animation changes.
  ///
  /// Listeners can be removed with [removeListener].
  void addListener(VoidCallback listener) => parent.addListener(listener);

  /// Stop calling the listener every time the value of the animation changes.
  ///
  /// Listeners can be added with [addListener].
  void removeListener(VoidCallback listener) => parent.removeListener(listener);

  /// The current status of this animation.
  AnimationStatus get status => parent.status;
}

// ---------------------------------------------------------------------------
// Tweens
// ---------------------------------------------------------------------------

abstract class Animatable<T> {
  const Animatable();

  Animation<T> animate(Animation<double> parent) => _AnimatedEvaluation(parent, this);

  T evaluate(Animation<double> animation) => transform(animation.value);
  /// Evaluate at progress [t] (0.0 → begin, 1.0 → end).
  T transform(double t);
}

class _AnimatedEvaluation<T> extends Animation<T> with AnimationWithParentMixin<double> {
  _AnimatedEvaluation(this.parent, this._evaluatable);

  @override
  final Animation<double> parent;

  final Animatable<T> _evaluatable;

  @override
  T get value => _evaluatable.evaluate(parent);

  @override
  String toString() {
    return '$parent\u27A9$_evaluatable\u27A9$value';
  }

/*
  @override
  String toStringDetails() {
    return '${super.toStringDetails()} $_evaluatable';
  }
*/
}


/// Linearly interpolates between [begin] and [end] given a progress [t].
class Tween<T> extends Animatable<T> {
  const Tween({required this.begin, required this.end});

  final T begin;
  final T end;

  /// Evaluate at progress [t] (0.0 → begin, 1.0 → end).
  @override
  T transform(double t) {
    try {
      return (begin as dynamic) + ((end as dynamic) - (begin as dynamic)) * t;
    } on NoSuchMethodError {
      throw ArgumentError("Cannot lerp between $begin and $end, class might not implement `+`, `-`, and/or `*`.");
    } on TypeError {
      throw ArgumentError("Cannot lerp between $begin and $end, the return type of the `*` operation with a double (time) returns an incompatibe type");
    }
  }
}

// ---------------------------------------------------------------------------
// Curves
// ---------------------------------------------------------------------------

/// A mapping of the unit interval to the unit interval.
abstract class Curve {
  const Curve();

  /// Transform a value [t] in [0.0, 1.0] to another value in [0.0, 1.0].
  double transform(double t);
}

class _LinearCurve extends Curve {
  const _LinearCurve();

  @override
  double transform(double t) => t;
}

class _Cubic extends Curve {
  const _Cubic(this.a, this.b, this.c, this.d);

  final double a;
  final double b;
  final double c;
  final double d;

  // De Casteljau evaluation of a cubic Bézier with control points
  // (0,0), (a,b), (c,d), (1,1).
  @override
  double transform(double t) {
    // Newton–Raphson to solve for the parametric t that yields x = t.
    double start = 0.0;
    double end = 1.0;
    double mid = t;

    // Iterative binary search (good enough for offline rendering).
    for (int i = 0; i < 20; i++) {
      final x = _evaluateCubic(a, c, mid);
      if ((x - t).abs() < 1e-6) break;
      if (x < t) {
        start = mid;
      } else {
        end = mid;
      }
      mid = (start + end) / 2.0;
    }
    return _evaluateCubic(b, d, mid);
  }

  static double _evaluateCubic(double p1, double p2, double t) {
    // Cubic Bézier: B(t) = 3*(1-t)^2*t*p1 + 3*(1-t)*t^2*p2 + t^3
    final oneMinusT = 1.0 - t;
    return 3.0 * oneMinusT * oneMinusT * t * p1 +
        3.0 * oneMinusT * t * t * p2 +
        t * t * t;
  }
}

class _DecelerateCurve extends Curve {
  const _DecelerateCurve();

  @override
  double transform(double t) => 1.0 - (1.0 - t) * (1.0 - t);
}

class _BounceCurve extends Curve {
  const _BounceCurve();

  @override
  double transform(double t) => _bounce(t);

  static double _bounce(double t) {
    if (t < 1.0 / 2.75) {
      return 7.5625 * t * t;
    } else if (t < 2.0 / 2.75) {
      final adjusted = t - 1.5 / 2.75;
      return 7.5625 * adjusted * adjusted + 0.75;
    } else if (t < 2.5 / 2.75) {
      final adjusted = t - 2.25 / 2.75;
      return 7.5625 * adjusted * adjusted + 0.9375;
    } else {
      final adjusted = t - 2.625 / 2.75;
      return 7.5625 * adjusted * adjusted + 0.984375;
    }
  }
}

class _ElasticCurve extends Curve {
  const _ElasticCurve();

  @override
  double transform(double t) {
    if (t == 0.0 || t == 1.0) return t;
    final p = 0.3;
    final s = p / 4.0;
    return math.pow(2.0, -10.0 * t) *
            math.sin((t - s) * (2.0 * math.pi) / p) +
        1.0;
  }
}

class _ReversedCurve extends Curve {
  const _ReversedCurve(this.curve);
  final Curve curve;

  @override
  double transform(double t) => 1.0 - curve.transform(1.0 - t);
}

class _FlippedCurve extends Curve {
  const _FlippedCurve(this.curve);
  final Curve curve;

  @override
  double transform(double t) => 1.0 - curve.transform(t);
}

/// An interval that maps a sub-range of the 0.0~1.0 input range to 0.0~1.0
/// output, applying an optional [curve] within that interval.
class Interval extends Curve {
  const Interval(this.begin, this.end, {this.curve = Curves.linear})
      : assert(begin >= 0.0 && begin <= 1.0),
        assert(end >= 0.0 && end <= 1.0),
        assert(end >= begin);

  final double begin;
  final double end;
  final Curve curve;

  @override
  double transform(double t) {
    if (t <= begin) return 0.0;
    if (t >= end) return 1.0;
    final localT = (t - begin) / (end - begin);
    return curve.transform(localT.clamp(0.0, 1.0));
  }
}

/// Standard easing curves, matching Flutter's [Curves].
abstract final class Curves {
  static const Curve linear = _LinearCurve();
  static const Curve decelerate = _DecelerateCurve();
  static const Curve ease = _Cubic(0.25, 0.1, 0.25, 1.0);
  static const Curve easeIn = _Cubic(0.42, 0.0, 1.0, 1.0);
  static const Curve easeOut = _Cubic(0.0, 0.0, 0.58, 1.0);
  static const Curve easeInOut = _Cubic(0.42, 0.0, 0.58, 1.0);

  static const Curve easeInCubic = _Cubic(0.55, 0.055, 0.675, 0.19);
  static const Curve easeOutCubic = _Cubic(0.215, 0.61, 0.355, 1.0);
  static const Curve easeInOutCubic = _Cubic(0.645, 0.045, 0.355, 1.0);

  static const Curve easeInQuart = _Cubic(0.895, 0.03, 0.685, 0.22);
  static const Curve easeOutQuart = _Cubic(0.165, 0.84, 0.44, 1.0);
  static const Curve easeInOutQuart = _Cubic(0.77, 0.0, 0.175, 1.0);

  static const Curve easeInQuint = _Cubic(0.755, 0.05, 0.855, 0.06);
  static const Curve easeOutQuint = _Cubic(0.23, 1.0, 0.32, 1.0);
  static const Curve easeInOutQuint = _Cubic(0.86, 0.0, 0.07, 1.0);

  static const Curve bounceOut = _BounceCurve();
  static const Curve bounceIn = _ReversedCurve(_BounceCurve());

  static const Curve elasticOut = _ElasticCurve();
  static const Curve elasticIn = _ReversedCurve(_ElasticCurve());

  /// Convenience: reverse any curve.
  static Curve reversed(Curve curve) => _ReversedCurve(curve);

  /// Convenience: flip any curve (1 - curve(t)).
  static Curve flipped(Curve curve) => _FlippedCurve(curve);
}
