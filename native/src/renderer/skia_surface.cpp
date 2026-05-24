#include "skia_surface.h"
#include "../util/gpu_context.h"

#include "include/core/SkSurface.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#include "include/gpu/ganesh/vk/GrVkBackendSurface.h"
#include "include/gpu/ganesh/vk/GrVkTypes.h"
#include "include/gpu/ganesh/GrBackendSurface.h"
#include "include/core/SkColorSpace.h"

#if defined(__linux__) && !defined(__ANDROID__)
#define TENNOJI_USE_VULKAN 1
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_core.h>
#include <unistd.h>
#include <iostream>
#include "include/gpu/vk/VulkanTypes.h"
#include "drm/drm_fourcc.h"
#endif

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

#if defined(TENNOJI_USE_VULKAN)
PFN_vkGetImageDrmFormatModifierPropertiesEXT pfnGetImageDrmFormatModifierPropertiesEXT = nullptr;

static void init_vulkan_extensions(VkDevice device) {
  if (!pfnGetImageDrmFormatModifierPropertiesEXT) {
    pfnGetImageDrmFormatModifierPropertiesEXT = (PFN_vkGetImageDrmFormatModifierPropertiesEXT)vkGetDeviceProcAddr(device, "vkGetImageDrmFormatModifierPropertiesEXT");
    if (!pfnGetImageDrmFormatModifierPropertiesEXT) {
      std::cerr << "Failed to get vkGetImageDrmFormatModifierPropertiesEXT" << std::endl;
    }
  }
}

static uint32_t find_memory_type(VkPhysicalDevice physicalDevice, uint32_t typeFilter, VkMemoryPropertyFlags properties) {
    VkPhysicalDeviceMemoryProperties memProperties;
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties);

    for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++) {
        if ((typeFilter & (1 << i)) && (memProperties.memoryTypes[i].propertyFlags & properties) == properties) {
            return i;
        }
    }
    return -1;
}

