import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_agro/core/constants/app_durations.dart';

void main() {
  test('shared interaction durations stay short', () {
    expect(AppDurations.tapFeedback, const Duration(milliseconds: 120));
    expect(AppDurations.stateChange, const Duration(milliseconds: 180));
    expect(AppDurations.routeTransition, const Duration(milliseconds: 220));
  });

  testWidgets('motion duration becomes immediate when reduced motion is on', (
    tester,
  ) async {
    Duration? resolved;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            resolved = AppDurations.resolve(
              context,
              AppDurations.routeTransition,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolved, AppDurations.routeTransition);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            resolved = AppDurations.resolve(
              context,
              AppDurations.routeTransition,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolved, Duration.zero);
  });
}
