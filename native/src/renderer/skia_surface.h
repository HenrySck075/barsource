#pragma once

#include "include/core/SkSurface.h"
#include "include/gpu/ganesh/GrDirectContext.h"

namespace tennoji {

// Create a GPU-backed SkSurface for rendering
sk_sp<SkSurface> create_gpu_surface(GrDirectContext* grContext, int32_t width, int32_t height);

} // namespace tennoji