ExportableSurface create_exportable_gpu_surface(GPUContext* ctx, int32_t width, int32_t height) {
    ExportableSurface result;
    if (!ctx || ctx->type != GPUBackendType::Vulkan) return result;

    VkDevice device = (VkDevice)ctx->native_device;
    init_vulkan_extensions(device); // TODO: figure out where to better place this
    VkPhysicalDevice physicalDevice = (VkPhysicalDevice)ctx->native_context;
    
    // Get function pointer for vkGetMemoryFdKHR
    auto vkGetMemoryFdKHR = (PFN_vkGetMemoryFdKHR)vkGetDeviceProcAddr(device, "vkGetMemoryFdKHR");
    if (!vkGetMemoryFdKHR) {
        std::cerr << "Failed to get vkGetMemoryFdKHR" << std::endl;
        return result;
    }

    uint64_t modifiers[] = {
      I915_FORMAT_MOD_4_TILED,
      I915_FORMAT_MOD_Y_TILED,
      I915_FORMAT_MOD_X_TILED,
      DRM_FORMAT_MOD_LINEAR
    };
    VkImageDrmFormatModifierListCreateInfoEXT modifierListInfo = {};
    modifierListInfo.sType = VK_STRUCTURE_TYPE_IMAGE_DRM_FORMAT_MODIFIER_LIST_CREATE_INFO_EXT;
    modifierListInfo.drmFormatModifierCount = sizeof(modifiers) / sizeof(modifiers[0]);
    modifierListInfo.pDrmFormatModifiers = modifiers;

    // Create Image
    VkExternalMemoryImageCreateInfo externalImageInfo = {};
    externalImageInfo.sType = VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO;
    externalImageInfo.pNext = &modifierListInfo;
    externalImageInfo.handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT;

    VkImageCreateInfo imageInfo = {};
    imageInfo.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    imageInfo.pNext = &externalImageInfo;
    imageInfo.imageType = VK_IMAGE_TYPE_2D;
    imageInfo.extent.width = (uint32_t)width;
    imageInfo.extent.height = (uint32_t)height;
    imageInfo.extent.depth = 1;
    imageInfo.mipLevels = 1;
    imageInfo.arrayLayers = 1;
    imageInfo.format = VK_FORMAT_B8G8R8A8_UNORM; 
    imageInfo.tiling = VK_IMAGE_TILING_DRM_FORMAT_MODIFIER_EXT;
    imageInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    imageInfo.usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_SAMPLED_BIT;
    imageInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    imageInfo.samples = VK_SAMPLE_COUNT_1_BIT;

    VkImage image;
    if (vkCreateImage(device, &imageInfo, nullptr, &image) != VK_SUCCESS) {
        std::cerr << "Failed to create VkImage" << std::endl;
        return result;
    }

    // Allocate Memory
    VkMemoryRequirements memRequirements;
    vkGetImageMemoryRequirements(device, image, &memRequirements);

    VkExportMemoryAllocateInfo exportAllocInfo = {};
    exportAllocInfo.sType = VK_STRUCTURE_TYPE_EXPORT_MEMORY_ALLOCATE_INFO;
    exportAllocInfo.handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT;

    VkMemoryAllocateInfo allocInfo = {};
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocInfo.pNext = &exportAllocInfo;
    allocInfo.allocationSize = memRequirements.size;
    allocInfo.memoryTypeIndex = find_memory_type(physicalDevice, memRequirements.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);

    VkDeviceMemory imageMemory;
    if (vkAllocateMemory(device, &allocInfo, nullptr, &imageMemory) != VK_SUCCESS) {
        std::cerr << "Failed to allocate VkDeviceMemory" << std::endl;
        vkDestroyImage(device, image, nullptr);
        return result;
    }

    vkBindImageMemory(device, image, imageMemory, 0);

    // Get FD
    VkMemoryGetFdInfoKHR fdInfo = {};
    fdInfo.sType = VK_STRUCTURE_TYPE_MEMORY_GET_FD_INFO_KHR;
    fdInfo.memory = imageMemory;
    fdInfo.handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT;

    int fd = -1;
    if (vkGetMemoryFdKHR(device, &fdInfo, &fd) != VK_SUCCESS) {
        std::cerr << "Failed to get memory FD" << std::endl;
        vkFreeMemory(device, imageMemory, nullptr);
        vkDestroyImage(device, image, nullptr);
        return result;
    }

    // Wrap in SkSurface
    skgpu::VulkanAlloc valloc;
    valloc.fMemory = imageMemory;
    valloc.fOffset = 0;
    valloc.fSize = memRequirements.size;
    valloc.fFlags = 0;

    GrVkImageInfo grInfo;
    grInfo.fImage = image;
    grInfo.fAlloc = valloc;
    grInfo.fImageTiling = VK_IMAGE_TILING_DRM_FORMAT_MODIFIER_EXT;
    grInfo.fImageLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    grInfo.fFormat = VK_FORMAT_B8G8R8A8_UNORM;
    grInfo.fLevelCount = 1;
    grInfo.fCurrentQueueFamily = VK_QUEUE_FAMILY_IGNORED;
    grInfo.fProtected = skgpu::Protected::kNo;
    
    // Explicitly using GrBackendTextures::MakeVk instead of newer MakeVulkan
    GrBackendTexture backendTexture = GrBackendTextures::MakeVk(width, height, grInfo);

    SkSurfaceProps props(0, kUnknown_SkPixelGeometry);
    sk_sp<SkSurface> surface = SkSurfaces::WrapBackendTexture(
        ctx->grContext,
        backendTexture,
        kTopLeft_GrSurfaceOrigin,
        1,
        kBGRA_8888_SkColorType,
        nullptr,
        &props
    );

    if (!surface) {
         std::cerr << "Failed to wrap backend texture" << std::endl;
         close(fd);
         vkFreeMemory(device, imageMemory, nullptr);
         vkDestroyImage(device, image, nullptr);
         return result;
    }

    result.skSurface = surface;
    result.vkImage = (void*)image;
    result.vkMemory = (void*)imageMemory;
    result.fd = fd;
    // the new thing
    {
      VkImageDrmFormatModifierPropertiesEXT g;
      g.sType = VK_STRUCTURE_TYPE_IMAGE_DRM_FORMAT_MODIFIER_PROPERTIES_EXT;
      if (pfnGetImageDrmFormatModifierPropertiesEXT(device, image, &g) != VK_SUCCESS) {
        printf("uhm no modifier\n");
      } else {
        result.modifier = g.drmFormatModifier;
      }
      VkSubresourceLayout g2;
      VkImageSubresource irsc{VK_IMAGE_ASPECT_MEMORY_PLANE_0_BIT_EXT, 0, 0};
      vkGetImageSubresourceLayout(device, image, &irsc, &g2);
      result.pitch = g2.rowPitch;
    }
    return result;
}

void ExportableSurface::release(GPUContext* ctx) {
    if (!ctx || ctx->type != GPUBackendType::Vulkan) return;
    VkDevice device = (VkDevice)ctx->native_device;
    
    if (fd != -1) close(fd);
    if (vkImage) vkDestroyImage(device, (VkImage)vkImage, nullptr);
    if (vkMemory) vkFreeMemory(device, (VkDeviceMemory)vkMemory, nullptr);
}

#else

ExportableSurface create_exportable_gpu_surface(GPUContext* ctx, int32_t width, int32_t height) {
    ExportableSurface result;
    return result;
}

void ExportableSurface::release(GPUContext* ctx) {}

#endif

} // namespace tennoji
