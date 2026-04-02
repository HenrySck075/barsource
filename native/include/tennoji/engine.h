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
TENNOJI_EXPORT TennojiEngine* rina_engine_create(const TennojiEngineConfig* config);
TENNOJI_EXPORT void rina_engine_destroy(TennojiEngine* engine);

// Decoder (video/audio)
TENNOJI_EXPORT TennojiDecoder* rina_decoder_open(
  TennojiEngine* engine,
  const char* uri,
  TennojiHWAccel accel
);
TENNOJI_EXPORT void rina_decoder_close(TennojiDecoder* decoder);
TENNOJI_EXPORT int rina_decoder_seek(TennojiDecoder* decoder, int64_t timestamp_us);
TENNOJI_EXPORT TennojiCanvasImage* rina_decoder_get_texture(
  TennojiDecoder* decoder,
  int64_t timestamp_us
);
TENNOJI_EXPORT int64_t rina_decoder_duration(TennojiDecoder* decoder);
TENNOJI_EXPORT int rina_decoder_read_audio(
  TennojiDecoder* decoder,
  int64_t timestamp_us
);

// Canvas (Skia command recording)
TENNOJI_EXPORT TennojiCanvas* rina_canvas_create(
  TennojiEngine* engine,
  int32_t width,
  int32_t height
);
TENNOJI_EXPORT void rina_canvas_destroy(TennojiCanvas* canvas);

TENNOJI_EXPORT void rina_canvas_draw_color(
  TennojiCanvas* canvas,
  uint32_t color, // ARGB
  uint8_t blendMode // SkBlendMode
);
TENNOJI_EXPORT void rina_canvas_draw_paint(
  TennojiCanvas* canvas, 
  TennojiCanvasPaintMetadata* paintData
);
TENNOJI_EXPORT void rina_canvas_draw_rect(
  TennojiCanvas* canvas,
  float left, float top,
  float width, float height,
  TennojiCanvasPaintMetadata* paintData
);
TENNOJI_EXPORT void rina_canvas_draw_image_rect(
  TennojiCanvas* canvas,
  TennojiCanvasImage* image,
  float srcLeft, float srcTop,
  float srcWidth, float srcHeight,
  float dstLeft, float dstTop,
  float dstWidth, float dstHeight,
  TennojiCanvasPaintMetadata* paintData
);
TENNOJI_EXPORT void rina_canvas_draw_image(
  TennojiCanvas* canvas,
  TennojiCanvasImage* image,
  float dx, float dy,
  TennojiCanvasPaintMetadata* paintData
);
TENNOJI_EXPORT void rina_canvas_draw_paragraph(
  TennojiCanvas* canvas,
  TennojiParagraph* paragraph,
  float dx, float dy
);

TENNOJI_EXPORT void rina_canvas_save(TennojiCanvas* canvas);
TENNOJI_EXPORT void rina_canvas_restore(TennojiCanvas* canvas);
TENNOJI_EXPORT void rina_canvas_translate(TennojiCanvas* canvas, float dx, float dy);
TENNOJI_EXPORT void rina_canvas_scale(TennojiCanvas* canvas, float sx, float sy);
TENNOJI_EXPORT void rina_canvas_rotate(TennojiCanvas* canvas, float degrees);
TENNOJI_EXPORT void rina_canvas_clip_rect(
  TennojiCanvas* canvas,
  float left, float top,
  float width, float height,
  bool doAntiAlias
);
TENNOJI_EXPORT int rina_canvas_save_layer(TennojiCanvas* canvas, int alpha);

// Texture (GPU texture handle, opaque int ID)
// no longer true
TENNOJI_EXPORT void rina_texture_destroy(TennojiCanvasImage* texture);

TENNOJI_EXPORT TennojiCodec* rina_codec_from_encoded(const uint8_t* data, const uint64_t length);
TENNOJI_EXPORT TennojiCodec* rina_codec_from_file(const char* path);
TENNOJI_EXPORT void rina_codec_destroy(TennojiCodec* codec);
TENNOJI_EXPORT int rina_codec_get_frame_count(TennojiCodec* codec);
TENNOJI_EXPORT int rina_codec_get_repetition_count(TennojiCodec* codec);
TENNOJI_EXPORT TennojiFrameInfo* rina_codec_get_frame_info(TennojiCodec* codec, int index);
TENNOJI_EXPORT void rina_frame_info_destroy(TennojiFrameInfo* info);

