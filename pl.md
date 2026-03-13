# libtennoji ~~ Video Editor Library

A declarative, Flutter-inspired video editor library in Dart with a C++ backend powered by **Skia** (GPU rendering) and **FFmpeg libav** (GPU encode/decode).

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Dart (User API)                    │
│                                                     │
│  Widget Tree  →  Element Tree  →  RenderObject Tree │
│  (immutable)    (lifecycle)       (layout + paint)   │
└───────────────────────┬─────────────────────────────┘
                        │  dart:ffi
┌───────────────────────▼─────────────────────────────┐
│                  C++ Engine Core                     │
│                                                     │
│  ┌──────────┐  ┌───────────┐  ┌──────────────────┐  │
│  │  Skia    │  │  libav*   │  │  Render Engine   │  │
│  │ (render) │  │ (decode/  │  │  (frame pump,    │  │
│  │          │  │  encode)  │  │   composite)     │  │
│  └──────────┘  └───────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Export Model

```dart
// Just like runApp(), but for exporting
render(
  MyComposition(),
  RenderConfig(
    output: 'output.mp4',
    duration: Duration(seconds: 30),
    fps: 60,
    resolution: Size(1920, 1080),
    codec: VideoCodec.h264(),
    audioCodec: AudioCodec.aac(),
  ),
);
```

The engine drives the clock from 0 → duration, calling build/layout/paint each frame.

### Three Trees (same as Flutter)

| Tree | Role | Mutability |
|------|------|------------|
| **Widget** | Declarative description. Cheap to rebuild. | Immutable |
| **Element** | Lifecycle, reconciliation. | Mutable, long-lived |
| **RenderObject** | Layout + paint (Skia). | Mutable, long-lived |

---

## 2. Directory / Package Layout

```
libtennoji/
├── dart/                          # Pure Dart package (pub)
│   ├── lib/
│   │   ├── src/
│   │   │   ├── foundation/        # Core primitives
│   │   │   │   ├── key.dart
│   │   │   │   ├── change_notifier.dart
│   │   │   │   └── geometry.dart         # Size, Offset, Rect
│   │   │   ├── widgets/           # Widget layer (declarative API)
│   │   │   │   ├── framework.dart        # Widget, StatelessWidget, StatefulWidget, State<T>
│   │   │   │   ├── basic.dart            # Container, SizedBox, Padding
│   │   │   │   ├── stack.dart            # Stack (layered children, composited)
│   │   │   │   ├── sequence.dart         # Sequence (time-ordered children)
│   │   │   │   ├── clip.dart             # VideoClip, AudioClip, ImageClip
│   │   │   │   └── render_widget.dart    # RenderObjectWidget base classes
│   │   │   ├── elements/          # Element layer (reconciliation)
│   │   │   │   ├── framework.dart        # Element, ComponentElement, RenderObjectElement
│   │   │   │   └── media_element.dart    # Media-aware element lifecycle
│   │   │   ├── rendering/         # RenderObject layer
│   │   │   │   ├── object.dart           # RenderObject base, Constraints, PaintingContext
│   │   │   │   ├── box.dart              # RenderBox (2D spatial layout)
│   │   │   │   ├── time_box.dart         # TimeBoxConstraints, RenderTimeBox
│   │   │   │   ├── media_render.dart     # RenderVideoClip, RenderAudioClip
│   │   │   │   ├── stack_render.dart     # RenderStack
│   │   │   │   ├── sequence_render.dart  # RenderSequence
│   │   │   │   └── pipeline_owner.dart   # Drives layout → paint → composite
│   │   │   ├── engine/            # FFI bindings + engine control
│   │   │   │   ├── bindings.dart         # Auto-generated (ffigen) C bindings
│   │   │   │   ├── engine.dart           # Engine, init/shutdown
│   │   │   │   ├── texture_registry.dart # GPU texture handle management
│   │   │   │   └── render_controller.dart # render() function, frame pump
│   │   │   └── painting/         # Paint/Canvas wrappers
│   │   │       ├── canvas.dart           # Canvas (wraps Skia commands)
│   │   │       └── paint.dart            # Paint, Color, etc
│   │   └── tennoji.dart           # Barrel export
│   ├── test/
│   ├── pubspec.yaml
│   ├── ffigen.yaml                    # dart ffigen config
│   └── analysis_options.yaml
│
├── native/                        # C++ engine (built as shared lib)
│   ├── CMakeLists.txt
│   ├── include/
│   │   └── tennoji/
│   │       ├── engine.h               # Public C API (FFI boundary)
│   │       ├── types.h                # Shared struct definitions
│   │       └── export.h               # DLL export macros
│   └── src/
│       ├── engine.cpp                 # Engine lifecycle
│       ├── renderer/
│       │   ├── skia_surface.cpp       # SkSurface management (GPU context)
│       │   ├── compositor.cpp         # Composites layer tree
│       │   └── canvas.cpp             # Canvas command recording
│       ├── media/
│       │   ├── decoder.cpp            # AVCodec hw-accel decode
│       │   ├── encoder.cpp            # AVCodec hw-accel encode (NVENC/VAAPI/VT)
│       │   ├── demuxer.cpp            # AVFormatContext demux
│       │   ├── muxer.cpp              # AVFormatContext mux (export)
│       │   ├── frame_pool.cpp         # Ring buffer of decoded frames
│       │   └── audio_mixer.cpp        # Audio mixing / resampling (SwrContext)
│       └── util/
│           ├── gpu_context.cpp        # EGL/Metal/Vulkan context setup
│           └── thread_pool.cpp        # Work-stealing pool for decode/encode
│
└── pl.md                          # You are here
```

