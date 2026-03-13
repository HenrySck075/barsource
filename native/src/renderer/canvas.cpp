#include "../engine_internal.h"
#include "canvas_internal.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkSurface.h"
#include "include/core/SkImage.h"
#include "include/core/SkPaint.h"
#include "include/core/SkRect.h"
#include "include/core/SkColor.h"
#include "include/core/SkColorSpace.h"

#include "skia_surface.h"

extern "C" {

TENNOJI_EXPORT TennojiCanvas* tennoji_canvas_create(TennojiEngine* engine,
                                                     int32_t width,
                                                     int32_t height) {
    if (!engine) return nullptr;

    auto* c = new TennojiCanvas();
    c->engine = engine;
    c->surface = tennoji::create_gpu_surface(engine->grContext, width, height);
    if (!c->surface) {
        delete c;
        return nullptr;
    }
    c->canvas = c->surface->getCanvas();
    return c;
}

TENNOJI_EXPORT void tennoji_canvas_destroy(TennojiCanvas* canvas) {
    if (!canvas) return;
    delete canvas;
}

TENNOJI_EXPORT void tennoji_canvas_clear(TennojiCanvas* canvas, uint32_t color) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->clear(SkColor(color));
}

TENNOJI_EXPORT void tennoji_canvas_draw_rect(TennojiCanvas* canvas,
                                              float left, float top,
                                              float width, float height,
                                              uint32_t color) {
    if (!canvas || !canvas->canvas) return;

    SkPaint paint;
    paint.setColor(SkColor(color));
    paint.setStyle(SkPaint::kFill_Style);
    canvas->canvas->drawRect(SkRect::MakeXYWH(left, top, width, height), paint);
}

TENNOJI_EXPORT void tennoji_canvas_draw_image(TennojiCanvas* canvas,
                                               int texture_id,
                                               float dx, float dy) {
    if (!canvas || !canvas->canvas || !canvas->engine) return;

    sk_sp<SkImage> image = canvas->engine->get_texture(texture_id);
    if (!image) return;

    canvas->canvas->drawImage(image, dx, dy);
}

TENNOJI_EXPORT void tennoji_canvas_save(TennojiCanvas* canvas) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->save();
}

TENNOJI_EXPORT void tennoji_canvas_restore(TennojiCanvas* canvas) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->restore();
}

TENNOJI_EXPORT void tennoji_canvas_translate(TennojiCanvas* canvas, float dx, float dy) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->translate(dx, dy);
}

TENNOJI_EXPORT void tennoji_canvas_scale(TennojiCanvas* canvas, float sx, float sy) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->scale(sx, sy);
}

TENNOJI_EXPORT void tennoji_canvas_rotate(TennojiCanvas* canvas, float degrees) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->rotate(degrees);
}

TENNOJI_EXPORT void tennoji_canvas_clip_rect(TennojiCanvas* canvas,
                                              float left, float top,
                                              float width, float height) {
    if (!canvas || !canvas->canvas) return;
    canvas->canvas->clipRect(SkRect::MakeXYWH(left, top, width, height));
}

TENNOJI_EXPORT int tennoji_canvas_save_layer(TennojiCanvas* canvas, int alpha) {
    if (!canvas || !canvas->canvas) return -1;
    SkPaint paint;
    paint.setAlpha(static_cast<uint8_t>(alpha & 0xFF));
    return canvas->canvas->saveLayer(nullptr, &paint);
}

} // extern "C"
