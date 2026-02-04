import 'package:flutter/foundation.dart';

/// Global frosted-glass strength (0..1).
///
/// Used by `FrostStrengthScope` + `GlassContainer` so "0%" truly disables blur
/// across the whole app (including overlays).
final ValueNotifier<double> appFrostStrengthNotifier = ValueNotifier<double>(
  0.82,
);
