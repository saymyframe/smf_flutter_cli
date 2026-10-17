@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_firebase_messaging',
        // The bundle of its brick, and the module it depends on.
        dependencies: {'mason', 'smf_firebase_core'},
        // The app entry of the apps that the tests render, the provider of
        // the notifications role, which the push role requires, and the
        // provider of the preferences role, which the notifications role
        // requires.
        testModules: {
          'smf_flutter_core',
          'smf_local_notifications',
          'smf_shared_preferences',
        },
      ).problems(),
      isEmpty,
    );
  });
}
