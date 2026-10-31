// A test that continuous integration runs in the apps with every module,
// whichever module provides the app entry: `flutter test`, a command without
// --flavor, gives the app the default flavor that the app entry role names,
// from the line of its pubspec. Only a run of the flutter tool shows what a
// command without --flavor builds, so the rules of the role leave the value
// of that line to this test. A provider of the role with a known bug fails it
// with the reason of its expectation (brokenProviders of the fixture
// registry): a developer who runs the app without --flavor would get the
// production app, under its id.
//
// The probe of the same check (integration_test/flavors/probe.dart) runs on a
// device in the start check, where the debug start names no flavor and the
// release start names the one for a release.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/flavors/probe.dart';

void main() {
  test('a command without --flavor builds the default flavor of the app', () {
    expect(
      appFlavor,
      '{{default_flavor}}',
      reason: 'A command without --flavor builds the default flavor of the '
          'app that the app entry role names.',
    );
  });

  test('the probe of the flavor finds no problem', () async {
    expect(
      await probeFlavor(() async {}),
      isEmpty,
      reason: 'The app has the flavor that its build asked for.',
    );
  });

  test('the probe tells of another flavor, and of none, than was asked for',
      () {
    expect(problemsOfFlavor('prod', 'prod'), isEmpty);
    expect(problemsOfFlavor('dev', 'prod'), [
      'The app has the flavor dev, where its build asked for prod.',
    ]);
    expect(problemsOfFlavor(null, 'prod'), [
      'The app has the flavor null, where its build asked for prod.',
    ]);
  });
}
