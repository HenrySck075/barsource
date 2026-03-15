#include "include/core/SkImage.h"
#include "tennoji/engine.h"

extern "C" {
struct TennojiCanvasImage {
    sk_sp<SkImage> image;
};
}