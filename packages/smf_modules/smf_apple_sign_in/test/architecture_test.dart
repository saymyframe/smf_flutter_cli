@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_apple_sign_in',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, and, in some of
        // them, the provider of the localization role, with the provider of
        // the preferences role, which that role requires. The provider of
        // the auth role is one of the tests of their own.
        testModules: {
          'smf_flutter_core',
          'smf_gen_l10n',
          'smf_shared_preferences',
        },
      ).problems(),
      isEmpty,
    );
  });
}
