#include "include/core/SkImage.h"
#include "include/core/SkSamplingOptions.h"
#include "include/core/SkShader.h"
#include "include/core/SkString.h"
#include "include/effects/SkRuntimeEffect.h"
#include "include/effects/SkGradient.h"
#include "tennoji/engine.h"
#include "include/effects/SkGradient.h"
#include "include/core/SkMatrix.h"
#include "image_internal.h"
#include "src/shaders/SkImageShader.h"
#include <fstream>
#include <sstream>
#include "shader_internal.h"
#include "stuff.h"
const SkSamplingOptions sampling_from_quality_enum(uint8_t filterQuality) {
  switch (filterQuality) {
    case 1: return SkSamplingOptions(SkFilterMode::kLinear); // low
    case 2: return SkSamplingOptions(                        // medium
                     SkFilterMode::kLinear, 
                     SkMipmapMode::kLinear
                   ); 
    case 3: return SkSamplingOptions(SkCubicResampler::Mitchell());
    case 0: 
    default:return SkSamplingOptions(SkFilterMode::kNearest);// none
  }
}
SkGradient gradient_create(
  float* colors, // length must match stops, ordered as rgba, non-nullable 
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode // SkTileMode
) {
  // :)
  SkSpan<const SkColor4f> colorSpan{(SkColor4f*)colors, (size_t)length};
  SkSpan<const float> stopSpan{};
  if (stops) {
    stopSpan = {stops, (size_t)length};
  }

  return SkGradient(
    SkGradient::Colors(colorSpan, stopSpan, static_cast<SkTileMode>(tileMode)),
    {}
  );
}

std::unique_ptr<SkMatrix> matrix_from_matrix4_array(float* matrix4) {
  if (!matrix4) return nullptr;
  // its like 4x4 to 3x3 
  // also matrix4 is column-major
  SkMatrix* matrix = new SkMatrix();
  matrix->setAll(
    matrix4[0], matrix4[4], matrix4[12],
    matrix4[1], matrix4[5], matrix4[13],
    matrix4[3], matrix4[7], matrix4[15]
  );
  return std::unique_ptr<SkMatrix>(matrix);
}


