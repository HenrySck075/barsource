#ifndef TENNOJI_TYPES_H
#define TENNOJI_TYPES_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define tstruct(name) typedef struct name name

tstruct(TennojiEngine);
tstruct(TennojiDecoder);
tstruct(TennojiEncoder);
tstruct(TennojiTexture);
tstruct(TennojiCanvas);
tstruct(TennojiParagraphBuilder);
tstruct(TennojiCanvasImage); // for the most part it holds a skimage
tstruct(TennojiCodec);
tstruct(TennojiImageDescriptor);
tstruct(TennojiCanvasVertices);
tstruct(TennojiShader);
tstruct(TennojiCanvasGradient); // yall job is to tell me how are these related

typedef struct {
  int64_t durationMs;
  TennojiCanvasImage* image;
} TennojiFrameInfo;

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

#ifdef __cplusplus
}
#endif

#endif // TENNOJI_TYPES_H
