#include "../engine_internal.h"
#include "canvas_internal.h"
#include "../dart_ui/image_internal.h"
#include "../dart_ui/shader_internal.h"
#include "../dart_ui/text/paragraph_internal.h"
#include "../dart_ui/stuff.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkSurface.h"
#include "include/core/SkImage.h"
#include "include/core/SkPaint.h"
#include "include/core/SkRect.h"
#include "include/core/SkColor.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkMaskFilter.h"

#include "skia_surface.h"
#include "tennoji/types.h"

// copied straight from the dart file idc
// Must match //lib/ui/painting/paint.cc.
static const int _kIsAntiAliasIndex = 0;
static const int _kColorRedIndex = 1;
static const int _kColorGreenIndex = 2;
static const int _kColorBlueIndex = 3;
static const int _kColorAlphaIndex = 4;
static const int _kColorSpaceIndex = 5;
static const int _kBlendModeIndex = 6;
static const int _kStyleIndex = 7;
static const int _kStrokeWidthIndex = 8;
static const int _kStrokeCapIndex = 9;
static const int _kStrokeJoinIndex = 10;
static const int _kStrokeMiterLimitIndex = 11;
static const int _kFilterQualityIndex = 12;
static const int _kMaskFilterIndex = 13;
static const int _kMaskFilterBlurStyleIndex = 14;
static const int _kMaskFilterSigmaIndex = 15;
static const int _kInvertColorIndex = 16;

SkPaint paint_create_from_encoded(TennojiCanvasPaintMetadata* metadata) {
  if (!metadata) {
    // idk return a default paint 
    SkPaint defaultPaint;
    defaultPaint.setAntiAlias(true);
  }
  SkPaint paint;

  auto data = metadata->encodedData;

  paint.setAntiAlias(data[_kIsAntiAliasIndex]);
  paint.setColor4f(*reinterpret_cast<SkColor4f*>(&data[_kColorRedIndex]), SkColorSpace::MakeSRGBLinear().get());
  paint.setBlendMode((SkBlendMode)data[_kBlendModeIndex]);
  paint.setStyle((SkPaint::Style)data[_kStyleIndex]);
  paint.setStrokeWidth(*reinterpret_cast<float*>(&data[_kStrokeWidthIndex]));
  paint.setStrokeCap((SkPaint::Cap)data[_kStrokeCapIndex]);
  paint.setStrokeJoin((SkPaint::Join)data[_kStrokeJoinIndex]);
  paint.setStrokeMiter(*reinterpret_cast<float*>(&data[_kStrokeMiterLimitIndex]));
  paint.setMaskFilter(SkMaskFilter::MakeBlur(
    (SkBlurStyle)data[_kMaskFilterBlurStyleIndex],
    *reinterpret_cast<float*>(&data[_kMaskFilterSigmaIndex])
  ));

  if (metadata->shader)
    paint.setShader(metadata->shader->getShader());

  return paint;
}

extern "C" {

TENNOJI_EXPORT TennojiCanvas* rina_canvas_create(
  TennojiEngine* engine,
  int32_t width,
  int32_t height
) {
  if (!engine) return nullptr;

  auto* c = new TennojiCanvas();
  c->engine = engine;
  c->width = width;
  c->height = height;
  c->recorder = std::make_unique<SkPictureRecorder>();
  c->canvas = c->recorder->beginRecording(width, height);
  
  return c;
}

TENNOJI_EXPORT void rina_canvas_destroy(TennojiCanvas* canvas) {
  if (!canvas) return;
  delete canvas;
}
TENNOJI_EXPORT void rina_canvas_draw_color(
  TennojiCanvas* canvas,
  uint32_t color, // ARGB
  uint8_t blendMode // SkBlendMode
) {
  if (!canvas || !canvas->canvas) return;
  SkPaint paint;
  paint.setColor(color);
  paint.setBlendMode((SkBlendMode)blendMode);
  canvas->canvas->drawPaint(paint);
}
TENNOJI_EXPORT void rina_canvas_draw_paragraph(
  TennojiCanvas* canvas,
  TennojiParagraph* paragraph,
  float dx, float dy
) {
  if (!canvas || !canvas->canvas || !paragraph) return;
  paragraph->paragraph->paint(canvas->canvas, dx, dy);
}
TENNOJI_EXPORT void rina_canvas_draw_paint(
  TennojiCanvas* canvas, 
  TennojiCanvasPaintMetadata* paintData
) {
  if (!canvas || !canvas->canvas) return;
  canvas->canvas->drawPaint(paint_create_from_encoded(paintData));
}

TENNOJI_EXPORT void rina_canvas_draw_rect(
  TennojiCanvas* canvas,
  float left, float top,
  float width, float height,
  TennojiCanvasPaintMetadata* paintData
) {
  if (!canvas || !canvas->canvas) return;

  canvas->canvas->drawRect(
    SkRect::MakeXYWH(left, top, width, height), 
    paint_create_from_encoded(paintData)
  );
}

TENNOJI_EXPORT void rina_canvas_draw_image(
  TennojiCanvas* canvas,
  TennojiCanvasImage* texture,
  float dx, float dy,
  TennojiCanvasPaintMetadata* paintData
) {
  if (!canvas || !canvas->canvas || !canvas->engine) return;

  sk_sp<SkImage> image = texture->image;
  if (!image) return;
  
  auto paint = paint_create_from_encoded(paintData);
  auto samplingOpt = sampling_from_quality_enum(paintData->encodedData[_kFilterQualityIndex]);
  canvas->canvas->drawImage(
    image, dx, dy, 
    samplingOpt, &paint
  );
}

TENNOJI_EXPORT void rina_canvas_save(TennojiCanvas* canvas) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->save();
}

TENNOJI_EXPORT void rina_canvas_restore(TennojiCanvas* canvas) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->restore();
}

TENNOJI_EXPORT void rina_canvas_translate(TennojiCanvas* canvas, float dx, float dy) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->translate(dx, dy);
}

TENNOJI_EXPORT void rina_canvas_scale(TennojiCanvas* canvas, float sx, float sy) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->scale(sx, sy);
}

TENNOJI_EXPORT void rina_canvas_rotate(TennojiCanvas* canvas, float degrees) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->rotate(degrees);
}

TENNOJI_EXPORT void rina_canvas_clip_rect(TennojiCanvas* canvas,
                                              float left, float top,
                                              float width, float height) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->clipRect(SkRect::MakeXYWH(left, top, width, height));
}

TENNOJI_EXPORT int rina_canvas_save_layer(TennojiCanvas* canvas, int alpha) {
    if (!canvas || !canvas->canvas) return -1;
    SkPaint paint;
    paint.setAlpha(static_cast<uint8_t>(alpha & 0xFF));
    return canvas->canvas->saveLayer(nullptr, &paint);
}

} // extern "C"
