import 'package:tennoji/src/painting/basic_types.dart';

import '../rendering/flex_render.dart';
import '../rendering/object.dart';
import 'framework.dart';

/// A widget that displays its children in a one-dimensional array (flex layout).
class Flex extends MultiChildRenderObjectWidget {
  const Flex({
    super.key,
    required this.direction,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    super.children,
  });

  final Axis direction;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderFlex(
        direction: direction,
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
      );
}

/// A widget that lays out children horizontally.
class Row extends Flex {
  const Row({
    super.key,
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    super.mainAxisSize,
    super.children,
  }) : super(direction: Axis.horizontal);
}

/// A widget that lays out children vertically.
class Column extends Flex {
  const Column({
    super.key,
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    super.mainAxisSize,
    super.children,
  }) : super(direction: Axis.vertical);
}

/// A widget that expands a child of a [Row], [Column], or [Flex].
class Expanded extends SingleChildRenderObjectWidget {
  const Expanded({
    super.key,
    this.flex = 1,
    required Widget super.child,
  });

  final int flex;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderExpanded(flex: flex, fit: FlexFit.tight);
}

/// A widget like [Expanded] but does not force the child to fill the space.
class Flexible extends SingleChildRenderObjectWidget {
  const Flexible({
    super.key,
    this.flex = 1,
    this.fit = FlexFit.loose,
    required Widget super.child,
  });

  final int flex;
  final FlexFit fit;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderExpanded(flex: flex, fit: fit);
}
