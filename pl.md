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
                        │  dart:ffi / NativePort
┌───────────────────────▼─────────────────────────────┐
│                  C++ Engine Core                     │
│                                                     │
│  ┌──────────┐  ┌───────────┐  ┌──────────────────┐  │
│  │  Skia    │  │  libav*   │  │  Timeline Engine │  │
│  │ (render) │  │ (decode/  │  │  (scheduling,    │  │
│  │          │  │  encode)  │  │   seeking, sync) │  │
│  └──────────┘  └───────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Why three trees?

Copying Flutter's proven pattern is intentional:

| Tree | Role | Mutability |
|------|------|------------|
| **Widget** | Declarative description of the composition. Cheap to rebuild. | Immutable |
| **Element** | Manages the widget↔render binding and lifecycle (mount, update, unmount). Reconciles old vs new widgets. | Mutable, long-lived |
| **RenderObject** | Owns layout (constraints-in, size-out) and paint (Skia command list). | Mutable, long-lived |

This gives us the same benefits Flutter gets: fast diffing via Elements, clean separation of concerns, and type safety in the render layer.

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
│   │   │   │   └── duration_ext.dart
│   │   │   ├── widgets/           # Widget layer (declarative API)
│   │   │   │   ├── framework.dart        # Widget, StatelessWidget, StatefulWidget, State<T>
│   │   │   │   ├── basic.dart            # Container, SizedBox, Padding, Stack, etc.
│   │   │   │   ├── clip.dart             # VideoClip, AudioClip, ImageClip
│   │   │   │   ├── track.dart            # Track (holds clips sequentially)
│   │   │   │   ├── timeline.dart         # Timeline (root widget, holds tracks)
│   │   │   │   └── transition.dart       # CrossFade, Cut (between clips)
│   │   │   ├── elements/          # Element layer (reconciliation)
│   │   │   │   ├── framework.dart        # Element, ComponentElement, RenderObjectElement
│   │   │   │   └── clip_element.dart     # Media-aware element lifecycle
│   │   │   ├── rendering/         # RenderObject layer
│   │   │   │   ├── object.dart           # RenderObject base, Constraints, PaintingContext
│   │   │   │   ├── box.dart              # RenderBox (2D box model)
│   │   │   │   ├── clip_render.dart      # RenderVideoClip, RenderAudioClip
│   │   │   │   ├── track_render.dart     # RenderTrack (sequential layout along time axis)
│   │   │   │   ├── timeline_render.dart  # RenderTimeline (stacked tracks, compositing)
│   │   │   │   └── pipeline_owner.dart   # Drives layout → paint → composite
│   │   │   ├── engine/            # FFI bindings + engine control
│   │   │   │   ├── bindings.dart         # Auto-generated (ffigen) C bindings
│   │   │   │   ├── engine.dart           # Init, shutdown, render loop
│   │   │   │   ├── texture_registry.dart # GPU texture handle management
│   │   │   │   └── export_session.dart   # Orchestrates encode/export
│   │   │   └── scheduler/        # Frame scheduling
│   │   │       ├── ticker.dart           # High-res timer tick
│   │   │       └── scheduler.dart        # Playback clock, seek, frame dispatch
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
│       │   ├── compositor.cpp         # Composites render tree output
│       │   └── scene.cpp              # Scene graph submitted per frame
│       ├── media/
│       │   ├── decoder.cpp            # AVCodec hw-accel decode
│       │   ├── encoder.cpp            # AVCodec hw-accel encode (NVENC/VAAPI/VT)
│       │   ├── demuxer.cpp            # AVFormatContext demux
│       │   ├── muxer.cpp              # AVFormatContext mux (export)
│       │   ├── frame_pool.cpp         # Ring buffer of decoded frames
│       │   └── audio_mixer.cpp        # Audio mixing / resampling (SwrContext)
│       ├── timeline/
│       │   ├── clock.cpp              # Master playback clock
│       │   └── frame_scheduler.cpp    # Decides which frames to decode ahead
│       └── util/
│           ├── gpu_context.cpp        # EGL/Metal/Vulkan context setup
│           └── thread_pool.cpp        # Work-stealing pool for decode/encode
│
└── pl.md                          # You are here
```

---

## 3. Dart Side Design (The Fast Parts)

### 3.1 Widget Layer

Widgets are **immutable** `const`-constructible objects. Identical to Flutter's model:

```dart
abstract class Widget {
  const Widget({this.key});
  final Key? key;

