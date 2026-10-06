@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_onboarding',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, the router that
        // renders the route of the module and asks its guard, and the
        // provider of the localization role that gets its texts. None of
        // them tests with this module. The preferences of those apps have a
        // provider of the tests, so that the code of the module runs with
        // the Dart SDK alone.
        testModules: {'smf_flutter_core', 'smf_gen_l10n', 'smf_go_router'},
      ).problems(),
      isEmpty,
    );
  });
}