---

THE FOLLOWING DOCS ARE FOR THE INITIAL REVISION INSTRUCTIONS. Use only for API references and not for actual instructions for anything not covered.
---

# DART TEAM SPEC

Work independently. Implement **exactly** these APIs. Do not add new public methods/classes.

## 3.1 Foundation (`lib/src/foundation/`)

### `key.dart`
```dart
@immutable
abstract class Key {
  const Key();
}

class ValueKey<T> extends Key {
  const ValueKey(this.value);
  final T value;
}

class ObjectKey extends Key {
  const ObjectKey(this.value);
  final Object value;
}
```

### `geometry.dart`
```dart
@immutable
class Size {
  const Size(this.width, this.height);
  final double width;
  final double height;
  static const Size zero = Size(0, 0);
}

@immutable
class Offset {
  const Offset(this.dx, this.dy);
  final double dx;
  final double dy;
  static const Offset zero = Offset(0, 0);
}

@immutable
class Rect {
  const Rect.fromLTWH(this.left, this.top, this.width, this.height);
  final double left;
  final double top;
  final double width;
  final double height;
}
```

### `change_notifier.dart`
```dart
class ChangeNotifier {
  final List<VoidCallback> _listeners = [];
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  void notifyListeners();
  void dispose();
}
```

## 3.2 Painting (`lib/src/painting/`)

### `paint.dart`
```dart
class Color {
  const Color(int value);
  final int value;
  int get alpha => (value >> 24) & 0xFF;
  int get red => (value >> 16) & 0xFF;
  int get green => (value >> 8) & 0xFF;
  int get blue => value & 0xFF;
}

class Paint {
  Color color = const Color(0xFF000000);
  double strokeWidth = 1.0;
  bool isAntiAlias = true;
}
```

### `canvas.dart`
```dart
// Wrapper around native canvas handle
class Canvas {
  Canvas(this._handle);
  final int _handle; // native pointer

  void drawRect(Rect rect, Paint paint) {
    // FFI call to tennoji_canvas_draw_rect
  }

  void drawImage(int textureId, Offset offset, Paint paint) {
    // FFI call to tennoji_canvas_draw_image
  }

  void save();
  void restore();
  void translate(double dx, double dy);
  void scale(double sx, double sy);
}
```

## 3.3 Rendering (`lib/src/rendering/`)

### `object.dart`
```dart
abstract class Constraints {
  const Constraints();
  bool get isTight;
}

class BoxConstraints extends Constraints {
  const BoxConstraints({
    this.minWidth = 0.0,
    this.maxWidth = double.infinity,
    this.minHeight = 0.0,
    this.maxHeight = double.infinity,
  });
  final double minWidth, maxWidth, minHeight, maxHeight;
  
  BoxConstraints tighten({double? width, double? height});
  static const BoxConstraints expand = BoxConstraints(
    minWidth: double.infinity,
    maxWidth: double.infinity,
    minHeight: double.infinity,
    maxHeight: double.infinity,
  );
}

class PaintingContext {
  PaintingContext(this.canvas);
  final Canvas canvas;
  void paintChild(RenderObject child, Offset offset);
}

abstract class RenderObject {
  RenderObject? parent;
  bool _needsLayout = true;
  bool _needsPaint = true;
  Size? _size;
  
  bool get needsLayout => _needsLayout;
  bool get needsPaint => _needsPaint;
  Size get size => _size!;
  
  void markNeedsLayout();
  void markNeedsPaint();
  void layout(Constraints constraints, {bool parentUsesSize = false});
  void paint(PaintingContext context, Offset offset);
  void attach(PipelineOwner owner);
  void detach();
}
```