TENNOJI_EXPORT TennojiImageDescriptor* rina_idesc_from_encoded(const uint8_t* data, const uint32_t length);
TENNOJI_EXPORT TennojiImageDescriptor* rina_idesc_from_raw(
  const uint8_t* data, 
  const uint32_t width, const uint32_t height,
  int8_t rowBytes,
  const int8_t pixelFormat // doesnt care because flutter hardcodes a 4
                               // on the bytes per pixel value where this matters
);

TENNOJI_EXPORT uint32_t rina_idesc_get_width(TennojiImageDescriptor* descriptor);
TENNOJI_EXPORT uint32_t rina_idesc_get_height(TennojiImageDescriptor* descriptor);

TENNOJI_EXPORT TennojiCodec* rina_idesc_instantiate_codec(TennojiImageDescriptor* descriptor, uint32_t targetWidth, uint32_t targetHeight, uint8_t targetPixelFormat);
TENNOJI_EXPORT void rina_idesc_destroy(TennojiImageDescriptor* descriptor);

TENNOJI_EXPORT bool rina_texture_equals(
  TennojiCanvasImage* tex1,
  TennojiCanvasImage* tex2
);

TENNOJI_EXPORT int rina_texture_get_width(TennojiCanvasImage* texture);
TENNOJI_EXPORT int rina_texture_get_height(TennojiCanvasImage* texture);


// Encoder (export)
TENNOJI_EXPORT TennojiEncoder* rina_encoder_create(
  TennojiEngine* engine,
  const TennojiEncoderConfig* config
);
TENNOJI_EXPORT int rina_encoder_write_frame(
  TennojiEncoder* encoder,
  TennojiCanvas* canvas
);
TENNOJI_EXPORT int rina_encoder_write_audio(
  TennojiEncoder* encoder,
  TennojiDecoder* audio_decoder,
  int64_t duration_us
);
TENNOJI_EXPORT int rina_encoder_drain_audio_queue(
  TennojiEncoder* encoder,
  TennojiDecoder* decoder
);

// Sample-based audio API (for new submission system)
TENNOJI_EXPORT int rina_decoder_read_audio_samples(
  TennojiDecoder* decoder,
  int64_t timestamp_us,
  float* samples_out,
  int sample_count,
  int sample_rate
);
TENNOJI_EXPORT int rina_encoder_write_audio_samples(
  TennojiEncoder* encoder,
  const float* samples,
  int sample_count,
  int sample_rate,
  int channels
);

TENNOJI_EXPORT int rina_encoder_finalize(TennojiEncoder* encoder);
TENNOJI_EXPORT void rina_encoder_destroy(TennojiEncoder* encoder);

// Paragraph
// sure non-null terminated string exist but we'll just assume dart is the only one interfacing this
TENNOJI_EXPORT TennojiParagraphBuilder* rina_paragraph_builder_create(
  int32_t* encodedStyle,
  uint8_t* strutData,
  bool hasStrutData,
  /*const std::string&*/ const char* fontFamily,
  /*const std::vector<std::string>&*/ const char** strutFontFamilies,
  uint32_t sffLen,
  /*const std::u16string&*/ const char* ellipsis,
  /*const std::string&*/ const char* locale
);
TENNOJI_EXPORT void rina_paragraph_builder_push_style(
  TennojiParagraphBuilder* builder,
  int32_t* encoded,
  const char** fontFamilies,
  uint32_t ffLength,
  float fontSize,
  float letterSpacing,
  float wordSpacing,
  float height,
  float decorationThickness,
  const char* locale,
  TennojiCanvasPaintMetadata* background,
  TennojiCanvasPaintMetadata* foreground,
  uint32_t* shadowsData,
  uint32_t* fontFeaturesData,
  uint32_t* fontVariationsData
);
TENNOJI_EXPORT void rina_paragraph_builder_pop(
  TennojiParagraphBuilder* builder
);
TENNOJI_EXPORT void rina_paragraph_builder_add_text(
  TennojiParagraphBuilder* builder,
  const char* text
);
TENNOJI_EXPORT void rina_paragraph_builder_add_placeholder(
  TennojiParagraphBuilder* builder,
  float width,
  float height,
  uint32_t alignment,
  float baselineOffset,
  uint32_t baseline
);
TENNOJI_EXPORT TennojiParagraph* rina_paragraph_builder_build(
  TennojiParagraphBuilder* builder
);
TENNOJI_EXPORT void rina_paragraph_builder_destroy(
  TennojiParagraphBuilder* builder
);
TENNOJI_EXPORT void rina_load_font_from_list(
  const uint8_t* data, uint32_t length,
  const char* fontFamily
);

