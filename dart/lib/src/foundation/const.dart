/// The epsilon of tolerable double precision error.
///
/// This is used in various places in the framework to allow for floating point
/// precision loss in calculations. Differences below this threshold are safe to
/// disregard.
const double precisionErrorTolerance = 1e-10;

const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');
const bool kDebugMode = !kReleaseMode;