### `box.dart`
```dart
abstract class RenderBox extends RenderObject {
  @override
  void layout(covariant BoxConstraints constraints, {bool parentUsesSize = false}) {
    // Call performLayout(), set _size, clear _needsLayout
  }
  
  void performLayout(); // subclass implements
}
```

### `time_box.dart`
```dart
class TimeBoxConstraints extends BoxConstraints {
  const TimeBoxConstraints({
    required this.currentTime,
    super.minWidth,
    super.maxWidth,
    super.minHeight,
    super.maxHeight,
  });
  final Duration currentTime;
}

abstract class RenderTimeBox extends RenderBox {
  @override
  void layout(covariant TimeBoxConstraints constraints, {bool parentUsesSize = false});
}
```

### `pipeline_owner.dart`
```dart
class PipelineOwner {
  final List<RenderObject> _nodesNeedingLayout = [];
  final List<RenderObject> _nodesNeedingPaint = [];
  
  void requestLayout(RenderObject node);
  void requestPaint(RenderObject node);
  void flushLayout();
  void flushPaint(Canvas canvas);
}
```

### `media_render.dart`
```dart
class RenderVideoClip extends RenderTimeBox {
  RenderVideoClip({
    required String source,
    Duration trimStart = Duration.zero,
    Duration? trimEnd,
    double playbackSpeed = 1.0,
  });
  
  int? _decoderHandle;
  int? _textureId;
  
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // FFI: _decoderHandle = tennoji_decoder_open(...)
  }
  
  @override
  void detach() {
    // FFI: tennoji_decoder_close(_decoderHandle)
    // FFI: tennoji_texture_release(_textureId)
    super.detach();
  }
  
  @override
  void performLayout() {
    // Use constraints, set size
  }
  
  @override
  void paint(PaintingContext context, Offset offset) {
    // FFI: tennoji_decoder_seek(currentTime)
    // FFI: _textureId = tennoji_decoder_get_texture()
    // context.canvas.drawImage(_textureId, offset, Paint())
  }
}

class RenderAudioClip extends RenderTimeBox {
  RenderAudioClip({
    required String source,
    Duration trimStart = Duration.zero,
    Duration? trimEnd,
    double volume = 1.0,
  });
  
  int? _decoderHandle;
  
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    // FFI: _decoderHandle = tennoji_audio_decoder_open(...)
  }
  
  @override
  void detach() {
    // FFI: tennoji_decoder_close(_decoderHandle)
    super.detach();
  }
  
  @override
  void performLayout() {
    size = Size.zero; // audio has no visual size
  }
  
  @override
  void paint(PaintingContext context, Offset offset) {
    // no-op, audio handled by mixer
    // But register with mixer: FFI call to tell engine about this audio source
  }
}
```

### `stack_render.dart`
```dart
class RenderStack extends RenderBox with ContainerRenderObjectMixin {
  // Lays out all children with same constraints, paints in order
  @override
  void performLayout() {
    // Give each child the incoming constraints
    // Size = max of all children
  }
  
  @override
  void paint(PaintingContext context, Offset offset) {
    // Paint each child at offset
  }
}
```

### `sequence_render.dart`
```dart
class RenderSequence extends RenderTimeBox with ContainerRenderObjectMixin {
  // Lays out children sequentially in time
  @override
  void performLayout() {
    Duration elapsed = Duration.zero;
    for (var child in children) {
      // Layout child with time offset
      elapsed += child.duration; // assume children expose duration
    }
  }
  
  @override
  void paint(PaintingContext context, Offset offset) {
    // Find active child at currentTime, paint only that
  }
}
```

## 3.4 Widgets (`lib/src/widgets/`)

