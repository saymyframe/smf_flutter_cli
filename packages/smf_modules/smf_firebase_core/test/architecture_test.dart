@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_firebase_core',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render.
        testModules: {'smf_flutter_core'},
      ).problems(),
      isEmpty,
    );
  });
}
