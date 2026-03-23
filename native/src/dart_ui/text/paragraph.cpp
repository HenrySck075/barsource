
#include "include/core/SkColor.h"
#include "include/core/SkData.h"
#include "include/core/SkFontStyle.h"
#include "modules/skparagraph/include/FontCollection.h"
#include "modules/skparagraph/include/Metrics.h"
#include "modules/skparagraph/include/TypefaceFontProvider.h"
#include "modules/skparagraph/include/ParagraphStyle.h"
#include "modules/skparagraph/include/TextStyle.h"
#include "modules/skunicode/include/SkUnicode.h"
#include "tennoji/engine.h"
#include "modules/skparagraph/include/ParagraphBuilder.h"
#include "modules/skunicode/include/SkUnicode_icu.h"
#include "tennoji/types.h"
#include "tennoji/export.h"
#include "../../renderer/canvas_internal.h"
#include "paragraph_internal.h"
#include <execution>
#include <string>
#include "include/core/SkFontScanner.h"

skia::textlayout::StrutStyle strut_style_from_encoded(
  uint8_t* d,
  /*const std::vector<std::string>&*/ const char** strutFontFamilies,
  uint32_t sffLen
) {
  // i checked, all of them are 32bit
  auto strutData = reinterpret_cast<uint32_t*>(d);
  
  // declared in the same order as the data itself
  auto mask = *reinterpret_cast<int32_t*>(&strutData[0]) ;
#define maskbit(idx) (mask & (1 << idx))
  uint8_t byteIndex = 1;
  auto fontWeight = maskbit(0) ? *reinterpret_cast<int32_t*>(&strutData[byteIndex++]) : 400;
  auto fontStyle = maskbit(1) ? *reinterpret_cast<int32_t*>(&strutData[byteIndex++]) : 0;
  auto fontSize = maskbit(4) ? *reinterpret_cast<float*>(&strutData[byteIndex++]) : 0;
  auto overrideHeight = maskbit(5) ? *reinterpret_cast<float*>(&strutData[byteIndex++]) : 0;
  auto leading = maskbit(6) ? *reinterpret_cast<float*>(&strutData[byteIndex++]) : 0;
  bool forceStrutHeight = maskbit(7);

  skia::textlayout::StrutStyle style;
  style.setFontStyle({fontWeight,SkFontStyle::kNormal_Width,SkFontStyle::kItalic_Slant});
  style.setForceStrutHeight(forceStrutHeight);
  style.setFontSize(fontSize);
  style.setHeight(overrideHeight); style.setHeightOverride(maskbit(5));
  style.setLeading(leading);
  if (strutFontFamilies)
    style.setFontFamilies({strutFontFamilies, strutFontFamilies+sffLen});

  return style;
#undef maskbit
}

// The encoded array buffer has 6 elements.
//
//  - Element 0: A bit mask indicating which fields are non-null.
//    Bit 0 is unused. Bits 1-n are set if the corresponding index in the
//    encoded array is non-null.  The remaining bits represent fields that
//    are passed separately from the array.
//
//  - Element 1: The enum index of the |textAlign|.
//
//  - Element 2: The enum index of the |textDirection|.
//
//  - Element 3: The index of the |fontWeight|.
//
//  - Element 4: The enum index of the |fontStyle|.
//
//  - Element 5: The value of |maxLines|.
//
//  - Element 6: The encoded value of |textHeightBehavior|, except its leading
//    distribution.
//    Specifically, `(applyHeightToFirstAscent ? 0 : 1 << 0) | (applyHeightToLastDescent ? 0 : 1 << 1)```
//  - Element 7: The value of |fontSize|
//  - Element 8: The value of |height|
skia::textlayout::ParagraphStyle paragraph_style_from_encoded(
  int32_t* encodedStyle,
  uint8_t* strutData,
  /*const std::vector<std::string>&*/ const char** strutFontFamilies,
  uint32_t sffLen,
  /*const std::u16string&*/ const char* ellipsis,
  /*const std::string&*/ const char* locale
) {
  auto mask = encodedStyle[0]; // nobody cares
  auto textAlign = static_cast<skia::textlayout::TextAlign>(encodedStyle[1]);
  auto textDirection = static_cast<skia::textlayout::TextDirection>(encodedStyle[2]);
  auto fontWeight = (encodedStyle[3]);
  auto fontStyleEnum = (encodedStyle[4]);
  auto maxLines = encodedStyle[5];
  auto textHeightBehavior = encodedStyle[6];

  skia::textlayout::ParagraphStyle style;
  skia::textlayout::TextStyle textStyle;
  SkFontStyle fontStyle(fontWeight, SkFontStyle::kNormal_Width, (SkFontStyle::Slant)fontStyleEnum);
  textStyle.setFontStyle(fontStyle);
  style.setTextStyle(textStyle);
  style.setTextAlign(textAlign);
  style.setTextDirection(textDirection);
  style.setHeight((float)(encodedStyle[8]));
  if (strutData)
    style.setStrutStyle(strut_style_from_encoded(strutData, strutFontFamilies, sffLen));
  style.setEllipsis(SkString(ellipsis));

  return style;
}

