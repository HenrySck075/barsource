import 'package:meta/meta.dart';
import 'package:tennoji/src/painting/basic_types.dart';

abstract class Listenable {
  /// This constructor enables subclasses to provide const constructors so that
  /// they can be used in const expressions.
  const Listenable();

  /// Return a [Listenable] that triggers when any of the given [Listenable]s
  /// themselves trigger.
  ///
  /// Once the factory is called, items must not be added or removed from the iterable.
  /// Doing so will lead to memory leaks or exceptions.
  ///
  /// The iterable may contain nulls; they are ignored.
  factory Listenable.merge(Iterable<Listenable?> listenables) = _MergingListenable;

  /// Register a closure to be called when the object notifies its listeners.
  void addListener(VoidCallback listener);

  /// Remove a previously registered closure from the list of closures that the
  /// object notifies.
  void removeListener(VoidCallback listener);
}
class _MergingListenable extends Listenable {
  _MergingListenable(this._children);

  final Iterable<Listenable?> _children;

  @override
  void addListener(VoidCallback listener) {
    for (final Listenable? child in _children) {
      child?.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    for (final Listenable? child in _children) {
      child?.removeListener(listener);
    }
  }

  @override
  String toString() {
    return 'Listenable.merge([${_children.join(", ")}])';
  }
}
abstract class ValueListenable<T> extends Listenable {
  /// This constructor enables subclasses to provide const constructors so that
  /// they can be used in const expressions.
  const ValueListenable();

  /// The current value of the object.
  ///
  /// When the value changes, the callbacks registered with [addListener] will be
  /// invoked.
  T get value;
}

mixin class ChangeNotifier implements Listenable {
  // Flutter does some other cursed low-level replica with this list so it's "monomorphic"
  // for simplicity I don't care
  // wow i finally know how to not copy everything over woohoo
  final List<VoidCallback> _listeners = [];

  bool _debugDisposed = false;

  @override
  void addListener(VoidCallback listener) {
    assert(!_debugDisposed);
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    assert(!_debugDisposed);
    _listeners.remove(listener);
  }

  void notifyListeners() {
    assert(!_debugDisposed);
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  @mustCallSuper
  void dispose() {
    //assert(_notificationCallStackDepth == 0);
    assert(() { _debugDisposed = true; return true; }());
    _listeners.clear();
  }
}
class ValueNotifier<T> extends ChangeNotifier implements ValueListenable<T> {
  /// Creates a [ChangeNotifier] that wraps this value.
  ValueNotifier(this._value) {
    /*
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
    */
  }

  /// The current value stored in this notifier.
  ///
  /// When the value is replaced with something that is not equal to the old
  /// value as evaluated by the equality operator ==, this class notifies its
  /// listeners.
  @override
  T get value => _value;
  T _value;
  set value(T newValue) {
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }

/*
  @override
  String toString() => '${describeIdentity(this)}($value)';
*/
}
