import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el arranque no fuerza una espera larga de marca', () {
    final main = File('lib/main.dart').readAsStringSync();
    final splash = File('lib/features/splash/splash_view.dart')
        .readAsStringSync();

    expect(main, isNot(contains('Duration(milliseconds: 3200)')));
    expect(splash, isNot(contains('Duration(milliseconds: 3200)')));
  });
}