### `framework.dart`
```dart
@immutable
abstract class Widget {
  const Widget({this.key});
  final Key? key;
  Element createElement();
}

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});
  Widget build(BuildContext context);
  @override
  Element createElement() => StatelessElement(this);
}

abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
  State createState();
  @override
  Element createElement() => StatefulElement(this);
}

abstract class State<T extends StatefulWidget> {
  T get widget => _widget!;
  T? _widget;
  BuildContext get context => _element!;
  StatefulElement? _element;
  
  void initState() {}
  void didUpdateWidget(covariant T oldWidget) {}
  void dispose() {}
  Widget build(BuildContext context);
  void setState(VoidCallback fn) {
    fn();
    _element!.markNeedsBuild();
  }
}

abstract class RenderObjectWidget extends Widget {
  const RenderObjectWidget({super.key});
  RenderObject createRenderObject(BuildContext context);
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {}
  @override
  Element createElement() => RenderObjectElement(this);
}

abstract class LeafRenderObjectWidget extends RenderObjectWidget {
  const LeafRenderObjectWidget({super.key});
}

abstract class SingleChildRenderObjectWidget extends RenderObjectWidget {
  const SingleChildRenderObjectWidget({super.key, this.child});
  final Widget? child;
}

abstract class MultiChildRenderObjectWidget extends RenderObjectWidget {
  const MultiChildRenderObjectWidget({super.key, this.children = const []});
  final List<Widget> children;
}
```

### `render_widget.dart`
```dart
abstract class BuildContext {
  Widget get widget;
}
```

### `basic.dart`
```dart
class Container extends SingleChildRenderObjectWidget {
  const Container({
    super.key,
    this.width,
    this.height,
    this.color,
    super.child,
  });
  final double? width;
  final double? height;
  final Color? color;
  
  @override
  RenderObject createRenderObject(BuildContext context) => RenderContainer();
}

class SizedBox extends SingleChildRenderObjectWidget {
  const SizedBox({super.key, this.width, this.height, super.child});
  final double? width;
  final double? height;
  
  @override
  RenderObject createRenderObject(BuildContext context) => RenderSizedBox();
}

class Padding extends SingleChildRenderObjectWidget {
  const Padding({super.key, required this.padding, super.child});
  final EdgeInsets padding;
  
  @override
  RenderObject createRenderObject(BuildContext context) => RenderPadding();
}

class EdgeInsets {
  const EdgeInsets.all(double value);
  const EdgeInsets.only({double left, double top, double right, double bottom});
  final double left, top, right, bottom;
}
```

### `stack.dart`
```dart
class Stack extends MultiChildRenderObjectWidget {
  const Stack({super.key, super.children});
  
  @override
  RenderStack createRenderObject(BuildContext context) => RenderStack();
}
```

### `sequence.dart`
```dart
class Sequence extends MultiChildRenderObjectWidget {
  const Sequence({super.key, super.children});
  
  @override
  RenderSequence createRenderObject(BuildContext context) => RenderSequence();
}
```

### `clip.dart`
```dart
class VideoClip extends LeafRenderObjectWidget {
  const VideoClip({
    super.key,
    required this.source,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.playbackSpeed = 1.0,
  });
  final String source;
  final Duration trimStart;
  final Duration? trimEnd;
  final double playbackSpeed;
  
  @override
  RenderVideoClip createRenderObject(BuildContext context) => RenderVideoClip(
    source: source,
    trimStart: trimStart,
    trimEnd: trimEnd,
    playbackSpeed: playbackSpeed,
  );
  
  @override
  void updateRenderObject(BuildContext context, RenderVideoClip renderObject) {
    // Update properties if changed
  }
}

class AudioClip extends LeafRenderObjectWidget {
  const AudioClip({
    super.key,
    required this.source,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.volume = 1.0,
  });
  final String source;
  final Duration trimStart;
  final Duration? trimEnd;
  final double volume;
  
  @override
  RenderAudioClip createRenderObject(BuildContext context) => RenderAudioClip(
    source: source,
    trimStart: trimStart,
    trimEnd: trimEnd,
    volume: volume,
  );
}
```

## 3.5 Elements (`lib/src/elements/`)

