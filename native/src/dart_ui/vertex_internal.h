#pragma once

#include "include/core/SkCanvas.h"
#include "include/core/SkRefCnt.h"

#ifdef __cplusplus
extern "C" {
#endif

struct TennojiCanvasVertices {
  sk_sp<SkVertices> vertices;
};

#ifdef __cplusplus
}
#endif // __cplusplus
