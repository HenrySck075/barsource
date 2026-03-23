#pragma once

#include "include/core/SkCanvas.h"
#include "include/core/SkContourMeasure.h"
#include "include/core/SkPathBuilder.h"
#include "include/core/SkPathMeasure.h"
#include "include/core/SkRefCnt.h"
#include <memory>
#include <vector>

#ifdef __cplusplus
extern "C" {
#endif

struct TennojiCanvasPath {
  std::unique_ptr<SkPathBuilder> builder;
};
struct TennojiCanvasPathMeasure {
  std::unique_ptr<SkPathMeasure> measure;
  std::vector<sk_sp<const SkContourMeasure>> computedContours;
};

#ifdef __cplusplus
}
#endif // __cplusplus
