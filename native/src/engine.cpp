#include "engine_internal.h"

#include <cstring>
#include <thread>

#include "include/codec/SkCodec.h"
#include "include/codec/SkJpegDecoder.h"
#include "include/codec/SkPngDecoder.h"
#include "include/codec/SkWebpDecoder.h"
#include "src/shaders/gradients/SkGradientBaseShader.h"

void setup_skia() {
  static bool doned = false;
  if (doned) return;
  SkCodecs::Register(SkPngDecoder::Decoder());
  SkCodecs::Register(SkJpegDecoder::Decoder());
  SkCodecs::Register(SkWebpDecoder::Decoder());


  SkRegisterConicalGradientShaderFlattenable();
  SkRegisterLinearGradientShaderFlattenable();
  SkRegisterRadialGradientShaderFlattenable();
  SkRegisterSweepGradientShaderFlattenable();
  doned = true;
}
extern "C" {

TENNOJI_EXPORT TennojiEngine* rina_engine_create(const TennojiEngineConfig* config) {
    if (!config) return nullptr;

    setup_skia();

    auto* engine = new TennojiEngine();
    engine->width = config->width;
    engine->height = config->height;
    engine->fps = config->fps;

    // Init GPU backend based on config->gpu_backend
    const char* backend = config->gpu_backend ? config->gpu_backend : "vulkan";
    engine->gpuCtx = tennoji::gpu_context_create(backend);
    if (engine->gpuCtx) {
        engine->grContext = engine->gpuCtx->grContext;
    } else {
      printf("no gpu?\n");
    }

    // Init thread pool (hardware concurrency or at least 4 threads)
    unsigned int nthreads = std::thread::hardware_concurrency();
    if (nthreads < 4) nthreads = 4;
    engine->threadPool = new tennoji::ThreadPool(nthreads);

    return engine;
}

TENNOJI_EXPORT void rina_engine_destroy(TennojiEngine* engine) {
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