### `framework.dart`
```dart
abstract class Element implements BuildContext {
  Element(this._widget);
  Widget _widget;
  @override
  Widget get widget => _widget;
  
  Element? _parent;
  RenderObject? _renderObject;
  bool _active = false;
  
  void mount(Element? parent, Object? newSlot);
  void update(covariant Widget newWidget) {
    _widget = newWidget;
  }
  void unmount();
  void markNeedsBuild();
  Widget build();
}

class ComponentElement extends Element {
  ComponentElement(super.widget);
  Element? _child;
  
  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _firstBuild();
  }
  
  void _firstBuild() {
    rebuild();
  }
  
  void rebuild() {
    Widget built = build();
    _child = updateChild(_child, built, null);
  }
  
  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    // Reconciliation logic
  }
}

class StatelessElement extends ComponentElement {
  StatelessElement(StatelessWidget super.widget);
  
  @override
  Widget build() => (widget as StatelessWidget).build(this);
}

class StatefulElement extends ComponentElement {
  StatefulElement(StatefulWidget super.widget) {
    _state = (widget as StatefulWidget).createState()
      .._element = this
      .._widget = widget as StatefulWidget;
  }
  
  late State _state;
  
  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _state.initState();
  }
  
  @override
  Widget build() => _state.build(this);
}

class RenderObjectElement extends Element {
  RenderObjectElement(RenderObjectWidget super.widget);
  
  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _renderObject = (widget as RenderObjectWidget).createRenderObject(this);
    _renderObject!.attach(/* get PipelineOwner from parent */);
  }
  
  @override
  void update(RenderObjectWidget newWidget) {
    super.update(newWidget);
    newWidget.updateRenderObject(this, _renderObject!);
  }
  
  @override
  void unmount() {
    _renderObject!.detach();
    super.unmount();
  }
}
```

## 3.6 Engine (`lib/src/engine/`)

### `bindings.dart`
Auto-generated by `ffigen`. Do not edit manually.

### `engine.dart`
```dart
class Engine {
  Engine._();
  static Engine? _instance;
  
  static void init() {
    // FFI: tennoji_engine_create()
    _instance = Engine._();
  }
  
  static Engine get instance => _instance!;
  
  void shutdown() {
    // FFI: tennoji_engine_destroy()
  }
}
```

### `render_controller.dart`
```dart
class RenderConfig {
  const RenderConfig({
    required this.output,
    required this.duration,
    required this.fps,
    required this.resolution,
    this.codec = const VideoCodec.h264(),
    this.audioCodec = const AudioCodec.aac(),
  });
  final String output;
  final Duration duration;
  final int fps;
  final Size resolution;
  final VideoCodec codec;
  final AudioCodec audioCodec;
}

class VideoCodec {
  const VideoCodec.h264();
  const VideoCodec.h265();
}

class AudioCodec {
  const AudioCodec.aac();
  const AudioCodec.opus();
}

void render(Widget root, RenderConfig config) {
  Engine.init();
  
  // Build the tree
  final rootElement = root.createElement();
  rootElement.mount(null, null);
  
  final pipelineOwner = PipelineOwner();
  final renderRoot = rootElement._renderObject!;
  
  // FFI: open encoder
  // FFI: tennoji_encoder_create(config.output, config.codec, ...)
  
  final frameDuration = Duration(microseconds: 1000000 ~/ config.fps);
  Duration currentTime = Duration.zero;
  
  while (currentTime < config.duration) {
    // Layout
    final constraints = TimeBoxConstraints(
      currentTime: currentTime,
      minWidth: config.resolution.width,
      maxWidth: config.resolution.width,
      minHeight: config.resolution.height,
      maxHeight: config.resolution.height,
    );
    renderRoot.layout(constraints);
    
    // Paint
    // FFI: get canvas handle
    final canvas = Canvas(/* native handle */);
    final paintingContext = PaintingContext(canvas);
    pipelineOwner.flushLayout();
    pipelineOwner.flushPaint(canvas);
    
    // FFI: tennoji_encoder_write_frame()
    
    currentTime += frameDuration;
  }
  
  // FFI: tennoji_encoder_finalize()
  rootElement.unmount();
  Engine.instance.shutdown();
}
```

---

---

# C++ TEAM SPEC

Work independently. Implement **exactly** this C API. Do not add new public functions.

## 4.1 C API (`include/tennoji/engine.h`)

