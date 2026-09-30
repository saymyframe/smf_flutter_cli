// What flutterfire_cli needs of macOS, checked with the Ruby of the machine
// and its gem xcodeproj, which `flutterfire configure` changes the Xcode
// project of the app with there; without the gem, the tests are skipped.
@TestOn('mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_core/src/preflight/xcode_project_tools.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'support/fake_machine.dart';
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
          'flutterfire opens and saves the Xcode project of an app of SMF, '
          'and keeps the Swift package of Flutter', () {
        saveXcodeProject(ruby!, app.path);

        // The gem needs 1.23.0 or newer to keep it.
        const package = 'FlutterGeneratedPluginSwiftPackage';
        expect(
          file.readAsStringSync(),
          allOf(
            contains('relativePath = Flutter/ephemeral/Packages/$package;'),
            contains('productName = $package;'),
          ),
        );
      });
    },
    skip: xcodeproj == null ? 'The gem xcodeproj is not installed.' : null,
  );
}
