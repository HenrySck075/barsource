// glorified data holders

#include "include/codec/SkCodec.h"
#include "include/core/SkImage.h"
#include "tennoji/engine.h"
#include <memory>

extern "C" {
struct TennojiCanvasImage {
  sk_sp<SkImage> image;
  bool managedByDecoder = false;
};
struct TennojiImageDescriptor {
  // This must be kept in sync with the enum in painting.dart
  enum PixelFormat {
    // Error pixel format for Skia compatibility.
    kUnknown = 0,
    kRGBA8888,
    kBGRA8888,
    kRGBAFloat32,
    kR32Float,
    kGray8,
  };
  struct ImageInfo {
    const uint32_t width;
    const uint32_t height;
    const PixelFormat format;
    const SkAlphaType alphaType;
    const sk_sp<SkColorSpace> colorSpace;
  }; 

  sk_sp<SkData> buffer;
  const ImageInfo imageInfo;
  bool fromRaw;
};

struct TennojiCodec {
  std::unique_ptr<SkCodec> codec;

  bool fromRaw;
  // everything after the field above only matter if its true
  sk_sp<SkData> buffer;
  uint32_t width, height;
  TennojiImageDescriptor::PixelFormat format;
};
}