// The encoded array buffer has 8 elements.
//
//  - Element 0: A bit field where the ith bit indicates whether the ith element
//    has a non-null value. Bits 8 to 12 indicate whether |fontFamily|,
//    |fontSize|, |letterSpacing|, |wordSpacing|, and |height| are non-null,
//    respectively. Bit 0 indicates the [TextLeadingDistribution] of the text
//    style.
//
//  - Element 1: The |color| in ARGB with 8 bits per channel.
//
//  - Element 2: A bit field indicating which text decorations are present in
//    the |textDecoration| list. The ith bit is set if there's a TextDecoration
//    with enum index i in the list.
//
//  - Element 3: The |decorationColor| in ARGB with 8 bits per channel.
//
//  - Element 4: The bit field of the |decorationStyle|.
//
//  - Element 5: The index of the |fontWeight|.
//
//  - Element 6: The enum index of the |fontStyle|.
//
//  - Element 7: The enum index of the |textBaseline|.
skia::textlayout::TextStyle text_style_from_encoded(
  int32_t* encoded,
  const char** fontFamilies,
  uint32_t ffLength,
  float fontSize,
  float letterSpacing,
  float wordSpacing,
  float height,
  float decorationThickness,
  const char* locale,
  TennojiCanvasPaintMetadata* background,
  TennojiCanvasPaintMetadata* foreground,

  uint32_t* shadowsData,
  uint32_t* fontFeaturesData,
  uint32_t* fontVariationsData
) {
  skia::textlayout::TextStyle style;

  auto state = encoded[0];
#define maskbit(idx) (state & (1 << idx))
  auto color = maskbit(1) ? (SkColor)encoded[1] : SkColor(0xffffffff);
  auto decorationMask = encoded[2];
  auto decorationColor = encoded[3];
  auto decorationStyleMask = encoded[4];
  auto fontWeight = encoded[5];
  auto fontStyleEnum = encoded[6];
  auto textBaselineEnum = encoded[7];

  style.setColor(color);
  style.setDecoration((skia::textlayout::TextDecoration)decorationMask);
  style.setDecorationColor(decorationColor);
  style.setDecorationStyle((skia::textlayout::TextDecorationStyle)decorationStyleMask);
  SkFontStyle fontStyle(
      fontWeight, 
      SkFontStyle::kNormal_Width, 
      (SkFontStyle::Slant)fontStyleEnum
  );
  style.setFontStyle(fontStyle);
  style.setTextBaseline(static_cast<skia::textlayout::TextBaseline>(textBaselineEnum));
  if (fontFamilies)
    style.setFontFamilies({fontFamilies, fontFamilies+ffLength});
  if (maskbit(9))
    style.setFontSize(fontSize);
  if (maskbit(10))
    style.setLetterSpacing(letterSpacing);
  if (maskbit(11))
    style.setWordSpacing(wordSpacing);
  if (maskbit(12))
    style.setHeight(height);
  style.setLocale(SkString(locale));

  if (background)
    style.setBackgroundPaint(paint_create_from_encoded(background));
  if (foreground)
    style.setForegroundPaint(paint_create_from_encoded(foreground));

  static const int _kShadowColorDefault = 0xff000000;
  const auto shadowsCount = shadowsData[0];
  for (uint32_t i = 0; i < shadowsCount; i++) {
    const uint32_t dex = 1 + (i*4);
    const auto shadowColor = *reinterpret_cast<int32_t*>(&shadowsData[dex]);
    const auto shadowOffsetX = *reinterpret_cast<float*>(&shadowsData[dex+1]);
    const auto shadowOffsetY = *reinterpret_cast<float*>(&shadowsData[dex+2]);
    const auto shadowBlurSigma = *reinterpret_cast<float*>(&shadowsData[dex+3]); 

    style.addShadow({
      (SkColor)shadowColor,
      {shadowOffsetX, shadowOffsetY},
      shadowBlurSigma
    });
  }

  {
    const uint32_t count = fontFeaturesData[0];

    for (uint32_t i = 0; i < count; i++) {
      const char* featureName = 
        reinterpret_cast<const char*>(fontFeaturesData[i*8 + 4]);
      const int32_t featureValue = 
        *reinterpret_cast<int32_t*>(&fontFeaturesData[i*8 + 8]);
      style.addFontFeature({featureName,4}, featureValue);
    }
  }

  return style;
#undef maskbit
}

