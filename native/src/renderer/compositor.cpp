#include "compositor.h"
#include "../engine_internal.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkPaint.h"
#include "include/core/SkImage.h"
#include "include/gpu/ganesh/GrDirectContext.h"

namespace tennoji {

void composite_layers(TennojiEngine* engine,
                      SkSurface* target,
                      const std::vector<CompositeLayer>& layers) {
    if (!target || !engine) return;

    SkCanvas* canvas = target->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);

    for (const auto& layer : layers) {
        sk_sp<SkImage> image = engine->get_texture(layer.texture_id);
        if (!image) continue;

        canvas->save();
        canvas->translate(layer.x, layer.y);
        canvas->scale(layer.scale_x, layer.scale_y);

        if (layer.opacity < 1.0f) {
            SkPaint paint;
            paint.setAlphaf(layer.opacity);
            canvas->drawImage(image, 0, 0, SkSamplingOptions(), &paint);
        } else {
            canvas->drawImage(image, 0, 0);
        }

        canvas->restore();
    }

    // Flush GPU commands
    if (auto* context = target->recordingContext()) {
        static_cast<GrDirectContext*>(context)->flushAndSubmit();
    }
}

} // namespace tennoji
