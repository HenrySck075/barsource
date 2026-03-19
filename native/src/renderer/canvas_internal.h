#pragma once

#include "include/core/SkPaint.h"
#include "include/core/SkSurface.h"
#include "include/core/SkCanvas.h"

struct TennojiEngine;

struct TennojiCanvas {
  sk_sp<SkSurface> surface;
  SkCanvas* canvas = nullptr;
  TennojiEngine* engine = nullptr;
};