  Element createElement();
}

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});
  Widget build(BuildContext context);
}

abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
  State createState();
}
```

**Media widgets** for the initial version:

```dart
/// A video clip on the timeline.
class VideoClip extends LeafRenderObjectWidget {
  const VideoClip({
    super.key,
    required this.source,       // file path or URI
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.playbackSpeed = 1.0,
    this.volume = 1.0,
    this.filters = const [],
  });

  final String source;
  final Duration trimStart;
  final Duration? trimEnd;
  final double playbackSpeed;
  final double volume;
  final List<Filter> filters;

  @override
  RenderVideoClip createRenderObject(BuildContext context) { ... }

  @override
  void updateRenderObject(BuildContext context, RenderVideoClip renderObject) { ... }
}

/// An audio clip on the timeline.
class AudioClip extends LeafRenderObjectWidget {
  const AudioClip({
    super.key,
    required this.source,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.volume = 1.0,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
  });
  // ...
}

/// Basic container widgets
class Track extends MultiChildRenderObjectWidget {
  const Track({super.key, required super.children});
  // lays out children sequentially along the time axis
}

class Timeline extends MultiChildRenderObjectWidget {
  const Timeline({super.key, required this.tracks});
  final List<Track> tracks;
  // lays out tracks stacked (video composited top-down, audio mixed)
}
```

### 3.2 Element Layer

Handles lifecycle and diffing. Key operations:

- **mount**: create RenderObject, request native resource (decoder handle)
- **update**: diff old widget vs new widget, update RenderObject properties
- **unmount**: release native decoder handle, drop textures

```dart
abstract class Element implements BuildContext {
  Widget _widget;
  RenderObject? _renderObject;
  Element? _parent;

  void mount(Element? parent, Object? newSlot);
  void update(covariant Widget newWidget);
  void unmount();
  void markNeedsBuild();
}
```

For media elements, unmount **must** call into native to release the decoder/frame pool. This is done through `TextureRegistry.release(handle)`.

### 3.3 RenderObject Layer

```dart
abstract class RenderObject {
  void layout(Constraints constraints, {bool parentUsesSize = false});
  void paint(PaintingContext context, Offset offset);
  void attach(PipelineOwner owner);
  void detach();
  bool get needsLayout;
  bool get needsPaint;
}

/// Video editing uses a time-box model:
/// constraints carry both spatial (width × height) AND temporal (timeRange) info.
class TimeBoxConstraints extends BoxConstraints {
  const TimeBoxConstraints({
    required this.timeRange,       // visible time window
    required this.pixelsPerSecond, // zoom level
    super.minWidth,
    super.maxWidth,
    super.minHeight,
    super.maxHeight,
  });

  final (Duration start, Duration end) timeRange;
  final double pixelsPerSecond;
}
```

### 3.4 Performance Priorities (Dart side)

| Technique | Why |
|-----------|-----|
| `const` widgets | Zero allocation on rebuild |
| Targeted `markNeedsBuild()` | Only dirty subtrees rebuild |
| RenderObject property setters with guards (`if (value == _value) return;`) | Skip redundant native calls |
| `dart:ffi` synchronous calls for hot path (frame request) | No message-passing overhead |
| `NativePort` / `Isolate` for cold path (export, probe) | Non-blocking on UI thread |
| Final fields everywhere, `@immutable` annotation | Compiler optimization + correctness |

---

## 4. C++ Engine Design

### 4.1 FFI Boundary (C API)

The shared library exposes a **flat C API** (no C++ symbols leak). This is what `dart:ffi` binds to, and what `ffigen` auto-generates bindings for.

```c
// include/tennoji/engine.h

