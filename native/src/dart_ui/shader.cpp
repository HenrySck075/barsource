#include "include/core/SkImage.h"
#include "include/effects/SkGradient.h"
#include "tennoji/engine.h"
#include "src/shaders/gradients/SkLinearGradient.h"
extern "C" {


struct TennojiShader {
  virtual void shader() = 0;// lets just leave it here
};

struct TennojiCanvasGradient {
  sk_sp<SkShader> shader;
};

SkGradient gradient_create(
  uint32_t* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode // SkTileMode
) {
  SkSpan<const SkColor4f> colorSpan{reinterpret_cast<SkColor4f*>(colors), (size_t)length};
  SkSpan<const float> stopSpan{};
  if (stops) {
    stopSpan = {stops, (size_t)length};
  }

  return SkGradient(
    SkGradient::Colors(colorSpan, stopSpan, static_cast<SkTileMode>(tileMode)),
    {}
  );
}

TENNOJI_EXPORT TennojiCanvasGradient* tennoji_gradient_init_linear(
  float x0, float y0, float x1, float y1,
  uint32_t* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  double* matrix4 // aka SkMatrix
) {
};
TENNOJI_EXPORT TennojiCanvasGradient* tennoji_gradient_init_radial(
  float cx, float cy, float radius,
  uint32_t* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  double* matrix4 
);
TENNOJI_EXPORT TennojiCanvasGradient* tennoji_gradient_init_sweep(
  float cx, float cy, 
  float startAngle, float endAngle,
  uint32_t* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  double* matrix4 
);
TENNOJI_EXPORT TennojiCanvasGradient* tennoji_gradient_init_conical(
  float startCx, float startCy, float startRadius,
  float endCx, float endCy, float endRadius,
  uint32_t* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  double* matrix4 
);
TENNOJI_EXPORT void tennoji_gradient_destroy(TennojiCanvasGradient* gradient);



}