// Platform-specific FontMgr factories
#if defined(TENNOJI_IS_WINDOWS)
    #include "include/ports/SkTypeface_win.h"
#elif defined(TENNOJI_IS_MACOS)
    #include "include/ports/SkFontMgr_mac_ct.h"
#elif defined(TENNOJI_IS_LINUX)
    #include "include/ports/SkFontMgr_fontconfig.h"
#elif defined(TENNOJI_IS_TERMUX)
    #include "include/ports/SkFontMgr_android_ndk.h"
    #include "include/ports/SkFontScanner_FreeType.h" // For font scanning logic
#endif

__EXTERN_C__

static sk_sp<skia::textlayout::FontCollection> g_collector;
static sk_sp<skia::textlayout::TypefaceFontProvider> g_provider;
void LoadDefaultFontManager() {
    sk_sp<SkFontMgr> fontMgr = nullptr;

    #if defined(TENNOJI_IS_WINDOWS)
        // DirectWrite is the standard for modern Windows apps
        fontMgr = SkFontMgr_New_DirectWrite();
    #elif defined(TENNOJI_IS_MACOS)
        // CoreText handles macOS/iOS
        fontMgr = SkFontMgr_New_CoreText(nullptr);
    #elif defined(TENNOJI_IS_LINUX)
        // Uses Fontconfig to locate system fonts
        fontMgr = SkFontMgr_New_FontConfig(nullptr,nullptr);
    #elif defined(TENNOJI_IS_TERMUX)
        // Create the scanner first (FreeType is the standard choice)
        auto scanner = SkFontScanner_Make_FreeType();
        
        // Create the NDK-specific Font Manager
        // First param: bool is_system_font_mgr (usually false for custom usage, true for system)
        fFontMgr = SkFontMgr_New_AndroidNDK(scanner); 
        
        // Fallback if NDK API is too old or fails
        if (!fFontMgr) {
            fFontMgr = SkFontMgr_New_Android(nullptr);
        }
    #endif

    if (fontMgr && g_collector) {
        g_collector->setDefaultFontManager(std::move(fontMgr));
    } else {
        // Fallback: You might want to load an empty font manager 
        // to prevent crashes if no system fonts are found.
        // probably
        g_collector->setDefaultFontManager(SkFontMgr::RefEmpty());
    }
}
void setup_font_collection() {
  static bool configured = false;
  if (configured) return;

  g_collector = sk_make_sp<skia::textlayout::FontCollection>();
  g_provider = sk_make_sp<skia::textlayout::TypefaceFontProvider>();
  
  LoadDefaultFontManager();

  g_collector->setAssetFontManager(g_provider);
}

TENNOJI_EXPORT TennojiParagraphBuilder* rina_paragraph_builder_create(
  int32_t* encodedStyle,
  uint8_t* strutData,
  bool hasStrutData,
  /*const std::string&*/ const char* fontFamily,
  /*const std::vector<std::string>&*/ const char** strutFontFamilies,
  uint32_t sffLen,
  /*const std::u16string&*/ const char* ellipsis,
  /*const std::string&*/ const char* locale
) {
  if (!hasStrutData) strutData = nullptr;

  return new TennojiParagraphBuilder{
    .builder = std::move(skia::textlayout::ParagraphBuilder::make(
      paragraph_style_from_encoded(
        encodedStyle, strutData, 
        strutFontFamilies, 
        sffLen, 
        ellipsis, 
        locale
      ),
      g_collector,
      SkUnicodes::ICU::Make()
    ))
  };
}

