@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_local_notifications',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, the provider of
        // the preferences role, which the notifications role requires, and,
        // in some of them, the providers of the settings screen role and of
        // the localization role, which the notifications role uses, with
        // the router that the settings screen requires.
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