TENNOJI_EXPORT void rina_paragraph_destroy(
  TennojiParagraph* paragraph
);
TENNOJI_EXPORT float rina_paragraph_get_width(TennojiParagraph* paragraph);
TENNOJI_EXPORT float rina_paragraph_get_height(TennojiParagraph* paragraph);
TENNOJI_EXPORT float rina_paragraph_get_longest_line(TennojiParagraph* paragraph);
TENNOJI_EXPORT float rina_paragraph_get_min_intrinsic_width(TennojiParagraph* paragraph);
TENNOJI_EXPORT float rina_paragraph_get_max_intrinsic_width(TennojiParagraph* paragraph);
TENNOJI_EXPORT float rina_paragraph_get_alphabetic_baseline(TennojiParagraph* paragraph);
TENNOJI_EXPORT float rina_paragraph_get_ideographic_baseline(TennojiParagraph* paragraph);
TENNOJI_EXPORT bool rina_paragraph_did_exceed_max_lines(TennojiParagraph* paragraph);
TENNOJI_EXPORT void rina_paragraph_layout(TennojiParagraph* paragraph, double width);

TENNOJI_EXPORT float* rina_paragraph_get_boxes_for_range(
  TennojiParagraph* paragraph,
  uint32_t start, uint32_t end,
  uint8_t boxHeightStyle,
  uint8_t boxWidthStyle
);
TENNOJI_EXPORT float* rina_paragraph_get_boxes_for_placeholders(
  TennojiParagraph* paragraph
);
TENNOJI_EXPORT int32_t* rina_paragraph_get_position_for_offset(
  TennojiParagraph* paragraph,
  double dx, double dy
);
TENNOJI_EXPORT int32_t* rina_paragraph_get_glyph_info_at(
  TennojiParagraph* paragraph,
  int32_t codeUnitOffset
);
TENNOJI_EXPORT int32_t* rina_paragraph_get_glyph_info_for_offset(
  TennojiParagraph* paragraph,
  double dx, double dy
);
TENNOJI_EXPORT int32_t* rina_paragraph_get_word_boundary(
  TennojiParagraph* paragraph,
  int64_t characterPos
);
TENNOJI_EXPORT int32_t* rina_paragraph_get_line_boundary(
  TennojiParagraph* paragraph,
  int64_t offset
);
// the first element is a reinterpreted uint32_t denoting the length
TENNOJI_EXPORT float* rina_paragraph_compute_line_metrics(
  TennojiParagraph* paragraph
);
TENNOJI_EXPORT float* rina_paragraph_get_line_metrics_at(
  TennojiParagraph* paragraph,
  uint64_t lineNumber
);
TENNOJI_EXPORT uint64_t rina_paragraph_get_number_of_lines(
  TennojiParagraph* paragraph
);
TENNOJI_EXPORT uint64_t rina_paragraph_get_line_number_at(
  TennojiParagraph* paragraph,
  int64_t codeUnitOffset
);
// this fucker on rsuperellipse
TENNOJI_EXPORT bool rina_rsuperellipse_contains(
    float px, float py,            // The point to test
    float left, float top, 
    float right, float bottom,
    float tlRx, float tlRy,        // Top-Left Radii
    float trRx, float trRy,        // Top-Right Radii
    float blRx, float blRy,        // Bottom-Left Radii
    float brRx, float brRy         // Bottom-Right Radii
);

// Vertices
TENNOJI_EXPORT TennojiCanvasVertices* rina_vertices_init(
  uint8_t mode,
  uint64_t length, // used by positions, textureCoordinates, colors assuming they matches the length
  float* positions, 
  float* textureCoordinates, // nullable
  int32_t* colors, // also nullable
  uint16_t* indices, uint64_t iLength
);
TENNOJI_EXPORT void rina_vertices_destroy(TennojiCanvasVertices* vertices);
TENNOJI_EXPORT void rina_canvas_draw_vertices(
  TennojiCanvas* canvas,
  TennojiCanvasVertices* vertices,
  uint32_t blendMode, // SkBlendMode
  uint32_t color
);

// shaders
TENNOJI_EXPORT TennojiShader* rina_gradient_create_linear(
  float x0, float y0, float x1, float y1,
  float* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  float* matrix4 // aka SkMatrix
);
TENNOJI_EXPORT TennojiShader* rina_gradient_create_radial(
  float cx, float cy, float radius,
  float* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  float* matrix4 
);
TENNOJI_EXPORT TennojiShader* rina_gradient_create_sweep(
  float cx, float cy, 
  float startAngle, float endAngle,
  float* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  float* matrix4 
);
TENNOJI_EXPORT TennojiShader* rina_gradient_create_conical(
  float startCx, float startCy, float startRadius,
  float endCx, float endCy, float endRadius,
  float* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  float* matrix4 
);

