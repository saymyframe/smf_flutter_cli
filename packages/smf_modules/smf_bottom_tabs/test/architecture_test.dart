@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_bottom_tabs',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, the router that
        // builds their main navigation, the provider of the texts that the
        // labels of the destinations are read from, and the preferences
        // that the localization role requires. The router tests with a
        // layout of its own and the others with no main navigation, so none
        // of them tests with this module.
        testModules: {
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
