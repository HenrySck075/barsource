#include "filter_internal.h"
#include "include/core/SkColor.h"
#include "include/core/SkColorFilter.h"
#include "include/effects/SkColorMatrix.h"
#include "include/core/SkTileMode.h"
#include "include/effects/SkImageFilters.h"
#include "stuff.h"
#include "tennoji/engine.h"

extern "C" {

TennojiImageFilter* tennoji_mk_imgfilter_pointer(sk_sp<SkImageFilter> filter) {
  if (!filter) return nullptr;
  return new TennojiImageFilter{.filter = filter};
}

TennojiColorFilter* tennoji_mk_cfilter_pointer(sk_sp<SkColorFilter> filter) {
  if (!filter) return nullptr;
  return new TennojiColorFilter{.filter = filter};
}



TENNOJI_EXPORT TennojiColorFilter* rina_color_filter_create_mode(
  uint32_t color, 
  uint8_t blendMode // SkBlendMode
) {
  return tennoji_mk_cfilter_pointer(
    SkColorFilters::Blend(SkColor4f::FromBytes_RGBA(color), nullptr, static_cast<SkBlendMode>(blendMode))
  );
}
TENNOJI_EXPORT TennojiColorFilter* rina_color_filter_create_matrix(float* matrix20) {
  if (matrix20) return nullptr;
  SkColorMatrix matrix;
  matrix.setRowMajor(matrix20);
  return tennoji_mk_cfilter_pointer(
    SkColorFilters::Matrix(matrix)
  );
}
TENNOJI_EXPORT TennojiColorFilter* rina_color_filter_create_srgb2linear_gamma() {
  return tennoji_mk_cfilter_pointer(SkColorFilters::SRGBToLinearGamma());
}
TENNOJI_EXPORT TennojiColorFilter* rina_color_filter_create_linear2srgb_gamma() {
  return tennoji_mk_cfilter_pointer(SkColorFilters::LinearToSRGBGamma());
}
TENNOJI_EXPORT void rina_color_filter_destroy(TennojiColorFilter* color) {
  delete color;
}



TENNOJI_EXPORT TennojiImageFilter* rina_image_filter_create_blur(
  float sigmaX, float sigmaY,
  uint8_t tileMode,
  bool bounded,
  float boundsLeft, float boundsTop, float boundsRight, float boundsBottom
) {
  return tennoji_mk_imgfilter_pointer(SkImageFilters::Blur(
    sigmaX, 
    sigmaY, 
    tileMode < 0 ? SkTileMode::kDecal : (SkTileMode)tileMode, 
    nullptr, 
    bounded ? SkRect{boundsLeft, boundsTop, boundsRight, boundsBottom} : SkImageFilters::CropRect{}
  ));
}
TENNOJI_EXPORT TennojiImageFilter* rina_image_filter_create_dilate(
  float radiusX, float radiusY
) {
  return tennoji_mk_imgfilter_pointer(SkImageFilters::Dilate(radiusX, radiusY, nullptr));
}
TENNOJI_EXPORT TennojiImageFilter* rina_image_filter_create_erode(
  float radiusX, float radiusY
) {
  return tennoji_mk_imgfilter_pointer(SkImageFilters::Erode(radiusX, radiusY, nullptr));
}

TENNOJI_EXPORT TennojiImageFilter* rina_image_filter_create_matrix(
  float* matrix4, uint8_t filterQuality
) {
  return tennoji_mk_imgfilter_pointer(SkImageFilters::MatrixTransform(
    *matrix_from_matrix4_array(matrix4),
    sampling_from_quality_enum(filterQuality),
    nullptr
  ));
}

TENNOJI_EXPORT TennojiImageFilter* rina_image_filter_create_from_cf(
  TennojiColorFilter* filter
) {
  if (!filter) return nullptr;
  return tennoji_mk_imgfilter_pointer(SkImageFilters::ColorFilter(filter->filter, nullptr));
}

TENNOJI_EXPORT TennojiImageFilter* rina_image_filter_create_composed(
  TennojiImageFilter* outer,
  TennojiImageFilter* inner
) {
  /// TODO: probably return the other if one of them is nullptr and null if both is null
  return tennoji_mk_imgfilter_pointer(SkImageFilters::Compose(outer->filter, inner->filter));
}

TENNOJI_EXPORT void rina_image_filter_destroy(TennojiImageFilter* filter) {
  delete filter;
};
}
