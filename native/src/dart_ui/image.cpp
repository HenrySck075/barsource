#include "image_internal.h"


TENNOJI_EXPORT void tennoji_texture_release(TennojiCanvasImage* texture) {
    delete texture;
}

TENNOJI_EXPORT int tennoji_texture_get_width(TennojiCanvasImage* texture) {
    return texture->image->width();
}

TENNOJI_EXPORT int tennoji_texture_get_height(TennojiCanvasImage* texture) {
    return texture->image->height();
}