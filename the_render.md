# Rendering System Analysis

The current rendering pipeline at `@dart/lib/src/engine/render_controller.dart` (and its native backend) implements a functional but performance-constrained architecture.

## Speed Rating: **Slow / Bottlenecked**
**Rating: 4/10** (Functional for offline rendering at lower resolutions, likely unusable for real-time 1080p/4K).

The system suffers from critical bottlenecks where data is forced to cross the CPU-GPU boundary synchronously for every single frame.

## Critical Bottlenecks

1.  **Synchronous GPU Readback (`rina_encoder_write_frame`)**
    *   **Issue:** The system calls `image->readPixels()` (in `encoder.cpp`), which forces a full flush of the GPU pipeline and waits for pixels to be copied from VRAM to system RAM.
    *   **Impact:** This destroys parallelism between CPU and GPU, making them wait for each other constantly.

2.  **Software Color Conversion (`sws_scale`)**
    *   **Issue:** After the costly readback, the CPU must convert the raw BGRA pixels to YUV420P using `sws_scale`.
    *   **Impact:** This is a computationally expensive $O(N)$ operation (where N is pixel count) running on the CPU, adding significant latency per frame.

3.  **Serialized Execution Model**
    *   **Issue:** The Dart `render` loop handles Layout -> Paint -> Readback -> Convert -> Encode sequentially.
    *   **Impact:** No pipelining. The Encoder cannot work on frame $N$ while the GPU renders frame $N+1$.

4.  **CPU-Bound Decoding to Texture**
    *   **Issue:** `avframe_to_skimage` (in `decoder.cpp`) performs a CPU copy and format conversion (YUV -> RGB) before uploading the texture to the GPU.
    *   **Impact:** High CPU usage during playback of video clips; redundant data movement.

## Recommended Improvements

### 1. Zero-Copy Hardware Encoding (High Impact)
Eliminate the CPU readback entirely.
*   **Implementation:** Use platform-specific APIs (VAAPI, NVENC, MediaCodec) that can accept a GPU texture (Texture ID or DMA-BUF) directly as input.
*   **Benefit:** Removes both the GPU readback and the `sws_scale` CPU conversion cost.

### 2. GPU-Side Color Conversion (Medium Impact)
If zero-copy encoding is not feasible, perform the BGRA -> YUV conversion on the GPU using a shader *before* readback.
*   **Implementation:** Render the scene to a texture, then draw that texture to a YUV render target using a fragment shader. Read back the YUV data.
*   **Benefit:** Replaces the slow CPU `sws_scale` with fast GPU compute; reduces readback bandwidth by 50% (YUV420 vs BGRA).

### 3. Pipelined Threading (Medium Impact)
Decouple the stages into separate threads connected by ring buffers.
*   **Implementation:**
    *   **Thread 1 (Dart/Layout):** Generates layer trees.
    *   **Thread 2 (Render):** Rasterizes to GPU surfaces.
    *   **Thread 3 (Encode):** Consumes frames and writes to disk.
*   **Benefit:** Allows the GPU to rasterize the next frame while the previous one is being encoded.

### 4. Zero-Copy Decoding (Low Impact)
Implement the TODO in `avframe_to_skimage`.
*   **Implementation:** Use `SkImage::MakeFromTexture` with the hardware decoder's output texture (e.g., using `EGLImage` or `CVPixelBuffer`).
*   **Benefit:** Reduces CPU usage during video clip playback.