```c
#ifndef TENNOJI_ENGINE_H
#define TENNOJI_ENGINE_H

#include <stdint.h>

#ifdef _WIN32
  #ifdef TENNOJI_BUILD
    #define TENNOJI_EXPORT __declspec(dllexport)
  #else
    #define TENNOJI_EXPORT __declspec(dllimport)
  #endif
#else
  #define TENNOJI_EXPORT __attribute__((visibility("default")))
#endif

typedef struct TennojiEngine TennojiEngine;
typedef struct TennojiDecoder TennojiDecoder;
typedef struct TennojiEncoder TennojiEncoder;
typedef struct TennojiTexture TennojiTexture;
typedef struct TennojiCanvas TennojiCanvas;

typedef enum {
  TENNOJI_HW_ACCEL_AUTO,   // try NVENC/VAAPI/VT, fallback to SW
  TENNOJI_HW_ACCEL_NONE,   // software only
} TennojiHWAccel;

typedef struct {
  int32_t width;
  int32_t height;
  int32_t fps;
  const char* gpu_backend; // "vulkan", "metal", "d3d11", "opengl"
} TennojiEngineConfig;

typedef struct {
  const char* output_path;
  int32_t width;
  int32_t height;
  int32_t fps;
  const char* video_codec; // "h264", "h265"
  const char* audio_codec; // "aac", "opus"
  int32_t audio_sample_rate;
  int32_t audio_channels;
} TennojiEncoderConfig;

// Engine lifecycle
TENNOJI_EXPORT TennojiEngine* tennoji_engine_create(const TennojiEngineConfig* config);
TENNOJI_EXPORT void tennoji_engine_destroy(TennojiEngine* engine);

// Decoder (video/audio)
TENNOJI_EXPORT TennojiDecoder* tennoji_decoder_open(TennojiEngine* engine,
                                                     const char* uri,
                                                     TennojiHWAccel accel);
TENNOJI_EXPORT void tennoji_decoder_close(TennojiDecoder* decoder);
TENNOJI_EXPORT int tennoji_decoder_seek(TennojiDecoder* decoder, int64_t timestamp_us);
TENNOJI_EXPORT int tennoji_decoder_get_texture(TennojiDecoder* decoder,
                                                int64_t timestamp_us);
TENNOJI_EXPORT int64_t tennoji_decoder_duration(TennojiDecoder* decoder);

// Canvas (Skia command recording)
TENNOJI_EXPORT TennojiCanvas* tennoji_canvas_create(TennojiEngine* engine,
                                                     int32_t width,
                                                     int32_t height);
TENNOJI_EXPORT void tennoji_canvas_destroy(TennojiCanvas* canvas);
TENNOJI_EXPORT void tennoji_canvas_clear(TennojiCanvas* canvas, uint32_t color);
TENNOJI_EXPORT void tennoji_canvas_draw_rect(TennojiCanvas* canvas,
                                              float left, float top,
                                              float width, float height,
                                              uint32_t color);
TENNOJI_EXPORT void tennoji_canvas_draw_image(TennojiCanvas* canvas,
                                               int texture_id,
                                               float dx, float dy);
TENNOJI_EXPORT void tennoji_canvas_save(TennojiCanvas* canvas);
TENNOJI_EXPORT void tennoji_canvas_restore(TennojiCanvas* canvas);
TENNOJI_EXPORT void tennoji_canvas_translate(TennojiCanvas* canvas, float dx, float dy);
TENNOJI_EXPORT void tennoji_canvas_scale(TennojiCanvas* canvas, float sx, float sy);

// Texture (GPU texture handle, opaque int ID)
TENNOJI_EXPORT void tennoji_texture_release(TennojiEngine* engine, int texture_id);

// Encoder (export)
TENNOJI_EXPORT TennojiEncoder* tennoji_encoder_create(TennojiEngine* engine,
                                                       const TennojiEncoderConfig* config);
TENNOJI_EXPORT int tennoji_encoder_write_frame(TennojiEncoder* encoder,
                                                TennojiCanvas* canvas);
TENNOJI_EXPORT int tennoji_encoder_write_audio(TennojiEncoder* encoder,
                                                TennojiDecoder* audio_decoder,
                                                int64_t duration_us);
TENNOJI_EXPORT int tennoji_encoder_finalize(TennojiEncoder* encoder);
TENNOJI_EXPORT void tennoji_encoder_destroy(TennojiEncoder* encoder);

#endif // TENNOJI_ENGINE_H
```

## 4.2 Internal Architecture (C++ implementation notes)

### `src/engine.cpp`
```cpp
struct TennojiEngine {
  GrDirectContext* grContext;  // Skia GPU context
  // GPU backend (Vulkan/Metal/D3D11/OpenGL)
  // Thread pool
  // Texture registry (map<int, sk_sp<SkImage>>)
};

TennojiEngine* tennoji_engine_create(const TennojiEngineConfig* config) {
  // Init GPU backend based on config->gpu_backend
  // Create GrDirectContext
  // Init thread pool
}
```

