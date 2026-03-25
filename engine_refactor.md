# Engine Refactoring Documentation

This document outlines the refactoring of `render_controller.dart` to move rendering logic into dedicated bindings mixed into the `Engine` class, following a Flutter-like architecture.

## Changes Overview

### 1. Created `AudioBinding`
*   **File**: `dart/lib/src/engine/audio_binding.dart`
*   **Purpose**: Manages a registry of active `TennojiDecoder` instances.
*   **Features**:
    *   Maintains a list of decoders.
    *   Supports distinguishing decoders that need manual audio reading (e.g., audio-only clips) vs those handled by texture updates (video clips).
    *   Provides `registerAudioDecoder` and `unregisterAudioDecoder`.

### 2. Created `RendererBinding`
*   **File**: `dart/lib/src/rendering/binding.dart`
*   **Purpose**: Manages the rendering pipeline (`PipelineOwner`, `RenderView`).
*   **Features**:
    *   Initializes `PipelineOwner`.
    *   Provides `initRenderView` to setup the root view with configuration.
    *   Implements `drawFrame` structure (flush layout).

### 3. Updated `WidgetsBinding`
*   **File**: `dart/lib/src/widgets/binding.dart`
*   **Purpose**: Manages the widget tree (`BuildOwner`, `Element` tree).
*   **Features**:
    *   Initializes `BuildOwner`.
    *   Implements `attachRootWidget` to mount the widget tree.
    *   Implements `drawFrame` to perform build scope.

### 4. Updated `Engine` Class
*   **File**: `dart/lib/src/engine/engine.dart`
*   **Purpose**: The central engine that mixes in all bindings and drives the render loop.
*   **Changes**:
    *   Mixes in `SchedulerBinding`, `RendererBinding`, `WidgetsBinding`, `AudioBinding`.
    *   Implements the main `run(Widget app, RenderConfig config)` loop.
    *   Manages `Encoder` and `Canvas` lifecycle.
    *   Handles the frame loop: timing, build/layout/paint, encoding, and audio draining.
    *   Implements timer logic (`_registerTimer`, `_cancelTimer`, `_processTimers`).

### 5. Updated Media Render Objects
*   **File**: `dart/lib/src/rendering/media_render.dart`
*   **Changes**:
    *   `RenderVideoClip`: Registers its decoder with `Engine.instance` on attach, unregisters on detach.
    *   `RenderAudioClip`: Registers its decoder with `needsManualRead: true` on attach, unregisters on detach.
    *   Removed local decoder collection logic from the render controller.

### 6. Refactored `render_controller.dart`
*   **File**: `dart/lib/src/engine/render_controller.dart`
*   **Changes**:
    *   Removed `RenderConfig`, `VideoCodec`, `AudioCodec` classes (moved to `engine.dart`).
    *   Removed `render` logic loop.
    *   The `render` function now delegates entirely to `Engine.init` and `Engine.instance.run`.

### 7. Implemented `Ticker` and Refactored `EngineTimer`
*   **File**: `dart/lib/src/scheduler/ticker.dart`
*   **Purpose**: Implemented `Ticker` class to handle per-frame callbacks via `SchedulerBinding`.
*   **Engine Updates**:
    *   `Engine` now implements `TickerProvider`.
    *   Removed ad-hoc timer logic (`_timers`, `_processTimers`) from `Engine`.
    *   Updated `EngineTimer` to use `Ticker` for time tracking, aligning with Flutter's scheduler model.

## Usage

The external API remains compatible:
```dart
render(myWidget, myConfig);
```

Internally, the `Engine` now orchestrates the bindings to perform the offline rendering process, with decoders registering themselves automatically rather than being collected via tree traversal.
