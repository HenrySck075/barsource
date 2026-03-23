#pragma once

#include "include/core/SkPaint.h"
#include "include/core/SkSurface.h"
#include "include/core/SkCanvas.h"
#include "tennoji/types.h"

struct TennojiEngine;

#include "include/core/SkPictureRecorder.h"

struct TennojiCanvas {
  std::unique_ptr<SkPictureRecorder> recorder;
  SkCanvas* canvas = nullptr;
  TennojiEngine* engine = nullptr;
  int width = 0;
  int height = 0;
};
SkPaint paint_create_from_encoded(TennojiCanvasPaintMetadata* metadata);
