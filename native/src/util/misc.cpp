#include "../dart_ui/image_internal.h"
#include "../engine_internal.h"
#include "include/core/SkData.h"
#include "include/core/SkImage.h"
#include "include/gpu/ganesh/GrBackendSurface.h"
#include "include/gpu/ganesh/SkImageGanesh.h"
#include "include/gpu/vk/VulkanTypes.h"
#include "tennoji/engine.h"
#include <cmath>
#include <cstddef>
#include <vulkan/vulkan_core.h>

#if !defined(_WIN32)
#include <linux/dma-buf.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <vulkan/vulkan.h>
#include <include/gpu/ganesh/vk/GrVkBackendSurface.h>
#include <include/gpu/ganesh/vk/GrVkTypes.h>
#include <drm/drm_fourcc.h>
#endif
// Helper to map DRM formats to Vulkan formats
static VkFormat drm_format_to_vk(uint32_t drm_format) {
    // You'll need to expand this based on what wlroots gives you
    switch (drm_format) {
        case DRM_FORMAT_XRGB8888:
        case DRM_FORMAT_ARGB8888: return VK_FORMAT_B8G8R8A8_UNORM;
        case DRM_FORMAT_XBGR8888:
        case DRM_FORMAT_ABGR8888: return VK_FORMAT_R8G8B8A8_UNORM;
        default: return VK_FORMAT_UNDEFINED;
    }
}

struct VulkanImageCleanupContext {
    VkDevice device;
    VkImage image;
    VkDeviceMemory memory;
};

