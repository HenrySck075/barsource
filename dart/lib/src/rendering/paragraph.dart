import 'package:barsource/src/painting/strut_style.dart';
import 'package:barsource/src/painting/text_painter.dart';
import 'package:barsource/src/painting/inline_span.dart';
import 'package:barsource/src/painting/basic_types.dart';
import 'package:barsource/src/painting/text_scaler.dart';
import 'package:barsource/src/rendering/box.dart';
import 'package:barsource/src/rendering/object.dart';
import 'package:barsource/src/dart_ui/dart_ui.dart' as ui;

export 'package:barsource/src/painting/text_painter.dart' show TextOverflow;

class RenderParagraph extends RenderBox {
  RenderParagraph(
    InlineSpan text, {
    ui.TextAlign textAlign = ui.TextAlign.start,
    ui.TextDirection textDirection = ui.TextDirection.ltr,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.clip,
    TextScaler textScaler = TextScaler.noScaling,
    int? maxLines,
    ui.Locale? locale,
    StrutStyle? strutStyle,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    ui.TextHeightBehavior? textHeightBehavior,
  }) : _textPainter = TextPainter(
         text: text,
         textAlign: textAlign,
         textDirection: textDirection,
         textScaler: textScaler,
         maxLines: maxLines,
         ellipsis: overflow == TextOverflow.ellipsis ? '\u2026' : null,
         locale: locale,
         strutStyle: strutStyle,
         textWidthBasis: textWidthBasis,
         textHeightBehavior: textHeightBehavior,
       ),
       _softWrap = softWrap,
       _overflow = overflow;

  final TextPainter _textPainter;

  InlineSpan get text => _textPainter.text!;
  set text(InlineSpan value) {
    if (_textPainter.text == value) return;
    _textPainter.text = value;
    markNeedsLayout();
    //markNeedsPaint();
  }

  ui.TextAlign get textAlign => _textPainter.textAlign;
  set textAlign(ui.TextAlign value) {
    if (_textPainter.textAlign == value) return;
    _textPainter.textAlign = value;
    //markNeedsPaint();
  }

  ui.TextDirection get textDirection => _textPainter.textDirection!;
  set textDirection(ui.TextDirection value) {
    if (_textPainter.textDirection == value) return;
    _textPainter.textDirection = value;
    markNeedsLayout();
    //markNeedsPaint();
  }

  bool get softWrap => _softWrap;
  bool _softWrap;
  set softWrap(bool value) {
    if (_softWrap == value) return;
    _softWrap = value;
    markNeedsLayout();
    //markNeedsPaint();
  }

  TextOverflow get overflow => _overflow;
  TextOverflow _overflow;
  set overflow(TextOverflow value) {
    if (_overflow == value) return;
    _overflow = value;
    _textPainter.ellipsis = value == TextOverflow.ellipsis ? '\u2026' : null;
    markNeedsLayout();
    //markNeedsPaint();
  }

  TextScaler get textScaler => _textPainter.textScaler;
  set textScaler(TextScaler value) {
    if (_textPainter.textScaler == value) return;
    _textPainter.textScaler = value;
    markNeedsLayout();
    //markNeedsPaint();
  }

  int? get maxLines => _textPainter.maxLines;
  set maxLines(int? value) {
    if (_textPainter.maxLines == value) return;
    _textPainter.maxLines = value;
    markNeedsLayout();
    //markNeedsPaint();
  }

  ui.Locale? get locale => _textPainter.locale;
  set locale(ui.Locale? value) {
    if (_textPainter.locale == value) return;
    _textPainter.locale = value;
    markNeedsLayout();
    //markNeedsPaint();
  }

  StrutStyle? get strutStyle => _textPainter.strutStyle;
  set strutStyle(StrutStyle? value) {
    if (_textPainter.strutStyle == value) return;
    _textPainter.strutStyle = value;
    markNeedsLayout();
    //markNeedsPaint();
  }

  TextWidthBasis get textWidthBasis => _textPainter.textWidthBasis;
  set textWidthBasis(TextWidthBasis value) {
    if (_textPainter.textWidthBasis == value) return;
    _textPainter.textWidthBasis = value;
    markNeedsLayout();
    //markNeedsPaint();
  }

  ui.TextHeightBehavior? get textHeightBehavior => _textPainter.textHeightBehavior;
  set textHeightBehavior(ui.TextHeightBehavior? value) {
    if (_textPainter.textHeightBehavior == value) return;
    _textPainter.textHeightBehavior = value;
    markNeedsLayout();
    //markNeedsPaint();
  }

  @override
  void performLayout() {
    _textPainter.layout(
        minWidth: constraints.minWidth,
        maxWidth: _softWrap ? constraints.maxWidth : double.infinity,
    );
    final double width = constraints.constrainWidth(_textPainter.width);
    final double height = constraints.constrainHeight(_textPainter.height);
    size = Size(width, height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _textPainter.paint(context.canvas, offset);
  }
}
