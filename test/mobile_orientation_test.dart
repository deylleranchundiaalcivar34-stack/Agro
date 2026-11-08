import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android phone locks Agro+ to portrait', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(manifest, contains('android:screenOrientation="portrait"'));
  });

  test('iPhone supports portrait orientation only', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final orientations = RegExp(
      r'<key>UISupportedInterfaceOrientations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist)?.group(1);

    expect(orientations, isNotNull);
    expect(orientations, contains('UIInterfaceOrientationPortrait'));
    expect(orientations, isNot(contains('Landscape')));
  });

  test('Android dark mode uses the branded system splash background', () {
    final nightSplashTheme = File(
      'android/app/src/main/res/values-night-v31/styles.xml',
    );

    expect(nightSplashTheme.existsSync(), isTrue);
    if (!nightSplashTheme.existsSync()) return;

    final xml = nightSplashTheme.readAsStringSync();
    expect(xml, contains('android:windowSplashScreenBackground'));
    expect(xml, contains('@color/launch_splash_background'));
  });
}
