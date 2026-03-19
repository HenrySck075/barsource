#pragma once

#include "include/core/SkMatrix.h"
#include "include/core/SkSamplingOptions.h"
#include <memory>
std::unique_ptr<SkMatrix> matrix_from_matrix4_array(float* matrix4);

// Defined in renderer/canvas.cpp
const SkSamplingOptions sampling_from_quality_enum(uint8_t filterQuality);
