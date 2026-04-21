import 'dart:async';

import 'package:barsource/animation.dart';
import 'package:meta/meta.dart';
import 'package:barsource/src/painting/basic_types.dart' show VoidCallback;

import 'framework.dart';
import 'overlay.dart';

@immutable
/// Configuration data passed to route resolution callbacks.
class RouteSettings {
  /// Creates route settings with an optional [name] and [arguments].
  const RouteSettings({this.name, this.arguments});

  /// The route name, usually a path-like string such as `/settings`.
  final String? name;

  /// Extra data passed to the route when it is created.
  final Object? arguments;
}

/// Signature for creating a route from [RouteSettings].
typedef RouteFactory = Route<dynamic>? Function(RouteSettings settings);

/// Signature for customizing how a [PageRoute] presents its built page.
typedef RouteTransitionsBuilder =
    Widget Function(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    );

class _AlwaysDismissedAnimation extends Animation<double> {
  const _AlwaysDismissedAnimation();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  AnimationStatus get status => AnimationStatus.dismissed;

  @override
  double get value => 0.0;
}

const Animation<double> _kAlwaysDismissedAnimation =
    _AlwaysDismissedAnimation();

/// A visual route managed by a [NavigatorState].
abstract class Route<T> {
  /// Creates a route with optional [settings].
  Route({RouteSettings? settings})
    : settings = settings ?? const RouteSettings();

  /// The settings used to identify and configure this route.
  final RouteSettings settings;

  NavigatorState? _navigator;
  final Completer<T?> _popCompleter = Completer<T?>();
  late final OverlayEntry _overlayEntry = createOverlayEntry();

  /// The [NavigatorState] currently hosting this route, if any.
  NavigatorState? get navigator => _navigator;

  /// Whether this route is currently installed in a navigator.
  bool get isActive => _navigator != null;

  /// Completes when this route is popped.
  Future<T?> get popped => _popCompleter.future;

  /// The overlay entry that renders this route.
  OverlayEntry get overlayEntry => _overlayEntry;

  /// Whether this route fully obscures routes below it.
  bool get opaque => true;

  /// Whether to keep this route's state when inactive.
  bool get maintainState => true;

  /// Builds the primary widget subtree for this route.
  @protected
  Widget buildPage(BuildContext context);

  /// Creates the [OverlayEntry] used to present this route.
  @protected
  OverlayEntry createOverlayEntry() {
    return OverlayEntry(
      builder: buildPage,
      opaque: opaque,
      maintainState: maintainState,
    );
  }

  /// Installs this route into a [NavigatorState].
  ///
  /// Throws a [StateError] if the route is already installed.
  @mustCallSuper
  void install(NavigatorState navigator) {
    if (_navigator != null) {
      throw StateError('Route is already installed in a Navigator.');
    }
    _navigator = navigator;
  }

  /// Called when this route is asked to pop.
  ///
  /// Returns whether the pop was handled. The default implementation
  /// completes [popped] and returns `true`.
  bool didPop(T? result) {
    didComplete(result);
    return true;
  }

  /// Called by the navigator after this route is added to the stack.
  @mustCallSuper
  void didPush() {}

  /// Completes this route with [result] if it has not completed yet.
  @mustCallSuper
  void didComplete(T? result) {
    if (!_popCompleter.isCompleted) {
      _popCompleter.complete(result);
    }
  }

  /// Releases resources held by this route.
  @mustCallSuper
  void dispose() {
    _navigator = null;
    if (!_popCompleter.isCompleted) {
      _popCompleter.complete(null);
    }
  }
}

/// A route that builds its content from a [WidgetBuilder].
class PageRoute<T> extends Route<T> {
  /// Creates a page route.
  PageRoute({
    required this.builder,
    super.settings,
    bool opaque = true,
    bool maintainState = true,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.reverseTransitionDuration,
    this.transitionBuilder,
  }) : _opaque = opaque,
       _maintainState = maintainState;

  /// Builds the route's widget tree.
  final WidgetBuilder builder;
  final Duration transitionDuration;
  final Duration? reverseTransitionDuration;
  final RouteTransitionsBuilder? transitionBuilder;
  final bool _opaque;
  final bool _maintainState;
  AnimationController? _controller;

  @override
  bool get opaque => _opaque;

  @override
  bool get maintainState => _maintainState;

  Animation<double> get _animation => _controller ?? kAlwaysCompleteAnimation;

  @override
  void install(NavigatorState navigator) {
    super.install(navigator);
    _controller = AnimationController(
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration ?? transitionDuration,
      value: 1.0,
    )..addListener(overlayEntry.markNeedsBuild);
  }

  @override
  void didPush() {
    super.didPush();
    _controller?.forward(from: 0.0);
  }

  @override
  bool didPop(T? result) {
    final AnimationController? controller = _controller;
    if (controller == null) {
      return super.didPop(result);
    }
    controller.reverse().then((_) {
      didComplete(result);
    });
    return true;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget buildPage(BuildContext context) {
    final Widget page = builder(context);
    final RouteTransitionsBuilder? transitionBuilder = this.transitionBuilder;
    if (transitionBuilder == null) {
      return page;
    }
    return transitionBuilder(
      context,
      _animation,
      _kAlwaysDismissedAnimation,
      page,
    );
  }
}

/// A widget that manages a stack of routes in an [Overlay].
class Navigator extends StatefulWidget {
  /// Creates a navigator with named route configuration.
  const Navigator({
    super.key,
    this.initialRoute = '/',
    this.routes = const <String, WidgetBuilder>{},
    this.onGenerateRoute,
    this.onUnknownRoute,
  });

