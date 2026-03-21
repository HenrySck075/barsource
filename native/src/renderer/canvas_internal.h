#pragma once

#include "include/core/SkPaint.h"
#include "include/core/SkSurface.h"
#include "include/core/SkCanvas.h"
#include "tennoji/types.h"

struct TennojiEngine;

struct TennojiCanvas {
  sk_sp<SkSurface> surface;
  SkCanvas* canvas = nullptr;
  TennojiEngine* engine = nullptr;
};
SkPaint paint_create_from_encoded(TennojiCanvasPaintMetadata* metadata);
