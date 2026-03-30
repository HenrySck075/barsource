import 'package:meta/meta.dart';
import 'package:tennoji/src/animation/animation.dart';
import 'package:tennoji/src/painting/basic_types.dart';
import 'package:tennoji/src/rendering/align_render.dart';
import 'package:tennoji/src/widgets/animated.dart';
import 'package:tennoji/src/widgets/framework.dart';
import 'package:tennoji/src/widgets/ticker_provider.dart';

abstract class ImplicitlyAnimatedWidget extends StatefulWidget {
  const ImplicitlyAnimatedWidget({
    super.key,
    required this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  final Duration duration;
  final Curve curve;
  final VoidCallback? onEnd;
}
typedef TweenConstructor<T extends Object> = Tween<T> Function(T targetValue);
typedef TweenVisitor<T extends Object> =
    Tween<T>? Function(Tween<T>? tween, T targetValue, TweenConstructor<T> constructor);
abstract class ImplicitlyAnimatedWidgetState<T extends ImplicitlyAnimatedWidget>
    extends State<T> 
    with SingleTickerProviderStateMixin<T> {
  late final AnimationController controller;
  late CurvedAnimation _animation;
  Animation<double> get animation => _animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: widget.duration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onEnd?.call();
        }
      });
    _animation = CurvedAnimation(
      parent: controller,
      curve: widget.curve,
    );
    _constructTweens();
    didUpdateTweens();
  }
  @protected
  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.curve != oldWidget.curve) {
      _animation.dispose();
      _animation = CurvedAnimation(
        parent: controller,
        curve: widget.curve,
      );
    }
    controller.duration = widget.duration;
    if (_constructTweens()) {
      forEachTween((
        Tween<dynamic>? tween,
        dynamic targetValue,
        TweenConstructor<dynamic> constructor,
      ) {
        return tween
          ?..begin = tween.evaluate(_animation)
          ..end = targetValue;
      });
      controller.forward(from: 0.0);
      didUpdateTweens();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
  @protected
  void forEachTween(TweenVisitor<dynamic> visitor);
  bool _constructTweens() {
    var shouldStartAnimation = false;
    forEachTween((
      Tween<dynamic>? tween,
      dynamic targetValue,
      TweenConstructor<dynamic> constructor,
    ) {
      if (targetValue != null) {
        tween ??= constructor(targetValue);
        if (targetValue != (tween.end ?? tween.begin)) {
          shouldStartAnimation = true;
        } else {
          tween.end ??= tween.begin;
        }
      } else {
        tween = null;
      }
      return tween;
    });
    return shouldStartAnimation;
  }
  @protected
  void didUpdateTweens() {}
}


// ===== AnimatedOpacity =====
class AnimatedOpacity extends ImplicitlyAnimatedWidget {
  const AnimatedOpacity({
    super.key,
    required this.opacity,
    required super.duration,
    super.curve,
    super.onEnd,
    this.child,
  });

  final double opacity;
  final Widget? child;

  @override
  State<AnimatedOpacity> createState() => _AnimatedOpacityState();
}

class _AnimatedOpacityState extends ImplicitlyAnimatedWidgetState<AnimatedOpacity> {
  late Tween<double> _opacity;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _opacity = visitor(_opacity, widget.opacity, (targetValue) => Tween<double>(begin: targetValue)) as Tween<double>;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity.animate(animation),
      child: widget.child,
    );
  }
}

// ===== AnimatedSlide =====
class AnimatedSlide extends ImplicitlyAnimatedWidget {
  const AnimatedSlide({
    super.key,
    required this.offset,
    required super.duration,
    super.curve,
    super.onEnd,
    this.child,
  });

  final Offset offset;
  final Widget? child;

  @override
  State<AnimatedSlide> createState() => _AnimatedSlideState();
}

class _AnimatedSlideState extends ImplicitlyAnimatedWidgetState<AnimatedSlide> {
  late Tween<Offset> _offset;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _offset = visitor(_offset, widget.offset, (targetValue) => Tween<Offset>(begin: targetValue)) as Tween<Offset>;
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      offset: _offset.animate(animation),
      child: widget.child,
    );
  }
}

// ===== AnimatedScale =====
class AnimatedScale extends ImplicitlyAnimatedWidget {
  const AnimatedScale({
    super.key,
    required this.scale,
    this.alignment = Alignment.center,
    required super.duration,
    super.curve,
    super.onEnd,
    this.child,
  });

  final double scale;
  final Alignment alignment;
  final Widget? child;

  @override
  State<AnimatedScale> createState() => _AnimatedScaleState();
}

class _AnimatedScaleState extends ImplicitlyAnimatedWidgetState<AnimatedScale> {
  late Tween<double> _scale;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _scale = visitor(_scale, widget.scale, (targetValue) => Tween<double>(begin: targetValue)) as Tween<double>;
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale.animate(animation),
      alignment: widget.alignment,
      child: widget.child,
    );
  }
}

// ===== AnimatedRotation =====
class AnimatedRotation extends ImplicitlyAnimatedWidget {
  const AnimatedRotation({
    super.key,
    required this.turns,
    required super.duration,
    super.curve,
    super.onEnd,
    this.child,
  });

  final double turns;
  final Widget? child;

  @override
  State<AnimatedRotation> createState() => _AnimatedRotationState();
}

class _AnimatedRotationState extends ImplicitlyAnimatedWidgetState<AnimatedRotation> {
  late Tween<double> _turns;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _turns = visitor(_turns, widget.turns, (targetValue) => Tween<double>(begin: targetValue)) as Tween<double>;
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _turns.animate(animation),
      child: widget.child,
    );
  }
}
