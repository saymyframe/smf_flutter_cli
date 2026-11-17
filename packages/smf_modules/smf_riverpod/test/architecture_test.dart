@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_riverpod',
        testModules: {
          // The app entry of the apps that the tests render.
          'smf_flutter_core',
          // The theme and the languages of the app whose values the tests
          // follow, and the preferences that both require.
          'smf_material_theme',
          'smf_gen_l10n',
          'smf_shared_preferences',
        },
      ).problems(),
      isEmpty,
    );
  });
}
