import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_firebase_crashlytics/src/crashlytics_phase.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'support/crashlytics_phases.dart';

void main() {
  group('the build phase for Crashlytics that the tests repeat', () {
    test(
        'is that of the flutterfire_cli that the README of the app activates, '
        'and of the lowest that it accepts', () async {
      const modules = [
        FlutterCoreModule(),
        FirebaseCoreModule(),
        FirebaseCrashlyticsModule(),
      ];
      final result = await ContractHarness(ModuleRegistry(modules)).check(
        const ContractCase(
          'crashlytics',
          requested: [FirebaseCrashlyticsModule.id],
        ),
      );
      final readme = result.app!.texts[AppEntryRole.readmeFile]!;
      // The section of firebase_core, which configures the app.
      final firebase = RegExp(r'\n## Firebase\n(.*?)(\n## |$)', dotAll: true)
          .firstMatch(readme)?[1];
      final activated =
          RegExp(r'dart pub global activate flutterfire_cli (\S+)')
              .firstMatch(firebase ?? '')?[1];
      final lowest = RegExp(r'flutterfire_cli (\S+) or a later 1\.x')
          .firstMatch(firebase ?? '')?[1];

      expect([activated, lowest], everyElement(isNotNull), reason: readme);
      for (final version in {activated, lowest}) {
        expect(
          crashlyticsPhases.keys,
          contains(version),
          reason: 'Compare lib/src/firebase/firebase_apple_writes.dart of '
              'flutterfire_cli $version with the phases of '
              'test/support/crashlytics_phases.dart, and add its phase.',
        );
      }
    });

    test(
        'of 1.4.1 looks for the upload script in the build directory of '
        'Xcode, which the step that continues the configuration changes', () {
      final phase = crashlyticsPhases['1.4.1']!;

      expect(
        crashlyticsScriptInBuildDirectory.allMatches(phase),
        hasLength(2),
      );
      expect(phase, isNot(contains(crashlyticsScriptInApp)));
    });

    test('of 1.4.0 does not, so the step leaves it as it is', () {
      expect(
        crashlyticsPhases['1.4.0'],
        isNot(contains(crashlyticsScriptInBuildDirectory)),
      );
    });
  });
}