### `src/media/decoder.cpp`
```cpp
struct TennojiDecoder {
  AVFormatContext* fmtCtx;
  AVCodecContext* videoCodecCtx;
  AVCodecContext* audioCodecCtx;
  int videoStreamIdx;
  int audioStreamIdx;
  FramePool* framePool;   // ring buffer of decoded frames
  TennojiEngine* engine;
};

TennojiDecoder* tennoji_decoder_open(...) {
  // avformat_open_input, avformat_find_stream_info
  // Find video/audio streams
  // Open codec with hw accel (av_hwdevice_ctx_create)
}

int tennoji_decoder_get_texture(TennojiDecoder* decoder, int64_t timestamp_us) {
  // Seek if needed (av_seek_frame)
  // Decode frame (avcodec_send_packet, avcodec_receive_frame)
  // Map AVFrame to SkImage (via GPU interop, e.g. MakeFromTexture for NV12)
  // Store in engine's texture registry
  // Return texture ID (int)
}
```

### `src/renderer/canvas.cpp`
```cpp
struct TennojiCanvas {
  sk_sp<SkSurface> surface;
  SkCanvas* canvas;
};

TennojiCanvas* tennoji_canvas_create(TennojiEngine* engine, int32_t w, int32_t h) {
  // Create GPU SkSurface (SkSurfaces::RenderTarget)
}

void tennoji_canvas_draw_image(TennojiCanvas* canvas, int texture_id, ...) {
  // Look up texture_id in engine's registry -> SkImage
  // canvas->drawImage(image, ...)
}
```

### `src/media/encoder.cpp`
```cpp
struct TennojiEncoder {
  AVFormatContext* fmtCtx;
  AVCodecContext* videoCodecCtx;
  AVCodecContext* audioCodecCtx;
  AVStream* videoStream;
  AVStream* audioStream;
  TennojiEngine* engine;
};

TennojiEncoder* tennoji_encoder_create(...) {
  // avformat_alloc_output_context2
  // Add video/audio streams
  // Open codecs with hw accel (NVENC/VAAPI/VT)
  // avformat_write_header
}

int tennoji_encoder_write_frame(TennojiEncoder* encoder, TennojiCanvas* canvas) {
  // Flush canvas to get SkImage
  // Convert to AVFrame (GPU memory if possible, or readPixels to CPU)
  // avcodec_send_frame, avcodec_receive_packet
  // av_interleaved_write_frame
}

int tennoji_encoder_write_audio(TennojiEncoder* enc, TennojiDecoder* dec, ...) {
  // Decode audio frames from dec
  // Resample if needed (SwrContext)
  // avcodec_send_frame, avcodec_receive_packet
  // av_interleaved_write_frame
}
```

### GPU Pipeline (zero-copy)
```
AVCodecContext (HW decode) → AVFrame (GPU memory, e.g. CUDA/VAAPI/VT)
         ↓
SkImages::MakeFromTexture → SkImage (GPU texture, no CPU copy)
         ↓
SkCanvas::drawImage → composited into SkSurface (GPU)
         ↓
AVCodecContext (HW encode) → read from GPU SkSurface
         ↓
Output file
```

## 4.3 Build System (`CMakeLists.txt`)

```cmake
cmake_minimum_required(VERSION 3.20)
project(tennoji_native CXX)
set(CMAKE_CXX_STANDARD 20)

find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED libavcodec libavformat libavutil libswresample)

set(SKIA_DIR "${CMAKE_SOURCE_DIR}/third_party/skia" CACHE PATH "Skia path")

add_library(tennoji SHARED
  src/engine.cpp
  src/renderer/canvas.cpp
  src/renderer/compositor.cpp
  src/media/decoder.cpp
  src/media/encoder.cpp
  src/media/demuxer.cpp
  src/media/muxer.cpp
  src/media/frame_pool.cpp
  src/media/audio_mixer.cpp
  src/util/gpu_context.cpp
  src/util/thread_pool.cpp
)

target_include_directories(tennoji PUBLIC include PRIVATE ${SKIA_DIR}/include)
target_link_libraries(tennoji PRIVATE ${FFMPEG_LIBRARIES} ${SKIA_DIR}/out/Release/libskia.a)

if(WIN32)
  target_link_libraries(tennoji PRIVATE d3d11 dxgi)
elseif(APPLE)
  target_link_libraries(tennoji PRIVATE "-framework Metal" "-framework VideoToolbox")
else()
  target_link_libraries(tennoji PRIVATE vulkan)
endif()
```

---

## 5. Build System

| Component | Tool | Notes |
|-----------|------|-------|
| C++ native lib | **CMake** | Fetches Skia (pre-built from skia.org/download) and links FFmpeg system/bundled |
| Dart↔C bindings | **ffigen** | Generates from `include/tennoji/engine.h` |
| Dart package | **pub** | Standard `pubspec.yaml`, depends on `ffi` |
| CI | GitHub Actions | Matrix: Linux (VAAPI), macOS (VideoToolbox), Windows (NVENC/D3D11) |

