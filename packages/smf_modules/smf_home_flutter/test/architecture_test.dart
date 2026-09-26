@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_home_flutter',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, and the router
        // that renders the route of the module. The router tests with
        // features of its own, so it does not test with this module.
        testModules: {'smf_flutter_core', 'smf_go_router'},
      ).problems(),
      isEmpty,
    );
  });
}