TENNOJI_EXPORT TennojiShader* rina_image_shader_create(
  TennojiCanvasImage* image,
  uint8_t tileModeX, uint8_t tileModeY, // SkTileMode
  uint8_t filterQuality,
  float* matrix4
);

TENNOJI_EXPORT void rina_shader_destroy(TennojiShader* shader);
//TENNOJI_EXPORT TennojiShader* rina_shader_copy(TennojiShader* shader);

TENNOJI_EXPORT TennojiFragmentProgramResult rina_fragment_create(const char* filePath);
TENNOJI_EXPORT TennojiFragmentShader* rina_fragment_create_shader(
  TennojiFragmentProgram* prog,
  uint64_t floatCount,
  uint64_t samplerCount
);
TENNOJI_EXPORT float* rina_fragment_shader_get_uniform_buffer(TennojiFragmentShader* shader);
TENNOJI_EXPORT void rina_fragment_shader_set_image_sampler(
  TennojiFragmentShader* shader, 
  uint64_t index,
  TennojiCanvasImage* image, 
  uint8_t filterQuality
);

// Path
TENNOJI_EXPORT TennojiCanvasPath* rina_path_create();
TENNOJI_EXPORT void rina_path_destroy(TennojiCanvasPath* path);

TENNOJI_EXPORT uint8_t rina_path_get_fill_type(TennojiCanvasPath* path);
TENNOJI_EXPORT void rina_path_set_fill_type(TennojiCanvasPath* path, uint8_t type);

TENNOJI_EXPORT void rina_path_move_to(TennojiCanvasPath* path, float x, float y);
TENNOJI_EXPORT void rina_path_relative_move_to(TennojiCanvasPath* path, float dx, float dy);

TENNOJI_EXPORT void rina_path_line_to(TennojiCanvasPath* path, float x, float y);
TENNOJI_EXPORT void rina_path_relative_line_to(TennojiCanvasPath* path, float dx, float dy);

TENNOJI_EXPORT void rina_path_quadratic_to(
  TennojiCanvasPath* path, 
  float x1, float y1, float x2, float y2
);
TENNOJI_EXPORT void rina_path_relative_quadratic_to(
  TennojiCanvasPath* path, 
  float x1, float y1, float x2, float y2
);

TENNOJI_EXPORT void rina_path_cubic_to(
  TennojiCanvasPath* path, 
  float x1, float y1, float x2, float y2, float x3, float y3
);
TENNOJI_EXPORT void rina_path_relative_cubic_to(
  TennojiCanvasPath* path, 
  float x1, float y1, float x2, float y2, float x3, float y3
);

TENNOJI_EXPORT void rina_path_conic_to(
  TennojiCanvasPath* path, 
  float x1, float y1, float x2, float y2, float w
);
TENNOJI_EXPORT void rina_path_relative_conic_to(
  TennojiCanvasPath* path, 
  float x1, float y1, float x2, float y2, float w
);

TENNOJI_EXPORT void rina_path_arc_to_rect(
  TennojiCanvasPath* path,
  float left,
  float top,
  float right,
  float bottom,
  float startAngle,
  float sweepAngle,
  bool forceMoveTo
);

TENNOJI_EXPORT void rina_path_arc_to_point(
  TennojiCanvasPath* path,
  float arcEndX,
  float arcEndY,
  float radiusX,
  float radiusY,
  float rotation,
  bool largeArc,
  bool clockwise
);
TENNOJI_EXPORT void rina_path_relative_arc_to_point(
  TennojiCanvasPath* path,
  float arcEndDeltaX,
  float arcEndDeltaY,
  float radiusX,
  float radiusY,
  float rotation,
  bool largeArc,
  bool clockwise
);

