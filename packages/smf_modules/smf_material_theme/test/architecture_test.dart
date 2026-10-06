@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_material_theme',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, the preferences
        // in which they remember the theme mode, the settings screen that
        // shows the entry of the mode, with the router of its route, and
        // the localization that reads the texts of the entry. None of them
        // tests with this module.
        testModules: {
          'smf_flutter_core',
          'smf_gen_l10n',
          'smf_go_router',
          'smf_settings',
          'smf_shared_preferences',
        },
      ).problems(),
      isEmpty,
    );
  });
}
