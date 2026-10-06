@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_settings',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, the router that
        // renders the route of the module, the layout whose main
        // navigation shows it, the provider of the texts that the title of
        // the screen is one of, and the preferences that the localization
        // role requires. They test with features and texts of their own, so
        // none of them tests with this module.
        testModules: {
          'smf_bottom_tabs',
          'smf_flutter_core',
          'smf_gen_l10n',
          'smf_go_router',
          'smf_shared_preferences',
        },
      ).problems(),
      isEmpty,
    );
  });
}
