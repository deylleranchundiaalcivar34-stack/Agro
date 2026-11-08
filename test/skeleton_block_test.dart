import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_agro/core/widgets/skeleton_block.dart';

void main() {
  testWidgets('loading placeholder is static and respects its dimensions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SkeletonBlock(width: 180, height: 96)),
        ),
      ),
    );

    final placeholder = find.byType(SkeletonBlock);
    expect(placeholder, findsOneWidget);
    expect(tester.getSize(placeholder), const Size(180, 96));
    expect(
      find.descendant(of: placeholder, matching: find.byType(AnimatedBuilder)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
