#include "gpu_context.h"


#ifdef TENNOJI_IS_LINUX 
  #define TENNOJI_USE_VULKAN 1
#elif defined(TENNOJI_IS_MACOS)
  #define TENNOJI_USE_METAL 1
#elif defined(TENNOJI_IS_WINDOWS)
  #define TENNOJI_USE_D3D11 1
#endif

#ifdef TENNOJI_USE_VULKAN
  #include "include/gpu/ganesh/vk/GrVkDirectContext.h"
  #include "include/gpu/vk/VulkanBackendContext.h"
  #include "include/gpu/ganesh/GrDirectContext.h"
  #include "include/gpu/vk/VulkanExtensions.h"
  #include "src/gpu/vk/vulkanmemoryallocator/VulkanAMDMemoryAllocator.h"
  #include "src/gpu/vk/VulkanInterface.h"
  #include <vulkan/vulkan.h>
#endif

#ifdef TENNOJI_USE_METAL
  #include "include/gpu/ganesh/mtl/GrMtlDirectContext.h"
  #include "include/gpu/ganesh/mtl/GrMtlBackendContext.h"
#endif

#ifdef TENNOJI_USE_D3D11
  #include "include/gpu/ganesh/d3d/GrD3DDirectContext.h"
  #include <d3d11.h>
  #include <dxgi.h>
#endif

#include <cstring>

namespace tennoji {

#ifdef TENNOJI_USE_VULKAN

skgpu::VulkanExtensions extensions;
static GPUContext* create_vulkan_context() {
    auto* ctx = new GPUContext();
    ctx->type = GPUBackendType::Vulkan;

    // Create Vulkan instance
    VkApplicationInfo appInfo = {};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "tennoji";
    appInfo.apiVersion = VK_API_VERSION_1_1;

    VkInstanceCreateInfo instanceInfo = {};
    instanceInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    instanceInfo.pApplicationInfo = &appInfo;

    VkInstance instance = VK_NULL_HANDLE;
    if (vkCreateInstance(&instanceInfo, nullptr, &instance) != VK_SUCCESS) {
        delete ctx;
        printf("vkCreateInstance failed.\n");
        return nullptr;
    }

    // Select physical device
    uint32_t deviceCount = 0;
    if (vkEnumeratePhysicalDevices(instance, &deviceCount, nullptr) != VK_SUCCESS || deviceCount == 0) {
        vkDestroyInstance(instance, nullptr);
        delete ctx;
        printf("vkEnumeratePhysicalDevices (for getting device counts) failed.\n");
        return nullptr;
    }

    std::vector<VkPhysicalDevice> devices(deviceCount);
    if (vkEnumeratePhysicalDevices(instance, &deviceCount, devices.data()) != VK_SUCCESS) {
        vkDestroyInstance(instance, nullptr);
        delete ctx;
        printf("vkEnumeratePhysicalDevices (for getting real list) failed.\n");
        return nullptr;
    }
    VkPhysicalDevice physicalDevice = devices[0]; // Pick first device

    // Find graphics queue family
    uint32_t queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, nullptr);
    std::vector<VkQueueFamilyProperties> queueFamilies(queueFamilyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, queueFamilies.data());

