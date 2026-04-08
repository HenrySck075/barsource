#include "../engine_internal.h"
#include "canvas_internal.h"
#include "image_internal.h"
#include "include/core/SkM44.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#include "shader_internal.h"
#include "text/paragraph_internal.h"
#include "stuff.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkSurface.h"
#include "include/core/SkImage.h"
#include "include/core/SkPaint.h"
#include "include/core/SkRect.h"
#include "include/core/SkColor.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkMaskFilter.h"

#include "../renderer/skia_surface.h"
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
  // paint.setColor4f(*reinterpret_cast<SkColor4f*>(&data[_kColorRedIndex]), SkColorSpace::MakeSRGBLinear().get());
  float r = *reinterpret_cast<float*>(&data[_kColorRedIndex]);
  float g = *reinterpret_cast<float*>(&data[_kColorGreenIndex]);
  float b = *reinterpret_cast<float*>(&data[_kColorBlueIndex]);
  float a = 1.0f - *reinterpret_cast<float*>(&data[_kColorAlphaIndex]);
  paint.setColor4f({r, g, b, a}, SkColorSpace::MakeSRGBLinear().get());
  paint.setBlendMode((SkBlendMode)(data[_kBlendModeIndex] ^ 3));
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

TENNOJI_EXPORT void rina_canvas_draw_image_rect(
  TennojiCanvas* canvas,
  TennojiCanvasImage* image,
  float srcLeft, float srcTop,
  float srcWidth, float srcHeight,
  float dstLeft, float dstTop,
  float dstWidth, float dstHeight,
  TennojiCanvasPaintMetadata* paintData
) {
  if (!canvas || !canvas->canvas || !image) return;

  sk_sp<SkImage> img = image->image;
  if (!img) return;

  auto paint = paint_create_from_encoded(paintData);
  auto samplingOpt = sampling_from_quality_enum(paintData->encodedData[_kFilterQualityIndex]);
  canvas->canvas->drawImageRect(
    img, 
    SkRect::MakeXYWH(srcLeft, srcTop, srcWidth, srcHeight),
    SkRect::MakeXYWH(dstLeft, dstTop, dstWidth, dstHeight),
    samplingOpt, &paint, SkCanvas::kFast_SrcRectConstraint
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
TENNOJI_EXPORT void rina_canvas_transform(TennojiCanvas* canvas, float* matrix4) {
    if (!canvas || !canvas->canvas || !matrix4) return;
    canvas->canvas->concat(*(SkM44*)(matrix4));
}

TENNOJI_EXPORT void rina_canvas_scale(TennojiCanvas* canvas, float sx, float sy) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->scale(sx, sy);
}

TENNOJI_EXPORT void rina_canvas_skew(TennojiCanvas* canvas, float sx, float sy) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->skew(sx, sy);
}

TENNOJI_EXPORT void rina_canvas_rotate(TennojiCanvas* canvas, float degrees) {
  if (!canvas || !canvas->canvas) return;
  canvas->canvas->rotate(degrees);
}

TENNOJI_EXPORT void rina_canvas_clip_rect(
  TennojiCanvas* canvas,
  float left, float top,
  float width, float height, 
  bool doAntiAlias
) {
  if (!canvas || !canvas->canvas) return;
  canvas->canvas->clipRect(SkRect::MakeXYWH(left, top, width, height), doAntiAlias);
}

TENNOJI_EXPORT int rina_canvas_save_layer(
  TennojiCanvas* canvas,
  TennojiCanvasPaintMetadata* metadata
) {
  if (!canvas || !canvas->canvas) return -1;
  auto paint = paint_create_from_encoded(metadata);
  return canvas->canvas->saveLayer(nullptr, &paint);
}
TENNOJI_EXPORT int rina_canvas_save_layer_alpha(
  TennojiCanvas* canvas, 
  uint8_t alpha
) {
  if (!canvas || !canvas->canvas) return -1;
  return canvas->canvas->saveLayerAlpha(nullptr, alpha);
}

TENNOJI_EXPORT uint64_t rina_canvas_get_save_count(TennojiCanvas* canvas) {
  return canvas->canvas->getSaveCount();
}

TENNOJI_EXPORT TennojiPicture* rina_canvas_finish_recording(TennojiCanvas* canvas) {
  return new TennojiPicture {
    .picture = canvas->recorder->finishRecordingAsPicture()
  };
}

TENNOJI_EXPORT TennojiCanvasImage* rina_picture_to_image(
  TennojiPicture* picture,
  TennojiEngine* engine // for gpu context
) {
  if (!picture || !engine) return nullptr;
  // 1. Define the dimensions based on the picture's cull rect
  SkRect bounds = picture->picture->cullRect();
  SkImageInfo info = SkImageInfo::MakeN32Premul(bounds.width(), bounds.height());

  // 2. Create a GPU-backed surface
  sk_sp<SkSurface> surface = SkSurfaces::RenderTarget(engine->grContext, skgpu::Budgeted::kYes, info);
  if (!surface) return nullptr;

  // 3. Draw the picture into the surface's canvas
  SkCanvas* canvas = surface->getCanvas();
  canvas->drawPicture(picture->picture);

  // 4. Snap a snapshot. 
  // Since the surface is GPU-backed, the image stays in GPU memory.
  return new TennojiCanvasImage{
    .image = surface->makeImageSnapshot()
  };
}

} // extern "C"
