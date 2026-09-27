@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_firebase_analytics',
        // The bundle of its brick, and the module it depends on.
        dependencies: {'mason', 'smf_firebase_core'},
        // The app entry of the apps that the tests render, a DI container
        // that registers the service in some of them, and a router that
        // tells the listener of the module about the screens in others.
        testModules: {'smf_flutter_core', 'smf_get_it', 'smf_go_router'},
      ).problems(),
      isEmpty,
    );
  });
}