    uint32_t graphicsFamily = UINT32_MAX;
    for (uint32_t i = 0; i < queueFamilyCount; i++) {
        if (queueFamilies[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
            graphicsFamily = i;
            break;
        }
    }
    if (graphicsFamily == UINT32_MAX) {
        vkDestroyInstance(instance, nullptr);
        delete ctx;
        printf("graphicsFamily unqueriable.\n");
        return nullptr;
    }

    // Create logical device
    float queuePriority = 1.0f;
    VkDeviceQueueCreateInfo queueCreateInfo = {};
    queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queueCreateInfo.queueFamilyIndex = graphicsFamily;
    queueCreateInfo.queueCount = 1;
    queueCreateInfo.pQueuePriorities = &queuePriority;

    VkDeviceCreateInfo deviceCreateInfo = {};
    deviceCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    deviceCreateInfo.queueCreateInfoCount = 1;
    deviceCreateInfo.pQueueCreateInfos = &queueCreateInfo;

    // Enable External Memory FD extension for zero-copy
    const char* deviceExtensions[] = {
        VK_KHR_EXTERNAL_MEMORY_FD_EXTENSION_NAME,
        VK_EXT_IMAGE_DRM_FORMAT_MODIFIER_EXTENSION_NAME,
        VK_EXT_EXTERNAL_MEMORY_DMA_BUF_EXTENSION_NAME
    };
    deviceCreateInfo.enabledExtensionCount = 3;
    deviceCreateInfo.ppEnabledExtensionNames = deviceExtensions;

    VkDevice device = VK_NULL_HANDLE;
    if (vkCreateDevice(physicalDevice, &deviceCreateInfo, nullptr, &device) != VK_SUCCESS) {
        vkDestroyInstance(instance, nullptr);
        delete ctx;
        printf("vkCreateDevice failed.\n");
        return nullptr;
    }

    VkQueue queue = VK_NULL_HANDLE;
    vkGetDeviceQueue(device, graphicsFamily, 0, &queue);

    ctx->native_device = device;
    ctx->native_queue = queue;
    ctx->native_display = instance;
    ctx->native_context = physicalDevice; // Store physical device for memory allocation

    // Create Skia GrDirectContext from Vulkan
    skgpu::VulkanBackendContext vkBackendCtx = {};

    vkBackendCtx.fInstance = instance;
    vkBackendCtx.fPhysicalDevice = physicalDevice;
    vkBackendCtx.fDevice = device;
    vkBackendCtx.fQueue = queue;
    vkBackendCtx.fGraphicsQueueIndex = graphicsFamily;
    vkBackendCtx.fMaxAPIVersion = VK_API_VERSION_1_1;
    vkBackendCtx.fVkExtensions = &extensions;
    vkBackendCtx.fGetProc = [](const char* name, VkInstance inst, VkDevice dev) {
        if (dev) return vkGetDeviceProcAddr(dev, name);
        if (inst) return vkGetInstanceProcAddr(inst, name);
        return vkGetInstanceProcAddr(VK_NULL_HANDLE, name); // Fallback for global lookups
    };
    vkBackendCtx.fMemoryAllocator = skgpu::VulkanAMDMemoryAllocator::Make(
        instance, 
        physicalDevice, 
        device, 
        VK_API_VERSION_1_1,
        vkBackendCtx.fVkExtensions,
        new skgpu::VulkanInterface(
            vkBackendCtx.fGetProc, 
            instance, 
            device, 
            VK_API_VERSION_1_1,
            VK_API_VERSION_1_1,
            vkBackendCtx.fVkExtensions
        ),
        (skgpu::ThreadSafe)true
    );
    extensions.init(
        vkBackendCtx.fGetProc, 
        instance, 
        physicalDevice, 
        0, nullptr,        // Instance extensions count/names if you have them
        deviceCreateInfo.enabledExtensionCount, 
        deviceCreateInfo.ppEnabledExtensionNames
    );

    ctx->grContext = GrDirectContexts::MakeVulkan(vkBackendCtx).release();
    if (!ctx->grContext) {
        vkDestroyDevice(device, nullptr);
        vkDestroyInstance(instance, nullptr);
        delete ctx;
        printf("grContext creation failed.\n");
        return nullptr;
    }

    return ctx;
}
#endif

#ifdef TENNOJI_USE_METAL
static GPUContext* create_metal_context() {
    auto* ctx = new GPUContext();
    ctx->type = GPUBackendType::Metal;

    // Metal device/queue creation is done through Objective-C;
    // Skia provides GrDirectContexts::MakeMetal which handles this.
    GrMtlBackendContext mtlBackendCtx = {};
    // In production, set mtlBackendCtx.fDevice and mtlBackendCtx.fQueue
    // from MTLCreateSystemDefaultDevice() / [device newCommandQueue].
    // Skia can also auto-create these.
    ctx->grContext = GrDirectContexts::MakeMetal(mtlBackendCtx).release();
    if (!ctx->grContext) {
        delete ctx;
        return nullptr;
    }
    return ctx;
}
#endif

#ifdef TENNOJI_USE_D3D11
static GPUContext* create_d3d11_context() {
    auto* ctx = new GPUContext();
    ctx->type = GPUBackendType::D3D11;

    // Create D3D11 device
    D3D_FEATURE_LEVEL featureLevel;
    ID3D11Device* device = nullptr;
    ID3D11DeviceContext* deviceContext = nullptr;

    HRESULT hr = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        nullptr, 0, D3D11_SDK_VERSION,
        &device, &featureLevel, &deviceContext
    );
    if (FAILED(hr)) {
        delete ctx;
        return nullptr;
    }

    ctx->native_device = device;
    ctx->native_context = deviceContext;

    // Create Skia GrDirectContext from D3D
    // Note: Skia uses ANGLE or Direct3D backend
    GrD3DBackendContext d3dBackendCtx = {};
    // Configure d3dBackendCtx with device...
    ctx->grContext = GrDirectContexts::MakeDirect3D(d3dBackendCtx).release();
    if (!ctx->grContext) {
        deviceContext->Release();
        device->Release();
        delete ctx;
        return nullptr;
    }

    return ctx;
}
#endif

GPUContext* gpu_context_create(const char* backend) {
    if (!backend) backend = "vulkan";

    printf("%s",backend);

#ifdef TENNOJI_USE_VULKAN
    if (strcmp(backend, "vulkan") == 0) {
        return create_vulkan_context();
    }
#endif

#ifdef TENNOJI_USE_METAL
    if (strcmp(backend, "metal") == 0) {
        return create_metal_context();
    }
#endif

#ifdef TENNOJI_USE_D3D11
    if (strcmp(backend, "d3d11") == 0) {
        return create_d3d11_context();
    }
#endif

    // Fallback: return a context without GPU acceleration
    // Skia will use a CPU rasterizer
    auto* ctx = new GPUContext();
    ctx->type = GPUBackendType::OpenGL;
    ctx->grContext = nullptr; // CPU fallback
    return ctx;
}

void gpu_context_destroy(GPUContext* ctx) {
    if (!ctx) return;

    if (ctx->grContext) {
        ctx->grContext->abandonContext();
        ctx->grContext->unref();
    }

#ifdef TENNOJI_USE_VULKAN
    if (ctx->type == GPUBackendType::Vulkan) {
        if (ctx->native_device) {
            vkDeviceWaitIdle(static_cast<VkDevice>(ctx->native_device));
            vkDestroyDevice(static_cast<VkDevice>(ctx->native_device), nullptr);
        }
        if (ctx->native_display) {
            vkDestroyInstance(static_cast<VkInstance>(ctx->native_display), nullptr);
        }
    }
#endif

#ifdef TENNOJI_USE_D3D11
    if (ctx->type == GPUBackendType::D3D11) {
        if (ctx->native_context) {
            static_cast<ID3D11DeviceContext*>(ctx->native_context)->Release();
        }
        if (ctx->native_device) {
            static_cast<ID3D11Device*>(ctx->native_device)->Release();
        }
    }
#endif

    delete ctx;
}

} // namespace tennoji