TENNOJI_EXPORT void rina_paragraph_builder_push_style(
  TennojiParagraphBuilder* builder,
  int32_t* encoded,
  const char** fontFamilies,
  uint32_t ffLength,
  float fontSize,
  float letterSpacing,
  float wordSpacing,
  float height,
  float decorationThickness,
  const char* locale,
  TennojiCanvasPaintMetadata* background,
  TennojiCanvasPaintMetadata* foreground,
  uint32_t* shadowsData,
  uint32_t* fontFeaturesData,
  uint32_t* fontVariationsData
) {
  builder->builder->pushStyle(text_style_from_encoded(
    encoded, fontFamilies, ffLength, fontSize, letterSpacing, wordSpacing, height, decorationThickness, locale, background, foreground, shadowsData, fontFeaturesData, fontVariationsData
  ));
}

TENNOJI_EXPORT void rina_paragraph_builder_pop(
  TennojiParagraphBuilder* builder
) {
  builder->builder->pop();
}
TENNOJI_EXPORT void rina_paragraph_builder_add_text(
  TennojiParagraphBuilder* builder,
  const char* text
) {
  builder->builder->addText(text);
}
TENNOJI_EXPORT void rina_paragraph_builder_add_placeholder(
  TennojiParagraphBuilder* builder,
  float width,
  float height,
  uint32_t alignment,
  float baselineOffset,
  uint32_t baseline
) {
  builder->builder->addPlaceholder({
    width, height,
    static_cast<skia::textlayout::PlaceholderAlignment>(alignment),
    static_cast<skia::textlayout::TextBaseline>(baseline),
    baselineOffset,
  });
}
TENNOJI_EXPORT TennojiParagraph* rina_paragraph_builder_build(
  TennojiParagraphBuilder* builder
) {
  auto paragraph = builder->builder->Build();
  if (paragraph == nullptr) return nullptr;
  return new TennojiParagraph{
    .paragraph = std::move(paragraph)
  };
}
TENNOJI_EXPORT void rina_paragraph_builder_destroy(
  TennojiParagraphBuilder* builder
) {
  delete builder;
}

TENNOJI_EXPORT void rina_load_font_from_list(
  const uint8_t* data, uint32_t length,
  const char* fontFamily
) {
    // 1. Wrap the raw bytes into a SkData object (ref-counted)
    // We use MakeWithCopy to ensure the engine owns the memory
    sk_sp<SkData> fontData = SkData::MakeWithCopy(data, length);

    // 3. Create the typeface from the data
    // The index 0 refers to the first font face in the collection (e.g., .ttc)
    sk_sp<SkTypeface> typeface = g_provider->makeFromData(fontData, 0);

    if (!typeface) {
        // Handle error: The data was likely corrupted or an invalid format
        return ;
    }

    if (fontFamily)
      g_provider->registerTypeface(typeface, SkString(fontFamily));
    else
      g_provider->registerTypeface(typeface);
}

__UNEXTERN_C__

float* encodeTextBoxes(std::vector<skia::textlayout::TextBox> boxes) {
  uint32_t length = boxes.size();
  float* ret = (float*)malloc(sizeof(float)*(length*5+1));
  ret[0] = *reinterpret_cast<float*>(&length);
  float* list = ret+1;
  // store ltrbd sequentially
  for (size_t i = 0; i < length; i++) {
    list[i*5 + 0] = boxes[i].rect.fLeft;
    list[i*5 + 1] = boxes[i].rect.fTop;
    list[i*5 + 2] = boxes[i].rect.fRight;
    list[i*5 + 3] = boxes[i].rect.fBottom;
    list[i*5 + 4] = static_cast<float>(boxes[i].direction);
  };
  return ret;
}

__EXTERN_C__

