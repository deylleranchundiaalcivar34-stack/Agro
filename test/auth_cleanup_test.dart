import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el flujo de auth no depende de captcha ni webview', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final source = files.map((file) => file.readAsStringSync()).join('\n');
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(source.toLowerCase(), isNot(contains('turnstile')));
    expect(source.toLowerCase(), isNot(contains('captcha')));
    expect(pubspec, isNot(contains('webview_flutter')));
  });
}