### CMake sketch:

```cmake
cmake_minimum_required(VERSION 3.20)
project(tennoji_native CXX C)

set(CMAKE_CXX_STANDARD 20)

find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED
  libavcodec libavformat libavutil libswresample libswscale)

# Skia: use pre-built or build from source
set(SKIA_DIR "${CMAKE_SOURCE_DIR}/third_party/skia" CACHE PATH "Path to Skia")

add_library(tennoji SHARED
  src/engine.cpp
  src/renderer/skia_surface.cpp
  src/renderer/compositor.cpp
  src/renderer/scene.cpp
  src/media/decoder.cpp
  src/media/encoder.cpp
  src/media/demuxer.cpp
  src/media/muxer.cpp
  src/media/frame_pool.cpp
  src/media/audio_mixer.cpp
  src/timeline/clock.cpp
  src/timeline/frame_scheduler.cpp
  src/util/gpu_context.cpp
  src/util/thread_pool.cpp
)

target_include_directories(tennoji PUBLIC include)
target_include_directories(tennoji PRIVATE ${SKIA_DIR}/include ${FFMPEG_INCLUDE_DIRS})
target_link_libraries(tennoji PRIVATE ${FFMPEG_LIBRARIES} ${SKIA_DIR}/out/Release/libskia.a)
```

---

## 6. Initial Version Scope (v0.1)

### Must Have
- [ ] Engine init/shutdown (GPU context, Skia surface)
- [ ] `VideoClip` widget → decode, display a single video
- [ ] `AudioClip` widget → decode, play audio
- [ ] `Track` widget → sequential layout of clips
- [ ] `Timeline` widget → stacked tracks with basic compositing
- [ ] Playback (play, pause, seek)
- [ ] Export to file (single output codec, e.g. H.264 + AAC in MP4)
- [ ] Widget/Element/RenderObject framework (core three-tree)
- [ ] `Container`, `SizedBox`, `Padding` basic widgets

### Nice to Have (v0.2+)
- [ ] Transitions (crossfade, wipe)
- [ ] Filters (color correction, blur)
- [ ] Text overlay widget
- [ ] Multi-format export presets
- [ ] Undo/redo (command pattern on the widget tree)
- [ ] Thumbnail generation
- [ ] Waveform rendering for audio

---

## 7. Data Flow During Playback

```
1. Scheduler ticks at display rate (or target FPS for export)
        │
2. Clock advances → current_time
        │
3. RenderTimeline.performLayout()
   └─ for each RenderTrack:
      └─ find active RenderClip at current_time
         └─ compute clip-local time (accounting for trim, speed)
            └─ FFI call: tennoji_decoder_seek() if needed
            └─ FFI call: tennoji_decoder_next_frame()
            └─ FFI call: tennoji_texture_from_frame() → SkImage handle
        │
4. RenderTimeline.paint()
   └─ build draw command list (SkImage refs, transforms, opacity, filters)
   └─ FFI call: tennoji_render_submit(commands)
   └─ FFI call: tennoji_render_flush(output)
        │
5. Output goes to:
   ├─ Preview surface (display)  → platform window / texture widget
   └─ Encoder (export)           → tennoji_encoder_write_frame()
```

---

## 8. Maintenance & Extensibility Notes

1. **Widget = contract, RenderObject = implementation.** Adding a new feature (e.g., text overlay) means adding a `TextOverlay` widget + `RenderTextOverlay`. The framework code never changes.

2. **C API is the stability boundary.** Internal C++ can be refactored freely. Dart only sees the C function signatures.

3. **ffigen auto-generates bindings.** Change the C header → run `dart run ffigen` → bindings update. No manual FFI maintenance. (Requires configuring ffigen)

4. **Filters as a composable list** on clips. Each `Filter` maps to a Skia `SkImageFilter` or shader. Adding filters = adding a new `Filter` subclass, no framework changes.

5. **Platform GPU backends are isolated** in `gpu_context.cpp`. Adding Vulkan/Metal/DX support is localized to one file + CMake conditionals.

6. **Tests at every layer:**
   - Dart unit tests: widget diffing, element lifecycle, constraints
   - C++ unit tests (gtest): decoder, encoder, frame pool
   - Integration tests: full pipeline (decode → render → encode) with golden frame comparison
