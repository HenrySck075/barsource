import 'dart:math' as math;

import 'package:tennoji/src/engine/render_controller.dart';
import 'package:tennoji/src/foundation/listenable.dart';
import 'package:tennoji/src/painting/basic_types.dart';

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

abstract class Animation<T> extends Listenable implements ValueListenable<T> {
  @override
  T get value;
  AnimationStatus get status;
}

/// A value that changes over a [Duration].
class AnimationController extends Animation<double> {
  AnimationController({
    required this.duration,
    required TickerProvider vsync,
    this.lowerBound = 0.0,
    this.upperBound = 1.0,
  }) {
    _ticker = vsync.createTicker(_tick);
    _value = lowerBound;
  }

  final Duration duration;
  final double lowerBound;
  final double upperBound;
  
  late final Ticker _ticker;
  final Set<VoidCallback> _listeners = {};
  final Set<void Function(AnimationStatus)> _statusListeners = {};

  double _value = 0.0;
  @override double get value => _value;

  AnimationStatus _status = AnimationStatus.dismissed;
  @override AnimationStatus get status => _status;

  // --- Core Logic ---

  void _tick(Duration elapsed) {
    double elapsedInSeconds = elapsed.inMicroseconds / duration.inMicroseconds;
    
    if (_status == AnimationStatus.forward) {
      _value = (lowerBound + (upperBound - lowerBound) * elapsedInSeconds).clamp(lowerBound, upperBound);
      if (_value >= upperBound) _complete();
    } else if (_status == AnimationStatus.reverse) {
      _value = (upperBound - (upperBound - lowerBound) * elapsedInSeconds).clamp(lowerBound, upperBound);
      if (_value <= lowerBound) _complete();
    }
    
    _notify();
  }

  void forward() {
    _status = AnimationStatus.forward;
    _ticker.start();
  }

  void reverse() {
    _status = AnimationStatus.reverse;
    _ticker.start();
  }

  void stop() => _ticker.stop();

  void _complete() {
    _status = (_status == AnimationStatus.forward) ? AnimationStatus.completed : AnimationStatus.dismissed;
    _ticker.stop();
    _notifyStatus();
  }

  // --- Boilerplate Minimization ---

  @override void addListener(VoidCallback listener) => _listeners.add(listener);
  @override void removeListener(VoidCallback listener) => _listeners.remove(listener);
  
  void addStatusListener(void Function(AnimationStatus) listener) => _statusListeners.add(listener);

  void _notify() { for (final l in _listeners) l(); }
  void _notifyStatus() { for (final l in _statusListeners) l(_status); }

  void dispose() {
    _ticker.dispose();
    _listeners.clear();
    _statusListeners.clear();
  }
}

// ---------------------------------------------------------------------------
// Tweens
// ---------------------------------------------------------------------------

/// Linearly interpolates between [begin] and [end] given a progress [t].
class Tween<T extends num> {
  const Tween({required this.begin, required this.end});

  final T begin;
  final T end;

  /// Evaluate at progress [t] (0.0 → begin, 1.0 → end).
  double transform(double t) => begin + (end - begin) * t;
}

/// An [Offset]-based tween for sliding animations.
class OffsetTween {
  const OffsetTween({required this.begin, required this.end});

  final (double, double) begin;
  final (double, double) end;

  (double, double) transform(double t) => (
    begin.$1 + (end.$1 - begin.$1) * t,
    begin.$2 + (end.$2 - begin.$2) * t,
  );
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
