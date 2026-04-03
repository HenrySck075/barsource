
import 'package:meta/meta.dart';
import 'package:barsource/src/scheduler/ticker.dart';
import 'package:barsource/src/widgets/framework.dart';

abstract class TickerProvider {
  Ticker createTicker(TickerCallback onTick);
}

@optionalTypeArgs
mixin SingleTickerProviderStateMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  Ticker? _ticker;

  @override
  Ticker createTicker(TickerCallback onTick) {
    assert(_ticker == null, "Attempted to create more than one ticker from a SingleTickerProviderStateMixin.");
    _ticker = Ticker(onTick/*, debugLabel: 'created by $this'*/);
    return _ticker!;
  }

  @override
  void dispose() {
    assert(
      _ticker == null || !_ticker!.isActive,
      "Attempted to dispose while a ticker created by this $this is still active.",
    );
    super.dispose();
  }
}
