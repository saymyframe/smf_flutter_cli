// What flutterfire_cli needs of macOS, checked with the Ruby of the machine
// and its gem xcodeproj, which `flutterfire configure` changes the Xcode
// project of the app with there; without the gem, the tests are skipped.
@TestOn('mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_core/src/crashlytics_phase.dart';
import 'package:smf_firebase_core/src/preflight/xcode_project_tools.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'support/fake_machine.dart';
import 'support/flutterfire.dart';
import 'support/ruby.dart';

/// Runs [call] on this machine.
Future<SmfProcessResult> _run(Call call) async {
  final result = await Process.run(
    call.executable,
    call.arguments,
    workingDirectory: call.workingDirectory,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  return SmfProcessResult(
    exitCode: result.exitCode,
    stdout: '${result.stdout}',
    stderr: '${result.stderr}',
  );
}

void main() {
  final ruby = rubyOnPath();
  final xcodeproj = ruby == null ? null : xcodeprojVersion(ruby);
  late String project;
  late Directory app;
  late File file;

  setUpAll(() async {
    const modules = [FlutterCoreModule(), FirebaseCoreModule()];
    final result = await ContractHarness(ModuleRegistry(modules)).check(
      ContractCase(
        'firebase',
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
      test('the check of the tools of the Xcode project passes', () async {
        final machine = FakeMachine(
          executables: {'ruby': ruby!},
          reply: _run,
        );

        expect(
          await const XcodeProjectToolsCheck().check(machine),
          isA<PreflightPassed>(),
        );
        expect(machine.calls.single.executable, ruby);
      });

      test(
          'flutterfire adds its phase for Crashlytics to the Xcode project of '
          'an app of SMF as the tests of the module repeat it, last in the '
          'target Runner, and keeps the Swift package of Flutter', () {
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
        // The gem needs 1.23.0 or newer to keep it.
        const package = 'FlutterGeneratedPluginSwiftPackage';
        expect(
          saved,
          allOf(
            contains('relativePath = Flutter/ephemeral/Packages/$package;'),
            contains('productName = $package;'),
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
