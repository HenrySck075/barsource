import 'package:tennoji/src/dart_ui/dart_ui.dart' as ui;
import 'package:tennoji/src/rendering/object.dart';
import 'package:tennoji/src/widgets/framework.dart';

typedef InlineSpan = TextSpan;

class TextSpan {
  const TextSpan({
    this.text,
    this.children,
    /*super*/this.style,
    this.locale,
  });
  /// The text contained in this span.
  ///
  /// If both [text] and [children] are non-null, the text will precede the
  /// children.
  ///
  /// This getter does not include the contents of its children.
  final String? text;
  /// Additional spans to include as children.
  ///
  /// If both [text] and [children] are non-null, the text will precede the
  /// children.
  ///
  /// Modifying the list after the [TextSpan] has been created is not supported
  /// and may have unexpected results.
  ///
  /// The list must not contain any nulls.
  final List<InlineSpan>? children;
  /// The [TextStyle] to apply to this span.
  ///
  /// The [style] is also applied to any child spans when this is an instance
  /// of [TextSpan].
  final TextStyle? style;

  /// The language of the text in this span and its span children.
  ///
  /// Setting the locale of this text span affects the way that assistive
  /// technologies, such as VoiceOver or TalkBack, pronounce the text.
  ///
  /// If this span contains other text span children, they also inherit the
  /// locale from this span unless explicitly set to different locales.
  final ui.Locale? locale;


  /// Apply the [style], [text], and [children] of this object to the
  /// given [ParagraphBuilder], from which a [Paragraph] can be obtained.
  /// [Paragraph] objects can be drawn on [Canvas] objects.
  ///
  /// Rather than using this directly, it's simpler to use the
  /// [TextPainter] class to paint [TextSpan] objects onto [Canvas]
  /// objects.
  @override
  void build(
    ui.ParagraphBuilder builder, {
    TextScaler textScaler = TextScaler.noScaling,
    List<PlaceholderDimensions>? dimensions,
  }) {
    //assert(debugAssertIsValid());
    final hasStyle = style != null;
    if (hasStyle) {
      builder.pushStyle(style!.getTextStyle(textScaler: textScaler));
    }
    if (text != null) {
      try {
        builder.addText(text!);
      } on ArgumentError catch (exception, stack) {
        /*
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'painting library',
            context: ErrorDescription('while building a TextSpan'),
            silent: true,
          ),
        );
        */
        // Use a Unicode replacement character as a substitute for invalid text.
        builder.addText('\uFFFD');
      }
    }
    final List<InlineSpan>? children = this.children;
    if (children != null) {
      for (final InlineSpan child in children) {
        child.build(builder, textScaler: textScaler, dimensions: dimensions);
      }
    }
    if (hasStyle) {
      builder.pop();
    }
  }
}


class RichText extends MultiChildRenderObjectWidget {
  @override
  RenderObject createRenderObject(BuildContext context) {
    // TODO: implement createRenderObject
    throw UnimplementedError();
  }
  
}
