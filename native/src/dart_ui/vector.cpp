#include "include/core/SkPath.h"
#include "include/pathops/SkPathOps.h"
#include "include/private/base/SkPoint_impl.h"
#include "stuff.h"
#include "vector_internal.h"
#include "tennoji/engine.h"

#define RAD2DEG(x) ((x) * 180.0f / M_PI)

extern "C" {

TENNOJI_EXPORT TennojiCanvasPath* rina_path_create() {
  return new TennojiCanvasPath {
    .builder = std::make_unique<SkPathBuilder>()
  };
}

TENNOJI_EXPORT TennojiCanvasPath* rina_path_clone(TennojiCanvasPath* path) {
  return new TennojiCanvasPath {
    .builder = std::make_unique<SkPathBuilder>(*(path->builder))
  };
}

TENNOJI_EXPORT void rina_path_destroy(TennojiCanvasPath* path) {
  if (!path) return;
  delete path;
}

TENNOJI_EXPORT uint8_t rina_path_get_fill_type(TennojiCanvasPath* path) {
  return static_cast<uint8_t>(path->builder->fillType());
};
TENNOJI_EXPORT void rina_path_set_fill_type(TennojiCanvasPath* path, uint8_t type) {
  path->builder->setFillType(static_cast<SkPathFillType>(type));
};


TENNOJI_EXPORT void rina_path_move_to(TennojiCanvasPath* path, float x, float y) {
  path->builder->moveTo({x,y});
}
TENNOJI_EXPORT void rina_path_relative_move_to(TennojiCanvasPath* path, float dx, float dy) {
  path->builder->rMoveTo({dx,dy});
}

TENNOJI_EXPORT void rina_path_line_to(TennojiCanvasPath* path, float x, float y) {
  path->builder->lineTo({x,y});
}
TENNOJI_EXPORT void rina_path_relative_line_to(TennojiCanvasPath* path, float dx, float dy) {
  path->builder->rLineTo({dx,dy});
}

TENNOJI_EXPORT void rina_path_quadratic_to(
  TennojiCanvasPath* path, 
  float x1, float y1, float x2, float y2
) {
  path->builder->quadTo({x1,y1},{x2,y2});
}
TENNOJI_EXPORT void rina_path_relative_quadratic_to(
  TennojiCanvasPath* path, 
  float x1, float y1, float x2, float y2
) {
  path->builder->rQuadTo({x1,y1},{x2,y2});
}

TENNOJI_EXPORT void rina_path_cubic_to(
  TennojiCanvasPath* path, 
  float x1, float y1, float x2, float y2, float x3, float y3
) {
  path->builder->cubicTo({x1,y1},{x2,y2},{x3,y3});
}
TENNOJI_EXPORT void rina_path_relative_cubic_to(
  TennojiCanvasPath* path, 
  float x1, float y1, float x2, float y2, float x3, float y3
) {
  path->builder->rCubicTo({x1,y1},{x2,y2},{x3,y3});
}

TENNOJI_EXPORT void rina_path_conic_to(
  TennojiCanvasPath* path, 
  float x1, float y1, float x2, float y2, float w
) {
  path->builder->conicTo({x1,y1},{x2,y2},w);
}
TENNOJI_EXPORT void rina_path_relative_conic_to(
  TennojiCanvasPath* path, 
  float x1, float y1, float x2, float y2, float w
) {
  path->builder->rConicTo({x1,y1},{x2,y2},w);
}

TENNOJI_EXPORT void rina_path_arc_to_rect(
  TennojiCanvasPath* path,
  float left,
  float top,
  float right,
  float bottom,
  float startAngle,
  float sweepAngle,
  bool forceMoveTo
) {
  path->builder->arcTo(
    {left,top,right,bottom},
    RAD2DEG(startAngle),
    RAD2DEG(sweepAngle),
    forceMoveTo
  );
}
TENNOJI_EXPORT void rina_path_arc_to_point(
  TennojiCanvasPath* path,
  float arcEndX,
  float arcEndY,
  float radiusX,
  float radiusY,
  float rotation,
  bool largeArc,
  bool clockwise
) {
  path->builder->arcTo(
    {radiusX,radiusY},rotation,
    (SkPathBuilder::ArcSize)(!largeArc),
    (SkPathDirection)clockwise,
    {arcEndX,arcEndY}
  );
}
TENNOJI_EXPORT void rina_path_relative_arc_to_point(
  TennojiCanvasPath* path,
  float arcEndDeltaX,
  float arcEndDeltaY,
  float radiusX,
  float radiusY,
  float rotation,
  bool largeArc,
  bool clockwise
) {
  path->builder->rArcTo(
    {radiusX,radiusY},rotation,
    (SkPathBuilder::ArcSize)(!largeArc),
    (SkPathDirection)clockwise,
    {arcEndDeltaX,arcEndDeltaY}
  );
}


TENNOJI_EXPORT void rina_path_add_rect(
  TennojiCanvasPath* path, 
  float l, float t, float r, float b
) {
  path->builder->addRect({l,t,r,b});
}
TENNOJI_EXPORT void rina_path_add_oval(
  TennojiCanvasPath* path,
  float l, float t, float r, float b
) {
  path->builder->addOval({l,t,r,b});
}
TENNOJI_EXPORT void rina_path_add_arc(
  TennojiCanvasPath* path,
  float l, float t, float r, float b, float startAngle, float sweepAngle
) {
  path->builder->addArc({l,t,r,b},RAD2DEG(startAngle),RAD2DEG(sweepAngle));
}
TENNOJI_EXPORT void rina_path_add_polygon(
  TennojiCanvasPath* path,
  float* points, uint64_t length, bool close
) {
  SkPoint* skPoints = new SkPoint[length];
  for (uint64_t i = 0; i < length; i++) {
    skPoints[i] = {points[2*i], points[2*i + 1]};
  }
  path->builder->addPolygon({skPoints, (size_t)length}, close);
  delete[] skPoints;
}
TENNOJI_EXPORT void rina_path_add_rrect(
  TennojiCanvasPath* path,
  float* rrect_data 
) {
  // reinterprets everything after the 4th item (corresponds to tlRadiusX) as an array of 4 SkVectors
  SkRRect rrect;
  rrect.setRectRadii({rrect_data[0], rrect_data[1], rrect_data[2], rrect_data[3]}, (SkVector*)(rrect_data + 4));
  path->builder->addRRect(rrect);
}
TENNOJI_EXPORT void rina_path_add_rsuperellipse(TennojiCanvasPath* path, float* rsuperellipse_data) {
  // rsuperellipse_data is stored the same as rrect_data, in fact it contains the exact same set of data as rrect
  constexpr float smoothness = 0.67; // SIX SEVEN

  const float left = rsuperellipse_data[0];
  const float top = rsuperellipse_data[1];
  const float right = rsuperellipse_data[2];
  const float bottom = rsuperellipse_data[3];

  const float width = right - left;
  const float height = bottom - top;

  const float hw = width / 2;
  const float hh = height / 2;
  const float centerX = left + hw;
  const float centerY = top + hh;

  const float ox = hw * smoothness;
  const float oh = hh * smoothness;

  const auto builder = path->builder.get();

  builder->moveTo(centerX, top); // top-center

  // top-right
  builder->cubicTo(centerX + ox, top, right, centerY - oh, right, centerY);
  // bottom-right
  builder->cubicTo(right, centerY + oh, centerX + ox, bottom, centerX, bottom);
  // bottom-left
  builder->cubicTo(centerX - ox, bottom, left, centerY + oh, left, centerY);
  // top-left
  builder->cubicTo(left, centerY - oh, centerX - ox, top, centerX, top);

  // should probably be closed atp
  builder->close();
};

TENNOJI_EXPORT void rina_path_add_path_with_matrix(
  TennojiCanvasPath* path, TennojiCanvasPath* otherPath, 
  bool extend,
  float dx, float dy,
  float* matrix4
) {
  auto matrix = matrix_from_matrix4_array(matrix4);
  matrix->postTranslate(dx, dy);
  path->builder->addPath(otherPath->builder->snapshot(), *matrix, extend ? SkPath::kExtend_AddPathMode : SkPath::kAppend_AddPathMode);
}

TENNOJI_EXPORT void rina_path_add_path(
  TennojiCanvasPath* path, TennojiCanvasPath* otherPath, 
  bool extend,
  float dx, float dy
) {
  path->builder->addPath(otherPath->builder->snapshot(), dx,dy, extend ? SkPath::kExtend_AddPathMode : SkPath::kAppend_AddPathMode);
}


TENNOJI_EXPORT void rina_path_close(TennojiCanvasPath* path) {
  path->builder->close();
}
TENNOJI_EXPORT void rina_path_reset(TennojiCanvasPath* path) {
  path->builder->reset();
}

TENNOJI_EXPORT bool rina_path_contains(TennojiCanvasPath* path, float x, float y) {
  return path->builder->contains({x,y});
}
TENNOJI_EXPORT void rina_path_shift(TennojiCanvasPath* path, float x, float y) {
  path->builder->transform(SkMatrix::Translate(x,y));
}
TENNOJI_EXPORT void rina_path_transform(TennojiCanvasPath* path, float* matrix4) {
  path->builder->transform(*matrix_from_matrix4_array(matrix4));
}

TENNOJI_EXPORT bool rina_path_combine_op(
  TennojiCanvasPath* resultPath,
  TennojiCanvasPath* path1, TennojiCanvasPath* path2, 
  int operationId
) {
  SkPath betterPath;
  auto ret = Op(path1->builder->snapshot(), path2->builder->snapshot(), (SkPathOp)operationId, &betterPath);
  resultPath->builder = std::make_unique<SkPathBuilder>(betterPath);
  return ret;
}

TENNOJI_EXPORT float* rina_path_get_tight_bounds(TennojiCanvasPath* path) {
  auto bound = path->builder->computeTightBounds();
  // calloc so if bound is nullopt everything represents a zero-sized rect
  float* gamer = (float*)calloc(4, sizeof(float));
  if (bound.has_value()) {
    gamer[0] = bound->left();
    gamer[1] = bound->top();
    gamer[2] = bound->right();
    gamer[3] = bound->bottom();
  }
  return gamer;
}
TENNOJI_EXPORT float* rina_path_get_bounds(TennojiCanvasPath* path) {
  auto bound = path->builder->computeFiniteBounds();
  // calloc so if bound is nullopt everything represents a zero-sized rect
  float* gamer = (float*)calloc(4, sizeof(float));
  if (bound.has_value()) {
    gamer[0] = bound->left();
    gamer[1] = bound->top();
    gamer[2] = bound->right();
    gamer[3] = bound->bottom();
  }
  return gamer;
}



TENNOJI_EXPORT TennojiCanvasPathMeasure* rina_path_measure_create(
  TennojiCanvasPath* path, bool forceClose
) {
  return new TennojiCanvasPathMeasure {
    .measure = std::unique_ptr<SkPathMeasure>(new SkPathMeasure(path->builder->snapshot(), forceClose))
  };
}
TENNOJI_EXPORT void rina_path_measure_destroy(TennojiCanvasPathMeasure* measure) {
  if (!measure) return;
  delete measure;
};

TENNOJI_EXPORT double rina_path_measure_length(TennojiCanvasPathMeasure* measure, int32_t contourIndex) {
  if (contourIndex < 0 || contourIndex >= measure->computedContours.size()) return 0;
  return measure->computedContours[contourIndex]->length();
}
TENNOJI_EXPORT float* rina_path_measure_tangent_for_offset(TennojiCanvasPathMeasure* measure, int32_t contourIndex, double distance) {
  if (contourIndex < 0 || contourIndex >= measure->computedContours.size()) return nullptr;
  SkPoint position, tangent;
  if (!measure->computedContours[contourIndex]->getPosTan(distance, &position, &tangent)) {
    return nullptr;
  }
  float* gamer = (float*)malloc(4 * sizeof(float));
  gamer[0] = position.x();
  gamer[1] = position.y();
  gamer[2] = tangent.x();
  gamer[3] = tangent.y();
  return gamer;
} 
TENNOJI_EXPORT bool rina_path_measure_closed(TennojiCanvasPathMeasure* measure, int32_t contourIndex) {
  if (contourIndex < 0 || contourIndex >= measure->computedContours.size()) return false;
  return measure->computedContours[contourIndex]->isClosed();
} 
TENNOJI_EXPORT TennojiCanvasPath* rina_path_measure_extract(
  TennojiCanvasPathMeasure* measure,
  int32_t contourIndex,
  double start,
  double end,
  bool startWithMoveTo
) {
  if (contourIndex < 0 || contourIndex >= measure->computedContours.size()) return nullptr;
  auto builder = new SkPathBuilder();
  auto extracted = measure->computedContours[contourIndex]->getSegment(start,end, builder, startWithMoveTo);
  if (!extracted) {
    delete builder;
    return nullptr;
  }
  return new TennojiCanvasPath {
    .builder = std::unique_ptr<SkPathBuilder>(builder)
  };
}

TENNOJI_EXPORT bool rina_path_measure_next_contour(TennojiCanvasPathMeasure* measure) {
  auto contourAvailable = measure->doAdvanceContour ? measure->measure->nextContour() : measure->measure->currentMeasure() != nullptr;
  measure->doAdvanceContour = true;
  if (!contourAvailable) return 0;
  measure->computedContours.push_back(sk_ref_sp(measure->measure->currentMeasure()));
  return contourAvailable;
} 
}
