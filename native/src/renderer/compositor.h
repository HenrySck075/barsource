#pragma once

#include "include/core/SkSurface.h"
#include "include/core/SkImage.h"

#include <vector>
#include <map>

struct TennojiEngine;

namespace tennoji {

struct CompositeLayer {
    int texture_id;
    float x, y;
    float scale_x, scale_y;
    float opacity;
};

// Composite a list of layers onto a target surface
void composite_layers(TennojiEngine* engine,
                      SkSurface* target,
                      const std::vector<CompositeLayer>& layers);

} // namespace tennoji
