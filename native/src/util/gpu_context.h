#pragma once

struct GrDirectContext;

namespace tennoji {

enum class GPUBackendType {
    Vulkan,
    Metal,
    D3D11,
    OpenGL,
};

struct GPUContext {
    GPUBackendType type;
    GrDirectContext* grContext = nullptr;

    // Platform-specific handles
    void* native_device = nullptr;   // VkDevice, id<MTLDevice>, ID3D11Device*
    void* native_queue = nullptr;    // VkQueue, id<MTLCommandQueue>
    void* native_display = nullptr;  // EGLDisplay (Linux/OpenGL)
    void* native_context = nullptr;  // EGLContext
};

GPUContext* gpu_context_create(const char* backend);
void gpu_context_destroy(GPUContext* ctx);

} // namespace tennoji
