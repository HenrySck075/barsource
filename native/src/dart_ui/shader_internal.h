#pragma once

#include "include/core/SkShader.h"
extern "C" {

struct TennojiShader {
  virtual sk_sp<SkShader> getShader() = 0;
  virtual ~TennojiShader() = default;
};
}