extern "C" {

struct TennojiStaticShader : public TennojiShader {
  sk_sp<SkShader> shader;
  sk_sp<SkShader> getShader() override {return shader;}

  TennojiStaticShader(sk_sp<SkShader> shader) : shader(shader) {}
};

struct TennojiFragmentProgram {
  sk_sp<SkRuntimeEffect> effect;
};

TENNOJI_EXPORT TennojiShader* rina_gradient_create_linear(
  float x0, float y0, float x1, float y1,
  float* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  float* matrix4 // column-major ordered
) {
  SkPoint points[2] = {{x0,y0},{x1,y1}};
  auto matrix = matrix_from_matrix4_array(matrix4);
  auto shader = SkShaders::LinearGradient(
    points,
    gradient_create(colors, stops, length, tileMode),
    matrix.get()
  );
  return new TennojiStaticShader{shader};
}
TENNOJI_EXPORT TennojiShader* rina_gradient_create_radial(
  float cx, float cy, float radius,
  float* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  float* matrix4 
) {
  SkPoint center = {cx, cy};
  auto matrix = matrix_from_matrix4_array(matrix4);
  auto shader = SkShaders::RadialGradient(
    center, radius,
    gradient_create(colors, stops, length, tileMode),
    matrix.get()
  );
  return new TennojiStaticShader{shader};
}
TENNOJI_EXPORT TennojiShader* rina_gradient_create_sweep(
  float cx, float cy, 
  float startAngle, float endAngle,
  float* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  float* matrix4 
) {
  SkPoint center = {cx, cy};
  auto matrix = matrix_from_matrix4_array(matrix4);
  auto shader = SkShaders::SweepGradient(
    center, startAngle, endAngle,
    gradient_create(colors, stops, length, tileMode),
    matrix.get()
  );
  if (!shader) {
    return nullptr;
  }
  return new TennojiStaticShader{shader};
};
TENNOJI_EXPORT TennojiShader* rina_gradient_create_conical(
  float startCx, float startCy, float startRadius,
  float endCx, float endCy, float endRadius,
  float* colors, // length must match stops
  float* stops, // nullable, if null then it will be evenly distributed
  uint64_t length,
  uint32_t tileMode, // SkTileMode
  float* matrix4 
) {
  SkPoint start = {startCx, startCy};
  SkPoint end = {endCx, endCy};
  auto matrix = matrix_from_matrix4_array(matrix4);
  auto shader = SkShaders::TwoPointConicalGradient(
    start, startRadius,
    end, endRadius,
    gradient_create(colors, stops, length, tileMode),
    matrix.get()
  );
  if (!shader) {
    return nullptr;
  }
  return new TennojiStaticShader{shader};
}


TENNOJI_EXPORT TennojiShader* rina_image_shader_create(
  TennojiCanvasImage* image,
  uint8_t tileModeX, uint8_t tileModeY, // SkTileMode
  uint8_t filterQuality,
  float* matrix4
) {
  auto skimage = image->image;
  auto matrix = matrix_from_matrix4_array(matrix4);
  auto shader = SkImageShader::Make(
    skimage,
    (SkTileMode)tileModeX,
    (SkTileMode)tileModeY,
    sampling_from_quality_enum(filterQuality),
    matrix.get()
  );
  if (!shader) {
    return nullptr;
  }
  return new TennojiStaticShader{shader};
}
TENNOJI_EXPORT TennojiFragmentProgramResult rina_fragment_create(const char* filePath) {
  std::ifstream file(filePath);
  if (!file.is_open()) {
    return {nullptr, "Invalid or unreadable file path."};
  }
  std::stringstream buffer;
  buffer << file.rdbuf();
  SkString shaderCode(buffer.str().c_str());
  
  auto result = SkRuntimeEffect::MakeForShader(shaderCode);
  if (!result.effect) {
    return {nullptr, result.errorText.c_str()};
  }
  return {new TennojiFragmentProgram{
    .effect = result.effect
  }};
};

struct TennojiFragmentShader : public TennojiShader {
  TennojiFragmentProgram* program;
  sk_sp<SkData> uniformData;
  std::vector<std::pair<TennojiCanvasImage*,uint8_t>> imageSamplers;

  TennojiFragmentShader(
    TennojiFragmentProgram* prog,
    sk_sp<SkData> uniformData,
    uint64_t samplerCount
  ) : program(prog), uniformData(uniformData), imageSamplers(samplerCount) {}

  sk_sp<SkShader> getShader() override {
    if (!program || !program->effect) return nullptr;
    // for now we just create an empty uniform data blob, but in the future we will want to set this from dart
    if (!uniformData) {
      uniformData = SkData::MakeEmpty();
    }
    // construct a SkSpan<SkRuntimeEffect::ChildPtr> from imageSamplers array
    std::vector<SkRuntimeEffect::ChildPtr> samplers;
    for (auto image : imageSamplers) {
      if (image.first && image.first->image) {
        samplers.emplace_back(
          image.first->image->makeShader(sampling_from_quality_enum(image.second))
        );
      } else {
        return nullptr; // this never happens
      }
    }
    return program->effect->makeShader(uniformData, samplers);
  }
};

TENNOJI_EXPORT void rina_fragment_shader_set_image_sampler(
  TennojiFragmentShader* shader, 
  uint64_t index,
  TennojiCanvasImage* image, 
  uint8_t filterQuality
) {
  if (index >= shader->imageSamplers.size()) {
    // todo: tell dart the sampler index is out of bounds
    return;
  }
  shader->imageSamplers[index] = std::make_pair(image, filterQuality);
};

TENNOJI_EXPORT TennojiFragmentShader* rina_fragment_create_shader(
  TennojiFragmentProgram* prog,
  uint64_t floatCount,
  uint64_t samplerCount
) {
  return new TennojiFragmentShader(
    prog,
    SkData::MakeUninitialized((floatCount/* + 2 * samplerCount*/) * sizeof(float)), // what
    samplerCount
  );
}
TENNOJI_EXPORT float* rina_fragment_shader_get_uniform_buffer(TennojiFragmentShader* shader) {
  return reinterpret_cast<float*>(shader->uniformData->writable_data());
};

TENNOJI_EXPORT void rina_shader_destroy(TennojiShader* shader) {
  if (!shader) return;
  delete shader;
};


}
