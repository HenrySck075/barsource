# BarSource Video Editor

A declarative, Flutter-inspired video editor library with a high-performance C++ backend. Build interactive video compositions with widgets, animations, and real-time rendering.

## Features

- **Flutter-inspired API** - Familiar widget-based architecture for building video compositions
- **Animation System** - Full-featured animation controllers with curves and tweens
- **Video/Audio Clips** - Embed and manipulate video and audio tracks
- **Rich Transitions** - Fade, slide, scale, and rotation transitions with custom animations
- **Animated Lists** - Build dynamic, animated list compositions with insert/remove animations
- **Text Rendering** - High-quality text layout with styling support
- **Layout System** - Flex, Stack, and alignment-based layouts
- **High Performance** - Skia backend for fast rendering and processing

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  barsource:
    path: ../dart
```

## Quick Start

Here's a simple example that demonstrates animations and video playback:

```dart
import 'package:barsource/barsource.dart';

class MyVideoComposition extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _MyVideoCompositionState();
}

class _MyVideoCompositionState extends State<MyVideoComposition> {
  late final ListController<String> _controller;

  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final CurvedAnimation _slideCurve;
  late final AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();

    _controller = ListController<String>([]);
    _fadeCtrl = AnimationController(
      duration: Duration(seconds: 1),
    )..forward();
    
    _slideCtrl = AnimationController(
      duration: Duration(milliseconds: 500),
    );
    _slideCurve = CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOut,
    );
    _slideCtrl.forward();
    
    _rotateCtrl = AnimationController(
      duration: Duration(seconds: 2),
    )..forward();

    // Scheduled updates with engine timer
    EngineTimer(Duration(seconds: 1), () => _controller.insert(0, "hi"));
    EngineTimer(Duration(seconds: 2), () => _controller.insert(1, "hello"));
    EngineTimer(Duration(seconds: 3), () => _controller.removeAt(0));
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _slideCurve.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Video background
        VideoClip(source: "sample_video_720p.mp4"),
        
        Column(
          children: [
            // Fade in animation
            FadeTransition(
              opacity: _fadeCtrl.drive(CurveTween(
                curve: Curves.easeIn,
              )),
              child: Container(
                width: 200,
                height: 200,
                color: Color(0xFFFF0000),
              ),
            ),
            
            // Slide in animation
            SlideTransition(
              offset: _slideCurve.drive(
                Tween<Offset>(
                  begin: Offset(-1.0, 0.0),
                  end: Offset(0.0, 0.0),
                ),
              ),
              child: Container(
                width: 100,
                height: 100,
                color: Color(0xFF00FF00),
              ),
            ),
            
            // Rotation animation
            RotationTransition(
              turns: _rotateCtrl.drive(
                CurveTween(curve: Curves.easeInOut),
              ),
              alignment: Alignment.center,
              child: Image.file(
                "kaho.webp",
                targetWidth: 80,
                targetHeight: 80,
              ),
            ),
            
            Text(text: "Hello World"),
          ],
        ),
        
        // Animated list
        AnimatedList<String>(
          listController: _controller,
          clipBehavior: Clip.hardEdge,
          itemBuilder: (context, data, anim) {
            return SlideTransition(
              offset: CurvedAnimation(
                parent: anim,
                curve: Curves.easeOut,
              ).drive(
                Tween<Offset>(
                  begin: Offset(1.0, 0.0),
                  end: Offset(0.0, 0.0),
                ),
              ),
              child: Container(
                width: 200,
                height: 80,
                color: Color(0xFF363636),
                child: Text(text: data),
              ),
            );
          },
        ),
      ],
    );
  }
}
```
## Examples

Check the [example](../example) directory for a complete working example with video playback, animations, and dynamic lists.

## Platform Support

- **Dart**: 3.10.0 and above
- **Backend**: C++ renderer with FFI bindings

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