TENNOJI_EXPORT TennojiCanvasPath* rina_path_clone(TennojiCanvasPath* path);
TENNOJI_EXPORT void rina_path_add_rect(
  TennojiCanvasPath* path,
  float l, float t, float r, float b
);
TENNOJI_EXPORT void rina_path_add_oval(
  TennojiCanvasPath* path,
  float l, float t, float r, float b
);
TENNOJI_EXPORT void rina_path_add_arc(
  TennojiCanvasPath* path,
  float l, float t, float r, float b, float startAngle, float sweepAngle
);
TENNOJI_EXPORT void rina_path_add_polygon(
  TennojiCanvasPath* path,
  float* points, uint64_t unencoded_length, bool close
);
TENNOJI_EXPORT void rina_path_add_rrect(TennojiCanvasPath* path, float* rrectData);
TENNOJI_EXPORT void rina_path_add_rsuperellipse(TennojiCanvasPath* path, float* rsuperellipseData);

TENNOJI_EXPORT void rina_path_add_path(
  TennojiCanvasPath* path, TennojiCanvasPath* otherPath, 
  bool extend,
  float dx, float dy
);
TENNOJI_EXPORT void rina_path_add_path_with_matrix(
  TennojiCanvasPath* path, TennojiCanvasPath* otherPath, 
  bool extend,
  float dx, float dy,
  float* matrix4
);

TENNOJI_EXPORT void rina_path_close(TennojiCanvasPath* path);
TENNOJI_EXPORT void rina_path_reset(TennojiCanvasPath* path);

TENNOJI_EXPORT bool rina_path_contains(TennojiCanvasPath* path, float x, float y);
TENNOJI_EXPORT void rina_path_shift(TennojiCanvasPath* path, float x, float y);
TENNOJI_EXPORT void rina_path_transform(TennojiCanvasPath* path, float* matrix4);

TENNOJI_EXPORT bool rina_path_combine_op(
  TennojiCanvasPath* resultPath,
  TennojiCanvasPath* path1, TennojiCanvasPath* path2, 
  int operationId
); 

TENNOJI_EXPORT float* rina_path_get_bounds(TennojiCanvasPath* path);

TENNOJI_EXPORT TennojiCanvasPathMeasure* rina_path_measure_create(
  TennojiCanvasPath* path, bool forceClose
);
TENNOJI_EXPORT void rina_path_measure_destroy(TennojiCanvasPathMeasure* measure);

TENNOJI_EXPORT double rina_path_measure_length(TennojiCanvasPathMeasure* measure, int32_t contourIndex); 
TENNOJI_EXPORT float* rina_path_measure_tangent_for_offset(TennojiCanvasPathMeasure* measure, int32_t contourIndex, double distance); 
TENNOJI_EXPORT bool rina_path_measure_closed(TennojiCanvasPathMeasure* measure, int32_t contourIndex); 
TENNOJI_EXPORT TennojiCanvasPath* rina_path_measure_extract(
  TennojiCanvasPathMeasure* measure,
  int32_t contourIndex,
  double start,
  double end,
  bool startWithMoveTo
);

TENNOJI_EXPORT bool rina_path_measure_next_contour(TennojiCanvasPathMeasure* measure); 


// Filters

TENNOJI_EXPORT TennojiColorFilter* rina_color_filter_create_mode(
  uint32_t color, 
  uint8_t blendMode // SkBlendMode
);
TENNOJI_EXPORT TennojiColorFilter* rina_color_filter_create_matrix(float* matrix20);
TENNOJI_EXPORT TennojiColorFilter* rina_color_filter_create_srgb2linear_gamma();
TENNOJI_EXPORT TennojiColorFilter* rina_color_filter_create_linear2srgb_gamma();
TENNOJI_EXPORT void rina_color_filter_destroy(TennojiColorFilter* color);

TENNOJI_EXPORT TennojiImageFilter* rina_image_filter_create_blur(
  float sigmaX, float sigmaY,
  uint8_t tileMode,
  bool bounded,
  float boundsLeft, float boundsTop, float boundsRight, float boundsBottom
);
TENNOJI_EXPORT TennojiImageFilter* rina_image_filter_create_dilate(
  float radiusX, float radiusY
);
TENNOJI_EXPORT TennojiImageFilter* rina_image_filter_create_erode(
  float radiusX, float radiusY
);
TENNOJI_EXPORT TennojiImageFilter* rina_image_filter_create_matrix(
  float* matrix4, uint8_t filterQuality
);
TENNOJI_EXPORT TennojiImageFilter* rina_image_filter_create_from_cf(
  TennojiColorFilter* filter
);
TENNOJI_EXPORT TennojiImageFilter* rina_image_filter_create_composed(
  TennojiImageFilter* outer,
  TennojiImageFilter* inner
);
TENNOJI_EXPORT void rina_image_filter_destroy(TennojiImageFilter* filter);
#ifdef __cplusplus
}
#endif

#endif // TENNOJI_ENGINE_H
