@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_update_required',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, the router that
        // renders the route of the module and asks its guard, the providers
        // of the two roles that the module requires, remote config, with the
        // module that sets up Firebase that its provider depends on, and the
        // reviews, with the preferences and the values of .env that the
        // review role requires, and the provider of the localization role
        // that gets the texts of the module in some of them. None of them
        // tests with this module.
        testModules: {
          'smf_dart_define',
          'smf_firebase_core',
          'smf_firebase_remote_config',
          'smf_flutter_core',
          'smf_gen_l10n',
          'smf_go_router',
          'smf_in_app_review',
          'smf_shared_preferences',
        },
      ).problems(),
      isEmpty,
    );
  });
}
