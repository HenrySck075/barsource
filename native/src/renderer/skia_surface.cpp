#include "skia_surface.h"

#include "include/core/SkSurface.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"

namespace tennoji {

sk_sp<SkSurface> create_gpu_surface(GrDirectContext* grContext, int32_t width, int32_t height) {
    if (grContext) {
        // GPU-backed surface
        SkImageInfo imageInfo = SkImageInfo::MakeN32Premul(width, height);
        sk_sp<SkSurface> surface = SkSurfaces::RenderTarget(
            grContext,
            skgpu::Budgeted::kYes,
            imageInfo
        );
        if (surface) return surface;
    }

    // Fallback to raster surface (CPU)
    SkImageInfo imageInfo = SkImageInfo::MakeN32Premul(width, height);
    return SkSurfaces::Raster(imageInfo);
}

} // namespace tennoji
