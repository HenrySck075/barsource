import 'package:barsource/src/painting/basic_types.dart';
import 'package:barsource/src/rendering/flex.dart';

import '../rendering/object.dart';
import 'framework.dart';

/// A widget that displays its children in a one-dimensional array (flex layout).
class Flex extends MultiChildRenderObjectWidget {
  const Flex({
    super.key,
    required this.direction,
    this.mainAxisAlignment = .start,
    this.crossAxisAlignment = .center,
    this.mainAxisSize = .max,
    this.clipBehavior = .none,
    super.children,
  });

  final Axis direction;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final Clip clipBehavior;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderFlex(
    direction: direction,
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: crossAxisAlignment,
    mainAxisSize: mainAxisSize,
    clipBehavior: clipBehavior,
  );
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    final flex = renderObject as RenderFlex;
    flex
      ..direction = direction
      ..mainAxisAlignment = mainAxisAlignment
      ..crossAxisAlignment = crossAxisAlignment
      ..mainAxisSize = mainAxisSize
      ..clipBehavior = clipBehavior;
  }
}

/// A widget that lays out children horizontally.
class Row extends Flex {
  const Row({
    super.key,
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    super.mainAxisSize,
    super.clipBehavior,
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
    super.clipBehavior,
    super.children,
  }) : super(direction: Axis.vertical);
}

/// A widget that expands a child of a [Row], [Column], or [Flex].
class Flexible extends ParentDataWidget<FlexParentData> {
  Flexible({super.key, this.flex = 1, this.fit = .loose, required super.child});

  final int flex;
  final FlexFit fit;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is FlexParentData);
    final parentData = renderObject.parentData! as FlexParentData;
    var needsLayout = false;

    if (parentData.flex != flex) {
      parentData.flex = flex;
      needsLayout = true;
    }

    if (parentData.fit != fit) {
      parentData.fit = fit;
      needsLayout = true;
    }

    if (needsLayout) {
      renderObject.parent?.markNeedsLayout();
    }
  }
}

class Expanded extends Flexible {
  Expanded({super.key, super.flex, required super.child}) : super(fit: .tight);
}
