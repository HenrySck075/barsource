#pragma once

#include "include/core/SkCanvas.h"
#include "include/core/SkContourMeasure.h"
#include "include/core/SkPathBuilder.h"
#include "include/core/SkPathMeasure.h"
#include "include/core/SkRefCnt.h"
#include <vector>

#ifdef __cplusplus
extern "C" {
#endif

struct TennojiCanvasPath {
  sk_sp<SkPathBuilder> builder;
};
struct TennojiCanvasPathMeasure {
  sk_sp<SkPathMeasure> measure;
  std::vector<sk_sp<const SkContourMeasure>> computedContours;
};

#ifdef __cplusplus
}
#endif // __cplusplus
