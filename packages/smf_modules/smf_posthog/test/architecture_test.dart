@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_posthog',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, the provider of
        // the env role, which the module requires, and, in some of them, a
        // DI container, which registers the service, and a router, which
        // tells the listener of the module about the screens.
        testModules: {
          'smf_dart_define',
          'smf_flutter_core',
          'smf_get_it',
          'smf_go_router',
        },
      ).problems(),
      isEmpty,
    );
  });
}
