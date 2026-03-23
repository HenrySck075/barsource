import 'package:tennoji/tennoji.dart';

abstract class InheritedTheme extends InheritedWidget {
  const InheritedTheme({
    super.key,
    required super.child,
  });

  Widget wrap(BuildContext context, Widget child);

  static Widget captureAll(BuildContext context, Widget child, {BuildContext? to}) {
    return capture(from: context, to: to).wrap(child);
  }

  static CapturedThemes capture({
    required BuildContext from,
    BuildContext? to,
  }) {
    if (from == to) {
      return CapturedThemes._([]);
    }
    final themes = <InheritedTheme>[];
    from.visitAncestorElements((element) {
      if (element.widget is InheritedTheme) {
        themes.add(element.widget as InheritedTheme);
      }
      return true;
    });
    if (to != null) {
      to.visitAncestorElements((element) {
        if (element.widget is InheritedTheme) {
          themes.remove(element.widget as InheritedTheme);
        }
        return true;
      });
    }
    return CapturedThemes._(themes);
  }
  
  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}


class CapturedThemes {
  const CapturedThemes._(this.themes);

  final List<InheritedTheme> themes;

  Widget wrap(Widget child) {
    return _CaptureAll(themes: themes, child: child);
  }
}


class _CaptureAll extends StatelessWidget {
  const _CaptureAll({
    required this.themes,
    required this.child,
  });

  final List<InheritedTheme> themes;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    for (final theme in themes) {
      result = theme.wrap(context, result);
    }
    return result;
  }
}
