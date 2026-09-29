import 'dart:io';

import 'package:test/test.dart';

import 'support/app_pubspec.dart';

void main() {
  late Directory app;

  setUp(() => app = Directory.systemTemp.createTempSync('app_pubspec_'));
  tearDown(() => app.deleteSync(recursive: true));

  void pubspec(String text) =>
      File('${app.path}/pubspec.yaml').writeAsStringSync(text);

  test('finds the packages that an app depends on in its pubspec', () {
    pubspec('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
  firebase_core: "^4.15.0"
dev_dependencies:
  firebase_crashlytics_platform_interface: any
''');

    expect(dependsOn(app.path, 'firebase_core'), isTrue);
    expect(dependsOn(app.path, 'flutter'), isTrue);
    // Not as a dev dependency, which the tests of the app use.
    expect(
      dependsOn(app.path, 'firebase_crashlytics_platform_interface'),
      isFalse,
    );
    expect(dependsOn(app.path, 'firebase_crashlytics'), isFalse);
  });

  test('finds no package in a pubspec without dependencies', () {
    pubspec('name: my_app\n');

    expect(dependsOn(app.path, 'firebase_core'), isFalse);
  });
}
