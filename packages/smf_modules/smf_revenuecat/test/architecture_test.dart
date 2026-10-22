@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_revenuecat',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, the provider of
        // the env role, which the module requires, and, in some of them, the
        // providers of the roles that the purchases role uses: the auth
        // role, with the module that sets up Firebase, which it depends on,
        // the settings screen role, with the router that it requires, and
        // the localization role, with the preferences that it requires.
        testModules: {
          'smf_dart_define',
          'smf_firebase_auth',
          'smf_firebase_core',
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
