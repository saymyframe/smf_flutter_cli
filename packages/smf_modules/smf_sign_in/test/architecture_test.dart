@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_sign_in',
        // The bundles of its bricks.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, the router that
        // renders the routes of the module and asks its guards, the two
        // modules that manage state, for the variant of the screens with
        // each, the provider of the localization role that gets the texts
        // of the module, and the preferences that the role requires. None
        // of them tests with this module. The sign-in of those apps has a
        // provider of the tests, so that the module is tested with a
        // provider that it does not know.
        testModules: {
          'smf_bloc',
          'smf_flutter_core',
          'smf_gen_l10n',
          'smf_go_router',
          'smf_riverpod',
          'smf_shared_preferences',
        },
      ).problems(),
      isEmpty,
    );
  });
}