TENNOJI_EXPORT float rina_paragraph_get_width(TennojiParagraph* paragraph) {
  return paragraph->paragraph->getMaxWidth();
}
TENNOJI_EXPORT float rina_paragraph_get_height(TennojiParagraph* paragraph) {
  return paragraph->paragraph->getHeight();
}
TENNOJI_EXPORT float rina_paragraph_get_longest_line(TennojiParagraph* paragraph) {
  return paragraph->paragraph->getLongestLine();
}
TENNOJI_EXPORT float rina_paragraph_get_min_intrinsic_width(TennojiParagraph* paragraph) {
  return paragraph->paragraph->getMinIntrinsicWidth();
}
TENNOJI_EXPORT float rina_paragraph_get_max_intrinsic_width(TennojiParagraph* paragraph) {
  return paragraph->paragraph->getMaxIntrinsicWidth();
}
TENNOJI_EXPORT float rina_paragraph_get_alphabetic_baseline(TennojiParagraph* paragraph) {
  return paragraph->paragraph->getAlphabeticBaseline();
}
TENNOJI_EXPORT float rina_paragraph_get_ideographic_baseline(TennojiParagraph* paragraph) {
  return paragraph->paragraph->getIdeographicBaseline();
}
TENNOJI_EXPORT bool rina_paragraph_did_exceed_max_lines(TennojiParagraph* paragraph) {
  return paragraph->paragraph->didExceedMaxLines();
}
TENNOJI_EXPORT void rina_paragraph_layout(TennojiParagraph* paragraph, double width) {
  paragraph->paragraph->layout(width);
}


TENNOJI_EXPORT float* rina_paragraph_get_boxes_for_range(
  TennojiParagraph* paragraph,
  uint32_t start, uint32_t end,
  uint8_t boxHeightStyle,
  uint8_t boxWidthStyle
) {
  return encodeTextBoxes(paragraph->paragraph->getRectsForRange(
    start, end, 
    static_cast<skia::textlayout::RectHeightStyle>(boxHeightStyle),
    static_cast<skia::textlayout::RectWidthStyle>(boxWidthStyle)
  ));
}
TENNOJI_EXPORT float* rina_paragraph_get_boxes_for_placeholders(
  TennojiParagraph* paragraph
) {
  return encodeTextBoxes(paragraph->paragraph->getRectsForPlaceholders());
}
TENNOJI_EXPORT int32_t* rina_paragraph_get_position_for_offset(
  TennojiParagraph* paragraph,
  double dx, double dy
) {
  auto ret = static_cast<int32_t*>(malloc(sizeof(int32_t)*2));
  auto idk = paragraph->paragraph->getGlyphPositionAtCoordinate(dx, dy);
  ret[0] = idk.position;
  ret[1]= idk.affinity;
  return ret;
}

