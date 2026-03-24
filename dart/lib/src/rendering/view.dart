import 'object.dart';
import 'box.dart';
import 'time_box.dart';
import '../foundation/geometry.dart';

class ViewConfiguration {
  const ViewConfiguration({
    required this.size,
    required this.currentTime,
  });

  final Size size;
  final Duration currentTime;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ViewConfiguration &&
        other.size == size &&
        other.currentTime == currentTime;
  }

  @override
  int get hashCode => Object.hash(size, currentTime);
}

class RenderView extends RenderObject with ContainerRenderObjectMixin {
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

  RenderBox? get child => children.isNotEmpty ? children.first as RenderBox? : null;
  set child(RenderBox? value) {
    if (children.isNotEmpty) {
      final oldChild = children.first;
      if (oldChild == value) return;
      remove(oldChild);
    }
    if (value != null) {
      add(value);
    }
  }

  @override
  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    // RenderView is the root, so it ignores incoming constraints and relies
    // on its configuration.
    
    // However, we must ensure we don't ignore the layout call entirely.
    
    if (child != null) {
      child!.layout(TimeBoxConstraints(
        currentTime: _configuration.currentTime,
        minWidth: _configuration.size.width,
        maxWidth: _configuration.size.width,
        minHeight: _configuration.size.height,
        maxHeight: _configuration.size.height,
      ));
    }
    
    // In RenderObject, layout() sets _needsLayout = false.
    // Since we are overriding it, we must do it ourselves or call super.
    // But RenderObject.layout implementation is just setting flag to false.
    // We can just call super.layout(constraints) at the end.
    super.layout(constraints);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }
}
