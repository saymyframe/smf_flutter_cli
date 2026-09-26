@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_go_router',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render. The modules that
        // require a router test with this one, so its tests have features
        // of their own.
        testModules: {'smf_flutter_core'},
      ).problems(),
      isEmpty,
    );
  });
}
