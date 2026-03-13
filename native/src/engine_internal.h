#pragma once

#include "tennoji/engine.h"

#include "include/gpu/ganesh/GrDirectContext.h"
#include "include/core/SkImage.h"

#include "util/gpu_context.h"
#include "util/thread_pool.h"

#include <map>
#include <mutex>
#include <atomic>

struct TennojiEngine {
    GrDirectContext* grContext = nullptr;
    tennoji::GPUContext* gpuCtx = nullptr;
    tennoji::ThreadPool* threadPool = nullptr;

    // Texture registry: opaque int ID -> GPU SkImage
    std::map<int, sk_sp<SkImage>> textures;
    std::mutex textureMutex;
    std::atomic<int> nextTextureId{1};

    int32_t width = 0;
    int32_t height = 0;
    int32_t fps = 0;

    int register_texture(sk_sp<SkImage> image) {
        int id = nextTextureId.fetch_add(1);
        std::lock_guard<std::mutex> lock(textureMutex);
        textures[id] = std::move(image);
        return id;
    }

    sk_sp<SkImage> get_texture(int id) {
        std::lock_guard<std::mutex> lock(textureMutex);
        auto it = textures.find(id);
        if (it != textures.end()) return it->second;
        return nullptr;
    }

    void release_texture(int id) {
        std::lock_guard<std::mutex> lock(textureMutex);
        textures.erase(id);
    }
};
