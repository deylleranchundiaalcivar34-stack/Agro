import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editable source text has no accents or enye', () {
    final forbidden = RegExp(
      r'[\u00c1\u00c9\u00cd\u00d1\u00d3\u00da\u00dc\u00e1\u00e9\u00ed\u00f1\u00f3\u00fa\u00fc]',
    );
    final files = <File>[
      ...Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
      ...Directory('test')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
      File('pubspec.yaml'),
      File('README.md'),
    ];

    final filesWithForbiddenText = files
        .where((file) => forbidden.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList();

    expect(filesWithForbiddenText, isEmpty);
  });
}
