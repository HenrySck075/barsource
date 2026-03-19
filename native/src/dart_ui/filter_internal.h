#pragma once
#include "include/core/SkColorFilter.h"
#include "include/core/SkImageFilter.h"
#include "tennoji/types.h"
extern "C" {

struct TennojiColorFilter {
  sk_sp<SkColorFilter> filter;
};
struct TennojiImageFilter {
  sk_sp<SkImageFilter> filter;
};

}
