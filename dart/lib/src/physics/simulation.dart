import 'package:tennoji/src/foundation/object.dart';

class Tolerance {
  /// Creates a [Tolerance] object. By default, the distance, time, and velocity
  /// tolerances are all ±0.001; the constructor arguments override this.
  ///
  /// The arguments should all be positive values.
  const Tolerance({
    this.distance = _epsilonDefault,
    this.time = _epsilonDefault,
    this.velocity = _epsilonDefault,
  });

  static const double _epsilonDefault = 1e-3;

  /// A default tolerance of 0.001 for all three values.
  static const Tolerance defaultTolerance = Tolerance();

  /// The magnitude of the maximum distance between two points for them to be
  /// considered within tolerance.
  ///
  /// The units for the distance tolerance must be the same as the units used
  /// for the distances that are to be compared to this tolerance.
  final double distance;

  /// The magnitude of the maximum duration between two times for them to be
  /// considered within tolerance.
  ///
  /// The units for the time tolerance must be the same as the units used
  /// for the times that are to be compared to this tolerance.
  final double time;

  /// The magnitude of the maximum difference between two velocities for them to
  /// be considered within tolerance.
  ///
  /// The units for the velocity tolerance must be the same as the units used
  /// for the velocities that are to be compared to this tolerance.
  final double velocity;

  @override
  String toString() =>
      '${objectRuntimeType(this, 'Tolerance')}(distance: ±$distance, time: ±$time, velocity: ±$velocity)';
}

abstract class Simulation {
  /// Initializes the [tolerance] field for subclasses.
  Simulation({this.tolerance = Tolerance.defaultTolerance});

  /// The position of the object in the simulation at the given time.
  double x(double time);

  /// The velocity of the object in the simulation at the given time.
  double dx(double time);

  /// Whether the simulation is "done" at the given time.
  bool isDone(double time);

  /// How close to the actual end of the simulation a value at a particular time
  /// must be before [isDone] considers the simulation to be "done".
  ///
  /// A simulation with an asymptotic curve would never technically be "done",
  /// but once the difference from the value at a particular time and the
  /// asymptote itself could not be seen, it would be pointless to continue. The
  /// tolerance defines how to determine if the difference could not be seen.
  Tolerance tolerance;

  @override
  String toString() => objectRuntimeType(this, 'Simulation');
}