__UNEXTERN_C__
int32_t* packGlyphInfo(skia::textlayout::Paragraph::GlyphInfo& info) {
  auto ret = static_cast<int32_t*>(malloc(sizeof(uint32_t)*9));
  // rect ltrb
  auto bounds = info.fGraphemeLayoutBounds;
  ret[0] = *reinterpret_cast<int32_t*>(&bounds.fLeft);
  ret[1] = *reinterpret_cast<int32_t*>(&bounds.fTop);
  ret[2] = *reinterpret_cast<int32_t*>(&bounds.fRight);
  ret[3] = *reinterpret_cast<int32_t*>(&bounds.fBottom);
  // text range
  auto range = info.fGraphemeClusterTextRange;
  ret[4] = range.start;
  ret[5] = range.end;
  // text dir
  ret[6] = (int32_t)info.fDirection;

  return ret;

}
__EXTERN_C__
TENNOJI_EXPORT int32_t* rina_paragraph_get_glyph_info_at(
  TennojiParagraph* paragraph,
  int32_t codeUnitOffset
) {
  skia::textlayout::Paragraph::GlyphInfo info;
  auto d = paragraph->paragraph->getGlyphInfoAtUTF16Offset(codeUnitOffset,&info);
  if (!d) return nullptr;
  return packGlyphInfo(info);
}
TENNOJI_EXPORT int32_t* rina_paragraph_get_glyph_info_for_offset(
  TennojiParagraph* paragraph,
  double dx, double dy
) {
  skia::textlayout::Paragraph::GlyphInfo info;
  auto d = paragraph->paragraph->getClosestUTF16GlyphInfoAt(dx,dy,&info);
  if (!d) return nullptr;
  return packGlyphInfo(info);
}
TENNOJI_EXPORT int32_t* rina_paragraph_get_word_boundary(
  TennojiParagraph* paragraph,
  int64_t characterPos
) {
  auto range = paragraph->paragraph->getWordBoundary(characterPos);
  auto ret = static_cast<int32_t*>(malloc(sizeof(int32_t)*2));
  ret[0] = range.start;
  ret[1] = range.end;
  return ret;
}
TENNOJI_EXPORT int32_t* rina_paragraph_get_line_boundary(
  TennojiParagraph* paragraph,
  int64_t offset
) {
  skia::textlayout::LineMetrics metrics;
  auto range = paragraph->paragraph->getLineMetricsAt(offset, &metrics);
  if (!range) return nullptr;
  auto ret = static_cast<int32_t*>(malloc(sizeof(int32_t)*2));
  ret[0] = metrics.fStartIndex;
  ret[1] = metrics.fEndIndex;
  return ret;
}
TENNOJI_EXPORT float* rina_paragraph_compute_line_metrics(
  TennojiParagraph* paragraph
) {
  std::vector<skia::textlayout::LineMetrics> metrics;
  paragraph->paragraph->getLineMetrics(metrics);

  /* dart code as a reference
       LineMetrics(
          hardBreak: encoded[position++] != 0,
          ascent: encoded[position++],
          descent: encoded[position++],
          unscaledAscent: encoded[position++],
          height: encoded[position++],
          width: encoded[position++],
          left: encoded[position++],
          baseline: encoded[position++],
          lineNumber: encoded[position++].toInt(),
        ),
  */

  uint32_t length = metrics.size();
  float* ret = (float*)malloc(sizeof(float)*length);
  ret[0] = *reinterpret_cast<float*>(&length);

  float* list = ret+1;
  for (size_t i = 0; i < length; i++) {
    list[i*9 + 0] = metrics[i].fHardBreak ? 1.0f : 0.0f;
    list[i*9 + 1] = metrics[i].fAscent;
    list[i*9 + 2] = metrics[i].fDescent;
    list[i*9 + 3] = metrics[i].fUnscaledAscent;
    list[i*9 + 4] = metrics[i].fHeight;
    list[i*9 + 5] = metrics[i].fWidth;
    list[i*9 + 6] = metrics[i].fLeft;
    list[i*9 + 7] = metrics[i].fBaseline;
    list[i*9 + 8] = (float)metrics[i].fLineNumber;
  }

  return ret;
}
TENNOJI_EXPORT float* rina_paragraph_get_line_metrics_at(
  TennojiParagraph* paragraph,
  uint64_t lineNumber
) {
  skia::textlayout::LineMetrics metrics;
  auto d = paragraph->paragraph->getLineMetricsAt(lineNumber, &metrics);
  if (!d) return nullptr;

  float* ret = (float*)malloc(sizeof(float)*9);
  ret[0] = metrics.fHardBreak ? 1.0f : 0.0f;
  ret[1] = metrics.fAscent;
  ret[2] = metrics.fDescent;
  ret[3] = metrics.fUnscaledAscent;
  ret[4] = metrics.fHeight;
  ret[5] = metrics.fWidth;
  ret[6] = metrics.fLeft;
  ret[7] = metrics.fBaseline;
  ret[8] = (float)metrics.fLineNumber;

  return ret;
}
TENNOJI_EXPORT uint64_t rina_paragraph_get_number_of_lines(
  TennojiParagraph* paragraph
) {
  return paragraph->paragraph->lineNumber();
}
TENNOJI_EXPORT uint64_t rina_paragraph_get_line_number_at(
  TennojiParagraph* paragraph,
  int64_t codeUnitOffset
) {
  return paragraph->paragraph->getLineNumberAtUTF16Offset(codeUnitOffset);
}
TENNOJI_EXPORT void rina_paragraph_destroy(
  TennojiParagraph* paragraph
) {
  delete paragraph;
}

__UNEXTERN_C__
