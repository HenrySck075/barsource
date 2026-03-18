#include "include/core/SkVertices.h"
#include "tennoji/engine.h"
#include "vertex_internal.h"

extern "C" {
TENNOJI_EXPORT TennojiCanvasVertices* tennoji_vertices_init(
  uint8_t mode,
  uint64_t length, // used by positions, textureCoordinates, colors assuming they matches the length
  float* positions, 
  float* textureCoordinates, // nullable
  int32_t* colors, // also nullable
  uint16_t* indices, uint64_t iLength
) {

  // construct SkPoint array from the positions array
  // x,y are stored sequentially
  SkPoint* skPoints = new SkPoint[length/2];
  for (uint64_t i = 0; i < length/2; i++) {
    skPoints[i] = SkPoint::Make(positions[i*2], positions[i*2 + 1]);
  }

  // similarly for textureCoordinates and colors
  // color is stored as one ARGB integer
  SkPoint* skTexCoords = nullptr;
  if (textureCoordinates) {
    skTexCoords = new SkPoint[length/2];
    for (uint64_t i = 0; i < length/2; i++) {
      skTexCoords[i] = SkPoint::Make(textureCoordinates[i*2], textureCoordinates[i*2 + 1]);
    }
  }

  SkColor* skColors = nullptr;
  if (colors) {
    skColors = new SkColor[length];
    for (uint64_t i = 0; i < length; i++) {
      // convert ARGB to SkColor (which is RGBA)
      uint32_t argb = static_cast<uint32_t>(colors[i]);
      uint8_t a = (argb >> 24) & 0xFF;
      uint8_t r = (argb >> 16) & 0xFF;
      uint8_t g = (argb >> 8) & 0xFF;
      uint8_t b = argb & 0xFF;
      skColors[i] = SkColorSetARGB(a, r, g, b);
    }
  }

  auto p = SkVertices::MakeCopy((SkVertices::VertexMode)mode, length/2, skPoints, skTexCoords, skColors, iLength, indices);
  return new TennojiCanvasVertices{
    .vertices = p
  };
};
TENNOJI_EXPORT void tennoji_vertices_destroy(TennojiCanvasVertices* vertices);
}