TENNOJI_EXPORT TennojiEngine* tennoji_engine_create(const TennojiConfig* config);
TENNOJI_EXPORT void           tennoji_engine_destroy(TennojiEngine* engine);

// Decoder
TENNOJI_EXPORT TennojiDecoder* tennoji_decoder_open(TennojiEngine* engine,
                                                     const char* uri,
                                                     TennojiHWAccel accel);
TENNOJI_EXPORT void            tennoji_decoder_close(TennojiDecoder* decoder);
TENNOJI_EXPORT int             tennoji_decoder_seek(TennojiDecoder* decoder,
                                                     int64_t timestamp_us);
TENNOJI_EXPORT TennojiFrame*   tennoji_decoder_next_frame(TennojiDecoder* decoder);

// Renderer (Skia)
TENNOJI_EXPORT TennojiTexture* tennoji_texture_from_frame(TennojiEngine* engine,
                                                           TennojiFrame* frame);
TENNOJI_EXPORT void            tennoji_render_submit(TennojiEngine* engine,
                                                      const TennojiDrawCommand* cmds,
                                                      int32_t cmd_count);
TENNOJI_EXPORT void            tennoji_render_flush(TennojiEngine* engine,
                                                     void* output_buffer,
                                                     int32_t width,
                                                     int32_t height);

// Encoder (Export)
TENNOJI_EXPORT TennojiEncoder* tennoji_encoder_create(TennojiEngine* engine,
                                                       const TennojiEncodeConfig* config);
TENNOJI_EXPORT int             tennoji_encoder_write_frame(TennojiEncoder* encoder,
                                                            TennojiFrame* frame);
TENNOJI_EXPORT int             tennoji_encoder_finalize(TennojiEncoder* encoder);
TENNOJI_EXPORT void            tennoji_encoder_destroy(TennojiEncoder* encoder);

// Audio
TENNOJI_EXPORT TennojiAudioMixer* tennoji_audio_mixer_create(TennojiEngine* engine,
                                                               int sample_rate,
                                                               int channels);
TENNOJI_EXPORT void               tennoji_audio_mixer_add_source(TennojiAudioMixer* mixer,
                                                                   TennojiDecoder* src,
                                                                   float volume);
TENNOJI_EXPORT int                tennoji_audio_mixer_read(TennojiAudioMixer* mixer,
                                                            float* buffer,
                                                            int frame_count);
```

### 4.2 Internal Architecture (C++)

Behind the C API, everything is modern C++17/20:

- **`Renderer`**: Owns an `SkSurface` (GPU-backed), receives draw commands from Dart's paint phase, composites layers. One Skia `GrDirectContext` per engine instance.
- **`Decoder`**: Wraps `AVCodecContext` with hardware acceleration (CUDA/VAAPI/VideoToolbox). Decoded frames go to a `FramePool` (ring buffer). Frames are mapped to Skia `SkImage` via GPU interop (e.g., `SkImages::MakeFromTexture` for zero-copy).
- **`Encoder`**: Wraps `AVCodecContext` for encoding. Accepts Skia surfaces or raw frames. Supports NVENC, VAAPI, VideoToolbox with fallback to software.
- **`AudioMixer`**: Uses `SwrContext` for resampling, mixes multiple audio streams with per-source volume.
- **`Clock`**: Master clock for playback sync. Drives frame scheduling.
- **`ThreadPool`**: Work-stealing pool. Decode and encode run on pool threads; Skia render stays on the GPU thread.

### 4.3 GPU Pipeline (Zero-Copy)

```
[libav HW decode] → GPU memory (NV12/P010)
         │
         ▼  (texture interop, no CPU roundtrip)
[Skia SkImage::MakeFromTexture] → SkCanvas draw
         │
         ▼
[Skia SkSurface flush] → composited frame in GPU memory
         │
         ▼  (for export: read-back or direct encode)
[libav HW encode] → output file
```

Key: Decoded frames stay on GPU. Skia paints on GPU. Encoding reads from GPU. The CPU never touches pixel data during playback.

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
