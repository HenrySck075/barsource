import 'package:barsource/src/foundation/object.dart';
import 'package:barsource/src/painting/edge_insets.dart';
import 'basic_types.dart';

abstract class Decoration {
  const Decoration();

  BoxPainter createBoxPainter([VoidCallback? onChanged]);

  EdgeInsetsGeometry get padding => EdgeInsets.zero;
  
  bool get isComplex => false;

  bool debugAssertIsValid() => true;

  @override
  String toStringShort() => objectRuntimeType(this, 'Decoration');
}

abstract class BoxPainter {
  const BoxPainter([this.onChanged]);

  final VoidCallback? onChanged;

  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration);

  void dispose() {}
}

class ImageConfiguration {
  const ImageConfiguration({
    this.bundle,
    this.devicePixelRatio,
    this.locale,
    this.textDirection,
    this.size,
    this.platform,
  });

  final Object? bundle;
  final double? devicePixelRatio;
  final Locale? locale;
  final TextDirection? textDirection;
  final Size? size;
  final String? platform;

  ImageConfiguration copyWith({
    Object? bundle,
    double? devicePixelRatio,
    Locale? locale,
    TextDirection? textDirection,
    Size? size,
    String? platform,
  }) {
    return ImageConfiguration(
      bundle: bundle ?? this.bundle,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      locale: locale ?? this.locale,
      textDirection: textDirection ?? this.textDirection,
      size: size ?? this.size,
      platform: platform ?? this.platform,
    );
  }


  static const ImageConfiguration empty = ImageConfiguration();
}
