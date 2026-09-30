// The build phase for Crashlytics that `flutterfire configure` adds on macOS
// with the gem xcodeproj, repeated with the Ruby of the machine and its gem
// on the Xcode project of an app of SMF with Crashlytics, and the fix of the
// phase; without the gem, the tests are skipped.
@TestOn('mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_firebase_crashlytics/src/crashlytics_phase.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'support/crashlytics_phases.dart';
import 'support/ruby.dart';

void main() {
  final ruby = rubyOnPath();
  final xcodeproj = ruby == null ? null : xcodeprojVersion(ruby);
  late String project;
  late Directory app;
  late File file;

  setUpAll(() async {
    const modules = [
      FlutterCoreModule(),
      FirebaseCoreModule(),
      FirebaseCrashlyticsModule(),
    ];
    final result = await ContractHarness(ModuleRegistry(modules)).check(
      ContractCase(
        'crashlytics',
        requested: [for (final module in modules) module.descriptor.id],
      ),
    );
    project = result.app!.texts[AppEntryRole.xcodeProjectFile]!;
  });

  setUp(() {
    app = Directory.systemTemp.createTempSync('smf_xcodeproj_');
    file = File('${app.path}/${AppEntryRole.xcodeProjectFile}')
      ..createSync(recursive: true)
      ..writeAsStringSync(project);
  });

  tearDown(() => app.deleteSync(recursive: true));

  group(
    'with the gem xcodeproj $xcodeproj of the machine',
    () {
      test(
          'flutterfire adds its phase for Crashlytics to the Xcode project of '
          'an app of SMF as the tests of the module repeat it, last in the '
          'target Runner', () {
        addCrashlyticsPhase(ruby!, app.path, '1.4.1');

        final saved = file.readAsStringSync();
        final phase = RegExp(
          r'\t\t([0-9A-F]{24}) /\* FlutterFire: "flutterfire '
          r'upload-crashlytics-symbols" \*/ = \{.*?\n\t\t\};\n',
          dotAll: true,
        ).firstMatch(saved)!;
        final id = phase[1]!;
        final anyId = RegExp('[0-9A-F]{24}');
        expect(
          phase[0]!.replaceAll(id, '<id>'),
          crashlyticsPhases['1.4.1']!.replaceAll(anyId, '<id>'),
        );
        expect(
          saved,
          contains(
            '/* Thin Binary */,\n'
            '\t\t\t\t$id /* $crashlyticsPhaseName */,\n'
            '\t\t\t);',
          ),
        );
      });

      test(
          'the fix points the phase that flutterfire adds at the upload '
          'script in the app, and the gem reads the script with the path '
          'replaced', () {
        addCrashlyticsPhase(ruby!, app.path, '1.4.1');
        const step = crashlyticsPhaseFix;

        final result = Process.runSync(
          ruby,
          step.tool.argumentsFor(step.arguments),
          workingDirectory: app.path,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(
          result.stdout,
          'Fixed the Crashlytics phase in ${AppEntryRole.xcodeProjectFile}\n',
        );
        expect(
          crashlyticsPhaseScriptIn(ruby, app.path),
          crashlyticsPhaseScript('1.4.1').replaceAll(
            crashlyticsScriptInBuildDirectory,
            crashlyticsScriptInApp,
          ),
        );
      });
    },
    skip: xcodeproj == null ? 'The gem xcodeproj is not installed.' : null,
  );
}