  /// The route name used to resolve the first route.
  final String initialRoute;

  /// A map of route names to widget builders.
  final Map<String, WidgetBuilder> routes;

  /// Called to lazily create routes not found in [routes].
  final RouteFactory? onGenerateRoute;

  /// Called when a route cannot be resolved by [routes] or [onGenerateRoute].
  final RouteFactory? onUnknownRoute;

  /// Finds the nearest [NavigatorState] from [context].
  ///
  /// If [rootNavigator] is `true`, returns the furthest ancestor navigator.
  /// Throws a [StateError] if no navigator is found.
  static NavigatorState of(BuildContext context, {bool rootNavigator = false}) {
    final NavigatorState? result = maybeOf(
      context,
      rootNavigator: rootNavigator,
    );
    if (result == null) {
      throw StateError('No Navigator found in context.');
    }
    return result;
  }

  /// Finds a [NavigatorState] from [context], or returns `null` when absent.
  ///
  /// If [rootNavigator] is `true`, returns the furthest ancestor navigator.
  static NavigatorState? maybeOf(
    BuildContext context, {
    bool rootNavigator = false,
  }) {
    if (!rootNavigator) {
      final _NavigatorScope? scope = context
          .dependOnInheritedWidgetOfExactType<_NavigatorScope>();
      return scope?.state;
    }

    NavigatorState? result;
    context.visitAncestorElements((element) {
      final dynamic widget = element.widget;
      if (widget is _NavigatorScope) {
        result = widget.state;
      }
      return true;
    });
    return result;
  }

  @override
  State<Navigator> createState() => NavigatorState();
}

class NavigatorState extends State<Navigator> {
  final OverlayController _overlayController = OverlayController();
  final List<Route<dynamic>> _history = <Route<dynamic>>[];

  @override
  void initState() {
    super.initState();
    final Route<dynamic>? initialRoute = _routeNamed(
      RouteSettings(name: widget.initialRoute),
    );
    if (initialRoute == null) {
      throw StateError(
        'Failed to resolve initial route "${widget.initialRoute}".',
      );
    }
    _installRoute(initialRoute, insertIntoOverlay: false);
  }

  @override
  void dispose() {
    for (final Route<dynamic> route in _history.reversed) {
      route.overlayEntry.remove();
      route.dispose();
    }
    _history.clear();
    super.dispose();
  }

  /// Whether there is at least one route below the current route.
  bool canPop() => _history.length > 1;

  /// The top-most active route, or `null` when the stack is empty.
  Route<dynamic>? get currentRoute =>
      _history.isNotEmpty ? _history.last : null;

  /// Pushes [route] on top of the navigation stack.
  ///
  /// Returns a future that completes when the route is popped.
  Future<T?> push<T>(Route<T> route) {
    _installRoute(route, insertIntoOverlay: true);
    return route.popped;
  }

  /// Resolves and pushes a named route.
  Future<T?> pushNamed<T>(String name, {Object? arguments}) {
    final Route<dynamic>? route = _routeNamed(
      RouteSettings(name: name, arguments: arguments),
    );
    if (route == null) {
      throw StateError('No route defined for "$name".');
    }
    return push<T>(route as Route<T>);
  }

  /// Pops the current route with an optional [result].
  ///
  /// Returns `false` if there is no route to pop or if the route rejects
  /// the pop.
  bool pop<T>([T? result]) {
    if (!canPop()) {
      return false;
    }
    final Route<dynamic> route = _history.removeLast();
    final bool popped = route.didPop(result);
    if (!popped) {
      _history.add(route);
      return false;
    }
    route.popped.whenComplete(() {
      route.overlayEntry.remove();
      route.dispose();
    });
    return true;
  }

  Route<dynamic>? _routeNamed(RouteSettings settings) {
    final WidgetBuilder? builder = widget.routes[settings.name];
    if (builder != null) {
      return PageRoute<dynamic>(builder: builder, settings: settings);
    }
    final Route<dynamic>? generated = widget.onGenerateRoute?.call(settings);
    if (generated != null) {
      return generated;
    }
    return widget.onUnknownRoute?.call(settings);
  }

  void _installRoute(Route<dynamic> route, {required bool insertIntoOverlay}) {
    route.install(this);
    _history.add(route);
    if (insertIntoOverlay) {
      if (_overlayController.mounted) {
        _overlayController.insert(route.overlayEntry);
      }
      route.didPush();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _NavigatorScope(
      state: this,
      child: Overlay(
        controller: _overlayController,
        initialEntries: _history
            .map((Route<dynamic> r) => r.overlayEntry)
            .toList(growable: false),
      ),
    );
  }
}

class _NavigatorScope extends InheritedWidget {
  const _NavigatorScope({required this.state, required super.child});

  final NavigatorState state;

  @override
  bool updateShouldNotify(_NavigatorScope oldWidget) =>
      state != oldWidget.state;
}
