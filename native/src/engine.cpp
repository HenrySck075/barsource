#include "engine_internal.h"

#include <cstring>
#include <thread>

extern "C" {

TENNOJI_EXPORT TennojiEngine* tennoji_engine_create(const TennojiEngineConfig* config) {
    if (!config) return nullptr;

    auto* engine = new TennojiEngine();
    engine->width = config->width;
    engine->height = config->height;
    engine->fps = config->fps;

    // Init GPU backend based on config->gpu_backend
    const char* backend = config->gpu_backend ? config->gpu_backend : "vulkan";
    engine->gpuCtx = tennoji::gpu_context_create(backend);
    if (engine->gpuCtx) {
        engine->grContext = engine->gpuCtx->grContext;
    }

    // Init thread pool (hardware concurrency or at least 4 threads)
    unsigned int nthreads = std::thread::hardware_concurrency();
    if (nthreads < 4) nthreads = 4;
    engine->threadPool = new tennoji::ThreadPool(nthreads);

    return engine;
}

TENNOJI_EXPORT void tennoji_engine_destroy(TennojiEngine* engine) {
    if (!engine) return;

    // Clear all textures before destroying GPU context
    {
        std::lock_guard<std::mutex> lock(engine->textureMutex);
        engine->textures.clear();
    }

    delete engine->threadPool;

    if (engine->grContext) {
        engine->grContext->abandonContext();
    }

    tennoji::gpu_context_destroy(engine->gpuCtx);
    delete engine;
}


} // extern "C"
