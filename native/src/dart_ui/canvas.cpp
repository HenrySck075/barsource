#include "../engine_internal.h"
#include "canvas_internal.h"
#include "filter_internal.h"
#include "image_internal.h"
#include "include/core/SkM44.h"
#include "include/core/SkRRect.h"
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
#include "include/core/SkBlurTypes.h"

#include "../renderer/skia_surface.h"
#include "tennoji/types.h"
#include "vector_internal.h"
#include <iostream>
#include <memory>

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
    SkPaint paint;
    
    // 1. Fundamental Safety Check
    if (!metadata || !metadata->encodedData) {
        paint.setAntiAlias(true);
        return paint;
    }

    const uint32_t* data = metadata->encodedData;
    // Note: In a production environment, you should also verify 
    // metadata->dataLength >= _kInvertColorIndex to prevent OOB reads.

    // 2. Helper for Float extraction (Avoids UB compared to reinterpret_cast)
    auto getFloat = [&](int index) {
        float val;
        uint32_t raw = data[index];
        std::memcpy(&val, &raw, sizeof(float));
        return val;
    };

    // 3. Boolean/Integer Assignments
    paint.setAntiAlias(data[_kIsAntiAliasIndex] != 0);

    // 4. Color Handling 
    // If Dart sends 0.0-1.0 floats, we clamp them to be safe.
    float r = std::clamp(getFloat(_kColorRedIndex), 0.0f, 1.0f);
    float g = std::clamp(getFloat(_kColorGreenIndex), 0.0f, 1.0f);
    float b = std::clamp(getFloat(_kColorBlueIndex), 0.0f, 1.0f);
    // fuckass
    float a = 1 - std::clamp(getFloat(_kColorAlphaIndex), 0.0f, 1.0f);
    
    // Note: You had '1.0f - alpha' in your snippet. 
    // If that's genuinely what your data source requires, keep it, 
    // but usually, alpha is straight 0.0-1.0.
    paint.setColor4f({r, g, b, a}, SkColorSpace::MakeSRGBLinear().get());

    // 5. Enum Safety (Casting raw ints to Enums is risky)
    // BlendMode: Ensure it's within SkBlendMode::kLastMode (usually 29)
    auto rawBlend = static_cast<SkBlendMode>(data[_kBlendModeIndex] ^ static_cast<uint32_t>(SkBlendMode::kSrcOver));; // Kept your 'magic' xor
    paint.setBlendMode(std::min(rawBlend, SkBlendMode::kLastMode));

    // Style: Stroke, Fill, or StrokeAndFill (0, 1, 2)
    paint.setStyle(static_cast<SkPaint::Style>(std::min(data[_kStyleIndex], 2u)));

    // 6. Stroke Attributes
    paint.setStrokeWidth(std::max(0.0f, getFloat(_kStrokeWidthIndex)));
    paint.setStrokeCap(static_cast<SkPaint::Cap>(std::min(data[_kStrokeCapIndex], (uint32_t)SkPaint::kLast_Cap)));
    paint.setStrokeJoin(static_cast<SkPaint::Join>(std::min(data[_kStrokeJoinIndex], (uint32_t)SkPaint::kLast_Join)));
    paint.setStrokeMiter(getFloat(_kStrokeMiterLimitIndex));

    // 7. Mask Filter (Blur)
    float sigma = getFloat(_kMaskFilterSigmaIndex);
    if (sigma > 0.0f) {
        uint32_t blurStyle = std::min(data[_kMaskFilterBlurStyleIndex], (uint32_t)SkBlurStyle::kLastEnum_SkBlurStyle);
        paint.setMaskFilter(SkMaskFilter::MakeBlur(static_cast<SkBlurStyle>(blurStyle), sigma));
    }

    // 8. Object Attachments
    if (metadata->shader)
        paint.setShader(metadata->shader->getShader());
    if (metadata->colorFilter)
        paint.setColorFilter(metadata->colorFilter->filter);
    if (metadata->imageFilter)
        paint.setImageFilter(metadata->imageFilter->filter);

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
TENNOJI_EXPORT void rina_canvas_draw_rrect(
  TennojiCanvas* canvas,
  float left, float top,
  float width, float height,
  float tlRx, float tlRy,
  float trRx, float trRy,
  float blRx, float blRy,
  float brRx, float brRy,
  TennojiCanvasPaintMetadata* paintData
) {
  if (!canvas || !canvas->canvas) return;

  SkVector radii[4] = {
    {tlRx, tlRy},
    {trRx, trRy},
    {blRx, blRy},
    {brRx, brRy}
  };

  canvas->canvas->drawRRect(
    SkRRect::MakeRectRadii(
      SkRect::MakeXYWH(left, top, width, height),
      radii
    ), 
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
    samplingOpt, &paint, SkCanvas::kStrict_SrcRectConstraint
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
TENNOJI_EXPORT void rina_canvas_draw_picture(
  TennojiCanvas* canvas,
  TennojiPicture* picture
) {
  if (!canvas || !canvas->canvas || !picture) return;

  canvas->canvas->drawPicture(picture->picture);
}
TENNOJI_EXPORT void rina_canvas_draw_path(
  TennojiCanvas* canvas,
  TennojiCanvasPath* path,
  TennojiCanvasPaintMetadata* paintData
) {
  if (!canvas || !canvas->canvas || !path) return;

  canvas->canvas->drawPath(
    path->builder->snapshot(), 
    paint_create_from_encoded(paintData)
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
TENNOJI_EXPORT void rina_canvas_clip_rrect(
  TennojiCanvas* canvas,
  float left, float top,
  float width, float height,
  float tlRx, float tlRy,
  float trRx, float trRy,
  float blRx, float blRy,
  float brRx, float brRy,
  bool doAntiAlias
) {
  if (!canvas || !canvas->canvas) return;

  SkVector radii[4] = {
    {tlRx, tlRy},
    {trRx, trRy},
    {blRx, blRy},
    {brRx, brRy}
  };

  canvas->canvas->clipRRect(
    SkRRect::MakeRectRadii(
      SkRect::MakeXYWH(left, top, width, height),
      radii
    ), doAntiAlias
  );
}

TENNOJI_EXPORT int rina_canvas_save_layer(
  TennojiCanvas* canvas,
  TennojiCanvasPaintMetadata* metadata
) {
  if (!canvas || !canvas->canvas) return -1;
  auto paint = paint_create_from_encoded(metadata);
  return canvas->canvas->saveLayer(nullptr, &paint);
}
TENNOJI_EXPORT int rina_canvas_save_layer_rec(
  TennojiCanvas* canvas, 
  TennojiImageFilter* filter
) {
  if (!canvas || !canvas->canvas || !filter) return -1;
  SkCanvas::SaveLayerRec rec;
  rec.fBackdrop = filter->filter.get();
  return canvas->canvas->saveLayer(rec);
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
  if (!canvas) return nullptr;
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

TENNOJI_EXPORT void rina_picture_destroy(TennojiPicture* picture) {
  if (picture == nullptr) return;
  delete picture;
}

TENNOJI_EXPORT int rina_picture_approximate_bytes_used(TennojiPicture* picture) {
  return picture->picture->approximateBytesUsed();
}
TENNOJI_EXPORT int rina_picture_approximate_op_count(TennojiPicture* picture) {
  return picture->picture->approximateOpCount();
}

} // extern "C"
