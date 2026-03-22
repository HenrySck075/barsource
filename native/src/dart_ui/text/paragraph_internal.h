#pragma once

#include "modules/skparagraph/include/ParagraphBuilder.h"
#include "tennoji/export.h"
#include <memory>
__EXTERN_C__


struct TennojiParagraphBuilder {
  std::unique_ptr<skia::textlayout::ParagraphBuilder> builder;
};
struct TennojiParagraph {
  std::unique_ptr<skia::textlayout::Paragraph> paragraph;
};

__UNEXTERN_C__