extern "C" {
#pragma comment(linker, "/export:rina_tennoji")
#ifdef __clang__
__attribute__((used))
#endif
TENNOJI_EXPORT void rina_tennoji() {

}
// Supports vulkan only, for now
TENNOJI_EXPORT TennojiCanvasImage* rina_texture_from_dmabuf(
    TennojiEngine* engine,
    int dmaBufFd, int32_t width, int32_t height,
    int32_t rowBytes, int64_t offsetBytes,
    uint32_t pixelFormat, uint64_t modifier) {

    if (!engine || !engine->grContext || dmaBufFd < 0) {
      printf("One of the guarding condition failed, and that being: ");
      if (!engine) printf("engine is null.\n");
      else if (!engine->grContext) {
        printf("engine->grContext is null (testing, this means that engine->gpuCtx should be null to, and its ");
        if (engine->gpuCtx) printf("actually WRONG- wait what the grContext in it shouldve been copied over to the engine struct??????");
        else printf("actually right!");

        printf(").\n");
      }
      else if (dmaBufFd < 0) printf("dmaBufFd is invalid (negative) aka %d.\n", dmaBufFd);
      return nullptr;
    }

    // 1. Get Vulkan handles from your engine
    VkDevice* device = static_cast<VkDevice*>(engine->gpuCtx->native_device); // Assume your engine exposes this
    VkFormat vkFormat = drm_format_to_vk(pixelFormat);
    if (vkFormat == VK_FORMAT_UNDEFINED) return nullptr;

    // 2. Define the external memory and modifier pNext chains
    VkSubresourceLayout subresourceLayout = {};
    subresourceLayout.offset = offsetBytes;
    subresourceLayout.size = 0; // Driver calculates this based on extents
    subresourceLayout.rowPitch = rowBytes;
    subresourceLayout.arrayPitch = 0;
    subresourceLayout.depthPitch = 0;

    VkImageDrmFormatModifierExplicitCreateInfoEXT modifierInfo = {};
    modifierInfo.sType = VK_STRUCTURE_TYPE_IMAGE_DRM_FORMAT_MODIFIER_EXPLICIT_CREATE_INFO_EXT;
    modifierInfo.drmFormatModifier = modifier;
    modifierInfo.drmFormatModifierPlaneCount = 1;
    modifierInfo.pPlaneLayouts = &subresourceLayout;

    VkExternalMemoryImageCreateInfo extImageInfo = {};
    extImageInfo.sType = VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO;
    extImageInfo.pNext = &modifierInfo;
    extImageInfo.handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT;

    // 3. Create the VkImage
    VkImageCreateInfo imageInfo = {};
    imageInfo.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    imageInfo.pNext = &extImageInfo;
    imageInfo.imageType = VK_IMAGE_TYPE_2D;
    imageInfo.format = vkFormat;
    imageInfo.extent = { (uint32_t)width, (uint32_t)height, 1 };
    imageInfo.mipLevels = 1;
    imageInfo.arrayLayers = 1;
    imageInfo.samples = VK_SAMPLE_COUNT_1_BIT;
    imageInfo.tiling = VK_IMAGE_TILING_DRM_FORMAT_MODIFIER_EXT; // Critical for tiled buffers
    imageInfo.usage = VK_IMAGE_USAGE_SAMPLED_BIT;
    imageInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    imageInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

    VkImage vkImage = VK_NULL_HANDLE;
    if (vkCreateImage(*device, &imageInfo, nullptr, &vkImage) != VK_SUCCESS) {
        printf("vkCreateImage failed\n");
        return nullptr;
    }

    // 4. Import the dma_buf_fd into a VkDeviceMemory allocation
    // (Note: You must query the device for the correct memoryTypeIndex that supports this import)
    uint32_t memoryTypeIndex = 0; // Implement a helper to find this based on memory requirements

    VkImportMemoryFdInfoKHR importInfo = {};
    importInfo.sType = VK_STRUCTURE_TYPE_IMPORT_MEMORY_FD_INFO_KHR;
    importInfo.handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT;
    importInfo.fd = dmaBufFd; // Vulkan takes ownership of this FD! Do not close it yourself if success.

    VkMemoryAllocateInfo allocInfo = {};
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocInfo.pNext = &importInfo;
    VkMemoryRequirements memReq;
    vkGetImageMemoryRequirements(*device, vkImage, &memReq);
    allocInfo.allocationSize = memReq.size;
    allocInfo.memoryTypeIndex = memoryTypeIndex;

    VkDeviceMemory vkMemory = VK_NULL_HANDLE;
    if (vkAllocateMemory(*device, &allocInfo, nullptr, &vkMemory) != VK_SUCCESS) {
        vkDestroyImage(*device, vkImage, nullptr);
        close(dmaBufFd); // If import fails, we must manually close
        printf("vkAllocateMemory failed\n");
        return nullptr;
    }

    // 5. Bind the imported memory to the image
    vkBindImageMemory(*device, vkImage, vkMemory, 0);

    // 6. Wrap it in Skia's GrBackendTexture
    skgpu::VulkanAlloc alloc;
    alloc.fMemory = vkMemory;
    alloc.fOffset = 0;
    alloc.fSize = allocInfo.allocationSize;
    alloc.fFlags = 0;

    GrVkImageInfo skiaVkInfo;
    skiaVkInfo.fImage = vkImage;
    skiaVkInfo.fAlloc = alloc;
    skiaVkInfo.fImageTiling = VK_IMAGE_TILING_DRM_FORMAT_MODIFIER_EXT;
    skiaVkInfo.fImageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    skiaVkInfo.fFormat = vkFormat;
    skiaVkInfo.fImageUsageFlags = imageInfo.usage;
    skiaVkInfo.fSampleCount = 1;
    skiaVkInfo.fLevelCount = 1;

    // Depending on your Skia version, the MakeVk signature varies slightly
    GrBackendTexture backendTex = GrBackendTextures::MakeVk(width, height, skiaVkInfo);

    auto* cleanupCtx = new VulkanImageCleanupContext();
    cleanupCtx->device = *device; // Using your dereferenced device!
    cleanupCtx->image = vkImage;
    cleanupCtx->memory = vkMemory;

    // 7. Create the SkImage
    sk_sp<SkImage> image = SkImages::BorrowTextureFrom(
        engine->grContext,
        backendTex,
        kTopLeft_GrSurfaceOrigin,
        kRGBA_8888_SkColorType, 
        kPremul_SkAlphaType,
        nullptr, 
        
        // --- THE RELEASE PROC ---
        // Skia calls this automatically when the last reference to 'image' dies
        [](void* ctx) {
            if (!ctx) return;
            
            // Cast the raw void* back to our structural type
            auto* info = static_cast<VulkanImageCleanupContext*>(ctx);
            
            // Execute the native Vulkan cleanup sequence
            if (info->image != VK_NULL_HANDLE) {
                vkDestroyImage(info->device, info->image, nullptr);
            }
            if (info->memory != VK_NULL_HANDLE) {
                vkFreeMemory(info->device, info->memory, nullptr);
            }
            
            // CRITICAL: Delete the struct allocated on the heap to prevent CPU memory leaks
            delete info;
        },
        cleanupCtx // <-- This is what gets passed to the lambda as 'ctx'
    );
    if (!image.get()) {
        // Cleanup if Skia rejected it
        printf("Skia rejected the image\n");
        return nullptr; 
    }

    return new TennojiCanvasImage{.image = image};
}

bool rina_rsuperellipse_contains(
    float px, float py,            // The point to test
    float left, float top, 
    float right, float bottom,
    float tlRx, float tlRy,        // Top-Left Radii
    float trRx, float trRy,        // Top-Right Radii
    float blRx, float blRy,        // Bottom-Left Radii
    float brRx, float brRy         // Bottom-Right Radii
) {
    // 1. Basic Bounds Check
    if (px < left || px > right || py < top || py > bottom) {
        return false;
    }

    double dx = 0, dy = 0, rx = 0, ry = 0;
    double n = 2.4; // The "smoothness" exponent

    // 2. Identify which corner zone the point is in
    // Top-Left
    if (px < left + tlRx && py < top + tlRy) {
        dx = (left + tlRx) - px;
        dy = (top + tlRy) - py;
        rx = tlRx; ry = tlRy;
    } 
    // Top-Right
    else if (px > right - trRx && py < top + trRy) {
        dx = px - (right - trRx);
        dy = (top + trRy) - py;
        rx = trRx; ry = trRy;
    }
    // Bottom-Right
    else if (px > right - brRx && py > bottom - brRy) {
        dx = px - (right - brRx);
        dy = py - (bottom - brRy);
        rx = brRx; ry = brRy;
    }
    // Bottom-Left
    else if (px < left + blRx && py > bottom - blRy) {
        dx = (left + blRx) - px;
        dy = py - (bottom - blRy);
        rx = blRx; ry = blRy;
    }
    // 3. If not in a corner zone, it's in the central cross (always inside)
    else {
        return true;
    }

    // 4. Solve the superellipse inequality for the specific corner
    // Formula: (dx/rx)^n + (dy/ry)^n <= 1
    if (rx <= 0 || ry <= 0) return true; // Edge case for zero radius
    
    double val = pow(dx / rx, n) + pow(dy / ry, n);
    return val <= 1.0;
}
}
