import 'package:barsource/src/dart_ui/dart_ui.dart' as ui;
import 'package:barsource/src/painting/inline_span.dart';
import 'package:barsource/src/painting/strut_style.dart';
import 'package:barsource/src/painting/text_painter.dart';
import 'package:barsource/src/painting/text_scaler.dart';
import 'package:barsource/src/painting/text_span.dart';
import 'package:barsource/src/painting/text_style.dart';
import 'package:barsource/src/rendering/paragraph.dart';
import 'package:barsource/src/widgets/framework.dart';
import 'package:barsource/src/widgets/inherited_theme.dart';

class RichText extends LeafRenderObjectWidget {
  const RichText({
    super.key,
    required this.text,
    this.textAlign = ui.TextAlign.start,
    this.textDirection,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.textScaler = TextScaler.noScaling,
    this.maxLines,
    this.locale,
    this.strutStyle,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
  });

  final InlineSpan text;
  final ui.TextAlign textAlign;
  final ui.TextDirection? textDirection;
  final bool softWrap;
  final TextOverflow overflow;
  final TextScaler textScaler;
  final int? maxLines;
  final ui.Locale? locale;
  final StrutStyle? strutStyle;
  final TextWidthBasis textWidthBasis;
  final ui.TextHeightBehavior? textHeightBehavior;

  @override
  RenderParagraph createRenderObject(BuildContext context) {
    return RenderParagraph(
      text,
      textAlign: textAlign,
      textDirection: textDirection ?? ui.TextDirection.ltr,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      locale: locale,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderParagraph renderObject) {
    renderObject
      ..text = text
      ..textAlign = textAlign
      ..textDirection = textDirection ?? ui.TextDirection.ltr
      ..softWrap = softWrap
      ..overflow = overflow
      ..textScaler = textScaler
      ..maxLines = maxLines
      ..locale = locale
      ..strutStyle = strutStyle
      ..textWidthBasis = textWidthBasis
      ..textHeightBehavior = textHeightBehavior;
  }
}

class Text extends StatelessWidget {
  const Text(this.text, {
    super.key,
    this.style,
    this.textAlign = ui.TextAlign.start,
    this.textDirection,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.textScaler = TextScaler.noScaling,
    this.maxLines,
    this.locale,
    this.strutStyle,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
  });

  final String text;
  final TextStyle? style;
  final ui.TextAlign textAlign;
  final ui.TextDirection? textDirection;
  final bool softWrap;
  final TextOverflow overflow;
  final TextScaler textScaler;
  final int? maxLines;
  final ui.Locale? locale;
  final StrutStyle? strutStyle;
  final TextWidthBasis textWidthBasis;
  final ui.TextHeightBehavior? textHeightBehavior;


  @override
  Widget build(BuildContext context) { 
    final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    TextStyle? effectiveTextStyle = style;
    if (style == null || style!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(style);
    }
    return RichText(
      text: TextSpan(
        text: text,
        style: effectiveTextStyle,
      ),
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      locale: locale,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior ?? defaultTextStyle.textHeightBehavior,
    ); 
  }
}

class _NullWidget extends StatelessWidget {
  const _NullWidget();

  @override
  Widget build(BuildContext context) {
    // apparently they dont allow using a fallback widget in here
    throw StateError('A DefaultTextStyle.fallback cannot be incorporated into the widget tree.');
  }
}

class DefaultTextStyle extends InheritedTheme {
  const DefaultTextStyle({
    super.key,
    required this.style,
    this.textAlign,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    required super.child,
  });
  const DefaultTextStyle.fallback({super.key})
    : style = const TextStyle(),
      textAlign = null,
      softWrap = true,
      overflow = TextOverflow.clip,
      maxLines = null,
      textWidthBasis = TextWidthBasis.parent,
      textHeightBehavior = null,
      super(child: const _NullWidget());

  final TextStyle style;
  final ui.TextAlign? textAlign;
  final bool softWrap;
  final TextOverflow overflow;
  final int? maxLines;
  final TextWidthBasis textWidthBasis;
  final ui.TextHeightBehavior? textHeightBehavior;

  static DefaultTextStyle of(BuildContext context) {
    final DefaultTextStyle? defaultTextStyle = context.dependOnInheritedWidgetOfExactType<DefaultTextStyle>();
    return defaultTextStyle ?? DefaultTextStyle.fallback();
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return DefaultTextStyle(
      style: style,
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      child: child,
    );
  }

   @override
   bool updateShouldNotify(covariant DefaultTextStyle oldWidget) {
     return style != oldWidget.style ||
         textAlign != oldWidget.textAlign ||
         softWrap != oldWidget.softWrap ||
         overflow != oldWidget.overflow ||
         maxLines != oldWidget.maxLines ||
         textWidthBasis != oldWidget.textWidthBasis ||
         textHeightBehavior != oldWidget.textHeightBehavior;
   }
}
