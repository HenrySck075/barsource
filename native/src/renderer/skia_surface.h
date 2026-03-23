#pragma once

#include "include/core/SkSurface.h"
#include "include/gpu/ganesh/GrDirectContext.h"

namespace tennoji {

struct GPUContext;

struct ExportableSurface {
    sk_sp<SkSurface> skSurface;
    void* vkImage = nullptr; // VkImage
    void* vkMemory = nullptr; // VkDeviceMemory
    int fd = -1; // DMA-BUF fd

    bool isValid() const { return skSurface != nullptr && fd != -1; }
    void release(GPUContext* ctx);
};

// Create a GPU-backed SkSurface that can be exported as DMA-BUF
ExportableSurface create_exportable_gpu_surface(GPUContext* ctx, int32_t width, int32_t height);

// Create a GPU-backed SkSurface for rendering
sk_sp<SkSurface> create_gpu_surface(GrDirectContext* grContext, int32_t width, int32_t height);

} // namespace tennoji
