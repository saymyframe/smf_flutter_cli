@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_dio',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, the provider of the
        // env role, which the REST role requires, and, in some of them, the
        // provider of the auth role, which the REST role uses, with the module
        // that sets up Firebase, which it depends on.
        testModules: {
          'smf_dart_define',
          'smf_firebase_auth',
          'smf_firebase_core',
          'smf_flutter_core',
        },
      ).problems(),
      isEmpty,
    );
  });
}
