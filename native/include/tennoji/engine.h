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

#include "types.h"

#ifdef __cplusplus
extern "C" {
#endif

// Engine lifecycle
TENNOJI_EXPORT TennojiEngine* tennoji_engine_create(const TennojiEngineConfig* config);
TENNOJI_EXPORT void tennoji_engine_destroy(TennojiEngine* engine);

// Decoder (video/audio)
TENNOJI_EXPORT TennojiDecoder* tennoji_decoder_open(
  TennojiEngine* engine,
  const char* uri,
  TennojiHWAccel accel
);
TENNOJI_EXPORT void tennoji_decoder_close(TennojiDecoder* decoder);
TENNOJI_EXPORT int tennoji_decoder_seek(TennojiDecoder* decoder, int64_t timestamp_us);
TENNOJI_EXPORT TennojiCanvasImage* tennoji_decoder_get_texture(
  TennojiDecoder* decoder,
  int64_t timestamp_us
);
TENNOJI_EXPORT int64_t tennoji_decoder_duration(TennojiDecoder* decoder);
TENNOJI_EXPORT int tennoji_decoder_read_audio(
  TennojiDecoder* decoder,
  int64_t timestamp_us
);

// Canvas (Skia command recording)
TENNOJI_EXPORT TennojiCanvas* tennoji_canvas_create(
  TennojiEngine* engine,
  int32_t width,
  int32_t height
);
TENNOJI_EXPORT void tennoji_canvas_destroy(TennojiCanvas* canvas);
TENNOJI_EXPORT void tennoji_canvas_clear(TennojiCanvas* canvas, uint32_t color);
TENNOJI_EXPORT void tennoji_canvas_draw_rect(
  TennojiCanvas* canvas,
  float left, float top,
  float width, float height,
  uint32_t color
);
TENNOJI_EXPORT void tennoji_canvas_draw_image(
  TennojiCanvas* canvas,
  TennojiCanvasImage* image,
  float dx, float dy
);
TENNOJI_EXPORT void tennoji_canvas_save(TennojiCanvas* canvas);
TENNOJI_EXPORT void tennoji_canvas_restore(TennojiCanvas* canvas);
TENNOJI_EXPORT void tennoji_canvas_translate(TennojiCanvas* canvas, float dx, float dy);
TENNOJI_EXPORT void tennoji_canvas_scale(TennojiCanvas* canvas, float sx, float sy);
TENNOJI_EXPORT void tennoji_canvas_rotate(TennojiCanvas* canvas, float degrees);
TENNOJI_EXPORT void tennoji_canvas_clip_rect(
  TennojiCanvas* canvas,
  float left, float top,
  float width, float height
);
TENNOJI_EXPORT int tennoji_canvas_save_layer(TennojiCanvas* canvas, int alpha);

// Texture (GPU texture handle, opaque int ID)
// no longer true
TENNOJI_EXPORT void tennoji_texture_destroy(TennojiCanvasImage* texture);

TENNOJI_EXPORT TennojiCodec* tennoji_codec_from_encoded(const uint8_t* data, const uint32_t length);
TENNOJI_EXPORT TennojiCodec* tennoji_codec_from_file(const char* path);
TENNOJI_EXPORT void tennoji_codec_destroy(TennojiCodec* codec);
TENNOJI_EXPORT int tennoji_codec_get_frame_count(TennojiCodec* codec);
TENNOJI_EXPORT int tennoji_codec_get_repetition_count(TennojiCodec* codec);
TENNOJI_EXPORT TennojiFrameInfo* tennoji_codec_get_frame_info(TennojiCodec* codec, int index);
TENNOJI_EXPORT void tennoji_frame_info_destroy(TennojiFrameInfo* info);

TENNOJI_EXPORT TennojiImageDescriptor* tennoji_idesc_from_encoded(const uint8_t* data, const uint32_t length);
TENNOJI_EXPORT TennojiImageDescriptor* tennoji_idesc_from_raw(
  const uint8_t* data, 
  const uint32_t width, const uint32_t height,
  int8_t rowBytes,
  const int8_t pixelFormat // doesnt care because flutter hardcodes a 4
                               // on the bytes per pixel value where this matters
);

TENNOJI_EXPORT uint32_t tennoji_idesc_get_width(TennojiImageDescriptor* descriptor);
TENNOJI_EXPORT uint32_t tennoji_idesc_get_height(TennojiImageDescriptor* descriptor);

TENNOJI_EXPORT TennojiCodec* tennoji_idesc_instantiate_codec(TennojiImageDescriptor* descriptor, uint32_t targetWidth, uint32_t targetHeight, uint8_t targetPixelFormat);
TENNOJI_EXPORT void tennoji_idesc_destroy(TennojiImageDescriptor* descriptor);

TENNOJI_EXPORT bool tennoji_texture_equals(
  TennojiCanvasImage* tex1,
  TennojiCanvasImage* tex2
);

TENNOJI_EXPORT int tennoji_texture_get_width(TennojiCanvasImage* texture);
TENNOJI_EXPORT int tennoji_texture_get_height(TennojiCanvasImage* texture);


// Encoder (export)
TENNOJI_EXPORT TennojiEncoder* tennoji_encoder_create(
  TennojiEngine* engine,
  const TennojiEncoderConfig* config
);
TENNOJI_EXPORT int tennoji_encoder_write_frame(
  TennojiEncoder* encoder,
  TennojiCanvas* canvas
);
TENNOJI_EXPORT int tennoji_encoder_write_audio(
  TennojiEncoder* encoder,
  TennojiDecoder* audio_decoder,
  int64_t duration_us
);
TENNOJI_EXPORT int tennoji_encoder_drain_audio_queue(
  TennojiEncoder* encoder,
  TennojiDecoder* decoder
);
TENNOJI_EXPORT int tennoji_encoder_finalize(TennojiEncoder* encoder);
TENNOJI_EXPORT void tennoji_encoder_destroy(TennojiEncoder* encoder);

// sure non-null terminated string exist but we'll just assume dart is the only one interfacing this
TENNOJI_EXPORT TennojiParagraphBuilder* tennoji_paragraph_builder_create(
  int32_t* encodedStyle,
  uint8_t esLength,
  uint8_t* strutData,
  uint8_t sdLength,
  /*const std::string&*/ const char* fontFamily,
  /*const std::vector<std::string>&*/ const char** strutFontFamilies,
  uint8_t sffLen,
  double fontSize,
  double height,
  /*const std::u16string&*/ const uint16_t* ellipsis,
  /*const std::string&*/ const char* locale
);


// this fucker on rsuperellipse
TENNOJI_EXPORT bool tennoji_rsuperellipse_contains(
    double px, double py,            // The point to test
    double left, double top, 
    double right, double bottom,
    double tlRx, double tlRy,        // Top-Left Radii
    double trRx, double trRy,        // Top-Right Radii
    double blRx, double blRy,        // Bottom-Left Radii
    double brRx, double brRy         // Bottom-Right Radii
);

// Vertices
TENNOJI_EXPORT TennojiCanvasVertices* tennoji_vertices_init(
  uint8_t mode,
  uint64_t length, // used by positions, textureCoordinates, colors assuming they matches the length
  float* positions, 
  float* textureCoordinates, // nullable
  int32_t* colors, // also nullable
  uint16_t* indices, uint64_t iLength
);
TENNOJI_EXPORT void tennoji_vertices_destroy(TennojiCanvasVertices* vertices);
TENNOJI_EXPORT void tennoji_canvas_draw_vertices(
  TennojiCanvas* canvas,
  TennojiCanvasVertices* vertices,
  uint32_t blendMode, // SkBlendMode
  uint32_t color
);

// shaders
TENNOJI_EXPORT TennojiCanvasGradient* tennoji_gradient_init_linear(
  float x0, float y0, float x1, float y1,
  uint32_t* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  double* matrix4 // aka SkMatrix
);
TENNOJI_EXPORT TennojiCanvasGradient* tennoji_gradient_init_radial(
  float cx, float cy, float radius,
  uint32_t* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  double* matrix4 
);
TENNOJI_EXPORT TennojiCanvasGradient* tennoji_gradient_init_sweep(
  float cx, float cy, 
  float startAngle, float endAngle,
  uint32_t* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  double* matrix4 
);
TENNOJI_EXPORT TennojiCanvasGradient* tennoji_gradient_init_conical(
  float startCx, float startCy, float startRadius,
  float endCx, float endCy, float endRadius,
  uint32_t* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  double* matrix4 
);
TENNOJI_EXPORT void tennoji_gradient_destroy(TennojiCanvasGradient* gradient);

#ifdef __cplusplus
}
#endif

#endif // TENNOJI_ENGINE_H
