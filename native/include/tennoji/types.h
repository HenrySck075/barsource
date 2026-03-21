#ifndef TENNOJI_TYPES_H
#define TENNOJI_TYPES_H

#include <stdint.h>

#define ConstructResult(type) \
typedef struct { \
  type* result; \
  const char* errorDetails; \
} type##Result
#ifdef __cplusplus
extern "C" {
#endif


#define tstruct(name) typedef struct name name
#define trstruct(name) typedef struct name name; ConstructResult(name)

tstruct(TennojiEngine);
tstruct(TennojiDecoder);
tstruct(TennojiEncoder);
tstruct(TennojiTexture);
tstruct(TennojiCanvas);
tstruct(TennojiParagraphBuilder);
tstruct(TennojiParagraph);
tstruct(TennojiCanvasImage); // for the most part it holds a skimage
tstruct(TennojiCodec);
tstruct(TennojiImageDescriptor);
tstruct(TennojiCanvasVertices);
// TODO: figure out how to give out Sk pointers directly
tstruct(TennojiCanvasPath);
tstruct(TennojiCanvasPathMeasure);
tstruct(TennojiShader);
trstruct(TennojiFragmentProgram);
tstruct(TennojiFragmentShader);
tstruct(TennojiColorFilter);
tstruct(TennojiImageFilter);

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

typedef struct {
  uint32_t* encodedData;
  TennojiShader* shader;
  TennojiColorFilter* colorFilter;
  TennojiImageFilter* imageFilter;
} TennojiCanvasPaintMetadata;


#ifdef __cplusplus
}
#endif

#endif // TENNOJI_TYPES_H
