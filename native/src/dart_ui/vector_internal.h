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
  /// Whether or not to actually advace to the next contour
  /// on the normal case its false on the first call to _next_contour and true otheewise, 
  /// simply because Dart iterator points to the element before the first one while SkPathMeasure is already in the first item
  bool doAdvanceContour = false; 
  std::unique_ptr<SkPathMeasure> measure;
  std::vector<sk_sp<const SkContourMeasure>> computedContours;
};

#ifdef __cplusplus
}
#endif // __cplusplus
