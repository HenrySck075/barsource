import 'dart:async';

import 'package:meta/meta.dart';

import 'framework.dart';
import 'overlay.dart';

@immutable
class RouteSettings {
  const RouteSettings({this.name, this.arguments});

  final String? name;
  final Object? arguments;
}

typedef RouteFactory = Route<dynamic>? Function(RouteSettings settings);

abstract class Route<T> {
  Route({RouteSettings? settings})
    : settings = settings ?? const RouteSettings();

  final RouteSettings settings;

  NavigatorState? _navigator;
  final Completer<T?> _popCompleter = Completer<T?>();
  late final OverlayEntry _overlayEntry = createOverlayEntry();

  NavigatorState? get navigator => _navigator;
  bool get isActive => _navigator != null;
  Future<T?> get popped => _popCompleter.future;
  OverlayEntry get overlayEntry => _overlayEntry;

  bool get opaque => true;
  bool get maintainState => true;

  @protected
  Widget buildPage(BuildContext context);

  @protected
  OverlayEntry createOverlayEntry() {
    return OverlayEntry(
      builder: buildPage,
      opaque: opaque,
      maintainState: maintainState,
    );
  }

  @mustCallSuper
  void install(NavigatorState navigator) {
    if (_navigator != null) {
      throw StateError('Route is already installed in a Navigator.');
    }
    _navigator = navigator;
  }

  @mustCallSuper
  bool didPop(T? result) {
    didComplete(result);
    return true;
  }

  @mustCallSuper
  void didComplete(T? result) {
    if (!_popCompleter.isCompleted) {
      _popCompleter.complete(result);
    }
  }

  @mustCallSuper
  void dispose() {
    _navigator = null;
    if (!_popCompleter.isCompleted) {
      _popCompleter.complete(null);
    }
  }
}

class PageRoute<T> extends Route<T> {
  PageRoute({
    required this.builder,
    super.settings,
    bool opaque = true,
    bool maintainState = true,
  }) : _opaque = opaque,
       _maintainState = maintainState;

  final WidgetBuilder builder;
  final bool _opaque;
  final bool _maintainState;

  @override
  bool get opaque => _opaque;

  @override
  bool get maintainState => _maintainState;

  @override
  Widget buildPage(BuildContext context) => builder(context);
}

class Navigator extends StatefulWidget {
  const Navigator({
    super.key,
    this.initialRoute = '/',
    this.routes = const <String, WidgetBuilder>{},
    this.onGenerateRoute,
    this.onUnknownRoute,
  });

  final String initialRoute;
  final Map<String, WidgetBuilder> routes;
  final RouteFactory? onGenerateRoute;
  final RouteFactory? onUnknownRoute;

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

  bool canPop() => _history.length > 1;

  Route<dynamic>? get currentRoute =>
      _history.isNotEmpty ? _history.last : null;

  Future<T?> push<T>(Route<T> route) {
    _installRoute(route, insertIntoOverlay: true);
    return route.popped;
  }

  Future<T?> pushNamed<T>(String name, {Object? arguments}) {
    final Route<dynamic>? route = _routeNamed(
      RouteSettings(name: name, arguments: arguments),
    );
    if (route == null) {
      throw StateError('No route defined for "$name".');
    }
    return push<T>(route as Route<T>);
  }

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
    route.overlayEntry.remove();
    route.dispose();
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
    if (insertIntoOverlay && _overlayController.mounted) {
      _overlayController.insert(route.overlayEntry);
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
