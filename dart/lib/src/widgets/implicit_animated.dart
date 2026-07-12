import 'package:barsource/src/widgets/stack.dart';
import 'package:meta/meta.dart';
import 'package:barsource/src/animation/animation.dart';
import 'package:barsource/src/painting/basic_types.dart';
import 'package:barsource/src/rendering/align_render.dart';
import 'package:barsource/src/widgets/animated.dart';
import 'package:barsource/src/widgets/framework.dart';
import 'package:barsource/src/widgets/ticker_provider.dart';

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

// ===== AnimatedPositioned =====
class AnimatedPositioned extends ImplicitlyAnimatedWidget {
  /// Creates a widget that animates its position implicitly.
  ///
  /// Only two out of the three horizontal values ([left], [right],
  /// [width]), and only two out of the three vertical values ([top],
  /// [bottom], [height]), can be set. In each case, at least one of
  /// the three must be null.
  const AnimatedPositioned({
    super.key,
    required this.child,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    super.curve,
    required super.duration,
    super.onEnd,
  }) : assert(left == null || right == null || width == null),
       assert(top == null || bottom == null || height == null);

  /// Creates a widget that animates the rectangle it occupies implicitly.
  AnimatedPositioned.fromRect({
    super.key,
    required this.child,
    required Rect rect,
    super.curve,
    required super.duration,
    super.onEnd,
  }) : left = rect.left,
       top = rect.top,
       width = rect.width,
       height = rect.height,
       right = null,
       bottom = null;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// The offset of the child's left edge from the left of the stack.
  final double? left;

  /// The offset of the child's top edge from the top of the stack.
  final double? top;

  /// The offset of the child's right edge from the right of the stack.
  final double? right;

  /// The offset of the child's bottom edge from the bottom of the stack.
  final double? bottom;

  /// The child's width.
  ///
  /// Only two out of the three horizontal values ([left], [right], [width]) can
  /// be set. The third must be null.
  final double? width;

  /// The child's height.
  ///
  /// Only two out of the three vertical values ([top], [bottom], [height]) can
  /// be set. The third must be null.
  final double? height;

  @override
  ImplicitlyAnimatedWidgetState<AnimatedPositioned> createState() => _AnimatedPositionedState();

/*
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('left', left, defaultValue: null));
    properties.add(DoubleProperty('top', top, defaultValue: null));
    properties.add(DoubleProperty('right', right, defaultValue: null));
    properties.add(DoubleProperty('bottom', bottom, defaultValue: null));
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DoubleProperty('height', height, defaultValue: null));
  }
  */
}

class _AnimatedPositionedState extends ImplicitlyAnimatedWidgetState<AnimatedPositioned> {
  Tween<double>? _left;
  Tween<double>? _top;
  Tween<double>? _right;
  Tween<double>? _bottom;
  Tween<double>? _width;
  Tween<double>? _height;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _left =
        visitor(_left, widget.left, (dynamic value) => Tween<double>(begin: value as double))
            as Tween<double>?;
    _top =
        visitor(_top, widget.top, (dynamic value) => Tween<double>(begin: value as double))
            as Tween<double>?;
    _right =
        visitor(_right, widget.right, (dynamic value) => Tween<double>(begin: value as double))
            as Tween<double>?;
    _bottom =
        visitor(_bottom, widget.bottom, (dynamic value) => Tween<double>(begin: value as double))
            as Tween<double>?;
    _width =
        visitor(_width, widget.width, (dynamic value) => Tween<double>(begin: value as double))
            as Tween<double>?;
    _height =
        visitor(_height, widget.height, (dynamic value) => Tween<double>(begin: value as double))
            as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _left?.evaluate(animation),
      top: _top?.evaluate(animation),
      right: _right?.evaluate(animation),
      bottom: _bottom?.evaluate(animation),
      width: _width?.evaluate(animation),
      height: _height?.evaluate(animation),
      child: widget.child,
    );
  }

  /*
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(ObjectFlagProperty<Tween<double>>.has('left', _left));
    description.add(ObjectFlagProperty<Tween<double>>.has('top', _top));
    description.add(ObjectFlagProperty<Tween<double>>.has('right', _right));
    description.add(ObjectFlagProperty<Tween<double>>.has('bottom', _bottom));
    description.add(ObjectFlagProperty<Tween<double>>.has('width', _width));
    description.add(ObjectFlagProperty<Tween<double>>.has('height', _height));
  }
  */ 
}
