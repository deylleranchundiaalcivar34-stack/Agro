import 'package:flutter/material.dart';

/// Keeps scrolling usable without desktop scrollbar chrome or elastic effects.
class AgroScrollBehavior extends MaterialScrollBehavior {
  const AgroScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
