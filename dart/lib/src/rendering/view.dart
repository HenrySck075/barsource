import 'object.dart';
import 'box.dart';
import '../foundation/geometry.dart';

class ViewConfiguration {
  const ViewConfiguration({
    required this.size,
  });

  final Size size;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ViewConfiguration &&
        other.size == size;
  }

  @override
  int get hashCode => size.hashCode;
}

class RenderView extends RenderBox with RenderObjectWithChildMixin {
  RenderView({
    RenderBox? child,
    required ViewConfiguration configuration,
  }) : _configuration = configuration {
    if (child != null) {
      this.child = child;
    }
  }

  ViewConfiguration _configuration;
  ViewConfiguration get configuration => _configuration;
  set configuration(ViewConfiguration value) {
    if (_configuration == value) return;
    _configuration = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    // RenderView is the root, so it ignores incoming constraints and relies
    // on its configuration.
    
    // However, we must ensure we don't ignore the layout call entirely.
    
    if (child != null) {
      child!.layout(BoxConstraints(
        minWidth: _configuration.size.width,
        maxWidth: _configuration.size.width,
        minHeight: _configuration.size.height,
        maxHeight: _configuration.size.height,
      ));
    } 

    size = constraints.smallest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }
}
