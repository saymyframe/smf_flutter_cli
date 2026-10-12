@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_firebase_auth',
        // The bundle of its brick, and the module it depends on.
        dependencies: {'mason', 'smf_firebase_core'},
        // The app entry of the apps that the tests render, and, in some of
        // them, the provider of the router role, which the auth role uses,
        // and the provider of the localization role, with the provider of
        // the preferences role, which that role requires.
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
