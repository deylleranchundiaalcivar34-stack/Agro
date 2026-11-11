import 'package:flutter/material.dart';

/// Shared timing for short, purposeful Agro+ motion.
abstract final class AppDurations {
  static const Duration tapFeedback = Duration(milliseconds: 120);
  static const Duration stateChange = Duration(milliseconds: 180);
  static const Duration routeTransition = Duration(milliseconds: 220);

  /// Resolves motion against the operating-system reduced-motion preference.
  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
