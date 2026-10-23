@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_paywall',
        // The bundles of its bricks.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, the router that
        // renders the routes of the module and asks its guard, the two
        // modules that manage state, for the variant of the screens with
        // each, the provider of the env role, which the module requires,
        // and, in some of them, the providers of the roles that the module
        // uses: the localization role, with the preferences that it
        // requires, and the settings screen role. None of them tests with
        // this module. The purchases of those apps have a provider of the
        // tests, so that the module is tested with a provider that it does
        // not know.
        testModules: {
          'smf_bloc',
          'smf_dart_define',
          'smf_flutter_core',
          'smf_gen_l10n',
          'smf_go_router',
          'smf_riverpod',
          'smf_settings',
          'smf_shared_preferences',
        },
      ).problems(),
      isEmpty,
    );
  });
}
