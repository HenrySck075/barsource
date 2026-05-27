#include "image_internal.h"
#include "include/codec/SkCodec.h"
#include "include/core/SkData.h"
#include "include/core/SkImage.h"
#include "include/core/SkRefCnt.h"
#include <algorithm>
#include <filesystem>
#include <map>
#include "../engine_internal.h"
#include "include/gpu/ganesh/GrTypes.h"

extern "C" {

TENNOJI_EXPORT void rina_texture_destroy(TennojiCanvasImage* texture) {
  if (!texture) return;
  if (texture->managedByDecoder) return;
  delete texture;
}
TENNOJI_EXPORT void rina_engine_flush_textures(TennojiEngine* engine) {
  if (engine && engine->grContext) {
    engine->grContext->flushAndSubmit(GrSyncCpu::kYes);
    engine->grContext->freeGpuResources();
  }
}

TENNOJI_EXPORT int rina_texture_get_width(TennojiCanvasImage* texture) {
    return texture->image->width();
}

TENNOJI_EXPORT int rina_texture_get_height(TennojiCanvasImage* texture) {
    return texture->image->height();
}

TennojiCodec* rina_codec_from_encoded_skdata(sk_sp<SkData>& d) {
  SkCodec::Result r;
  auto codec = SkCodec::MakeFromData(d);
  if (!codec) return nullptr;
  auto info = codec->getInfo();

  return new TennojiCodec{
    .codec = std::move(codec),
    .fromRaw = false,
    .width = (uint32_t)info.width(),
    .height = (uint32_t)info.height(),
  };
}

TENNOJI_EXPORT TennojiCodec* rina_codec_from_encoded(const uint8_t* data, const uint64_t length) {
  auto d = SkData::MakeWithCopy(data, length);
  return rina_codec_from_encoded_skdata(d);
};
TENNOJI_EXPORT TennojiCodec* rina_codec_from_file(const char* path) {
  if (!std::filesystem::exists(path)) return nullptr;
  auto d = SkData::MakeFromFileName(path);
  if (!d) return nullptr;
  return rina_codec_from_encoded_skdata(d);
};

TENNOJI_EXPORT void rina_codec_destroy(TennojiCodec* codec) {
  if (codec) delete codec;
};

// intentionally unchecked (null checked on frontend) unless someone does batshit crazy with the (undetectable) inavlid address
TENNOJI_EXPORT int rina_codec_get_frame_count(TennojiCodec* codec) {
  return codec->fromRaw ? 1 : codec->codec->getFrameCount();
};
TENNOJI_EXPORT int rina_codec_get_repetition_count(TennojiCodec* codec) {
  return codec->fromRaw ? 0 : codec->codec->getRepetitionCount();
};

TENNOJI_EXPORT TennojiFrameInfo* rina_codec_get_frame_info(TennojiCodec* codec, int index) {
  if (codec->fromRaw) {
    // in this case, codec->codec is nullptr

    // 11/10 this is going to be a static image
    // we will make an image then pretend its something coming out of a static SkCodec

    auto img = SkImages::RasterFromPixmapCopy(SkPixmap(
      /*fInfo =*/ SkImageInfo::Make(
        /*width =*/ codec->width,
        /*height =*/ codec->height,
        /*colorType =*/ SkColorType::kRGBA_8888_SkColorType,
        /*alphaType =*/ SkAlphaType::kPremul_SkAlphaType,
        /*colorSpace =*/ nullptr
      ),
      /*fPixels =*/ codec->buffer->data(),
      /*fRowBytes =*/ codec->width * 4
    ));

    return new TennojiFrameInfo{
      .durationMs = 0,
      .image = new TennojiCanvasImage{img}
    };
  }
  // the else
  if (codec->codec->isAnimated() == SkCodec::IsAnimated::kYes) {
    SkCodec::FrameInfo info;
    bool res = codec->codec->getFrameInfo(index,&info);
    if (!res) return nullptr;

    SkCodec::Options o;
    o.fFrameIndex = index;
    o.fPriorFrame = info.fRequiredFrame;
    auto ret = codec->codec->getImage(codec->codec->getInfo(),&o);
    auto img = std::get<0>(ret);
    return new TennojiFrameInfo{
      .durationMs = info.fDuration,
      .image = new TennojiCanvasImage{img}
    };
  } else {
    auto ret = codec->codec->getImage(codec->codec->getInfo());
    auto img = std::get<0>(ret);
    return new TennojiFrameInfo{
      .durationMs = 0,
      .image = new TennojiCanvasImage{img}
    };
  }
}

TENNOJI_EXPORT void rina_frame_info_destroy(TennojiFrameInfo* info) {
  if (info) delete info;
}

// ImageDescriptor
TENNOJI_EXPORT TennojiImageDescriptor* rina_idesc_from_encoded(const uint8_t* data, const uint32_t length) {
  // to avoid copying we will let the dart side handles the data memory
  auto d = SkData::MakeWithoutCopy(data, length);

  auto codec = rina_codec_from_encoded_skdata(d); 
  if (!codec) return nullptr;

  auto ret = new TennojiImageDescriptor {
    .buffer = d,
    .imageInfo = {
      .width = codec->width,
      .height = codec->height,
      .format = TennojiImageDescriptor::PixelFormat::kBGRA8888, // we believe
      .alphaType = codec->codec->getInfo().alphaType(),
      .colorSpace = sk_sp(codec->codec->getInfo().colorSpace()),
    },
    .fromRaw = false
  };
  
  rina_codec_destroy(codec);
  return ret;
};
TENNOJI_EXPORT TennojiImageDescriptor* rina_idesc_from_raw(
  const uint8_t* data, 
  const uint32_t width, const uint32_t height,
  int8_t rowBytes,
  const int8_t pixelFormat
) {
  const char bytesPerPixel = 4;
  if (rowBytes < 0) {// usually -1
    rowBytes = width * bytesPerPixel;
  }

  auto d = SkData::MakeWithoutCopy(data, height * rowBytes);

  return new TennojiImageDescriptor {
    .buffer = d,
    .imageInfo = {
      .width = width,
      .height = height,
      .format = static_cast<TennojiImageDescriptor::PixelFormat>(pixelFormat),
      .alphaType = SkAlphaType::kPremul_SkAlphaType, // we believe
      .colorSpace = nullptr,
    },
    .fromRaw = true
  };
};

TENNOJI_EXPORT uint32_t rina_idesc_get_width(TennojiImageDescriptor* descriptor) {
  return descriptor->imageInfo.width;
}
TENNOJI_EXPORT uint32_t rina_idesc_get_height(TennojiImageDescriptor* descriptor) {
  return descriptor->imageInfo.height;
}

TENNOJI_EXPORT TennojiCodec* rina_idesc_instantiate_codec(
  TennojiImageDescriptor* descriptor,
  uint32_t targetWidth, uint32_t targetHeight, uint8_t targetPixelFormat
) {
  if (!descriptor->fromRaw) return rina_codec_from_encoded_skdata(descriptor->buffer);

  return new TennojiCodec{
    .codec = nullptr,
    .fromRaw = true,
    .buffer = descriptor->buffer,
    .width = descriptor->imageInfo.width,
    .height = descriptor->imageInfo.height,
    .format = descriptor->imageInfo.format
  };
};
TENNOJI_EXPORT void rina_idesc_destroy(TennojiImageDescriptor* descriptor) {
  if (descriptor) delete descriptor;
};

TENNOJI_EXPORT bool rina_texture_equals(
  TennojiCanvasImage* tex1,
  TennojiCanvasImage* tex2
);
}
