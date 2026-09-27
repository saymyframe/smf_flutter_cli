// The fix of the build phase for Crashlytics runs here with the Ruby of the
// machine, as the step runs it, on the Xcode project of an app of SMF in a
// temporary directory.
@TestOn('vm && !windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_core/src/crashlytics_phase.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'support/flutterfire.dart';

/// The Ruby on the `PATH`, or `null` without one.
String? _ruby() {
  final result = Process.runSync('which', ['ruby']);
  final path = result.stdout.toString().trim();
  return result.exitCode == 0 && path.isNotEmpty ? path : null;
}

void main() {
  final ruby = _ruby();
  final step = crashlyticsPhaseFix();
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
    app = Directory.systemTemp.createTempSync('smf_phase_');
    file = File('${app.path}/${AppEntryRole.xcodeProjectFile}');
  });

  tearDown(() => app.deleteSync(recursive: true));

  /// Runs the step in [app], with [environment] added to that of the test.
  ProcessResult fix([Map<String, String> environment = const {}]) {
    final result = Process.runSync(
      ruby!,
      step.tool.argumentsFor(step.arguments),
      workingDirectory: app.path,
      environment: environment,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return result;
  }

  /// Writes [bytes] as the Xcode project of [app], and dates it back, so
  /// that another write shows in its time, which it returns.
  DateTime write(List<int> bytes) {
    file
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    final time = DateTime(2001);
    file.setLastModifiedSync(time);
    return file.lastModifiedSync();
  }

  group(
    'the fix of the build phase for Crashlytics',
    () {
      test(
          'points the phase of flutterfire_cli 1.4.1 at the upload script in '
          'the app, and changes nothing else', () {
        final before = withCrashlyticsPhase(project, '1.4.1');
        write(utf8.encode(before));

        fix();

        final after = file.readAsStringSync();
        expect(
          after,
          before.replaceAll(
            crashlyticsScriptInBuildDirectory,
            crashlyticsScriptInApp,
          ),
        );
        expect(crashlyticsScriptInApp.allMatches(after), hasLength(2));
        expect(after, isNot(contains(crashlyticsScriptInBuildDirectory)));
      });

      test('changes nothing the second time, and does not write the file', () {
        write(utf8.encode(withCrashlyticsPhase(project, '1.4.1')));
        fix();
        final fixed = file.readAsBytesSync();
        final time = write(fixed);

        fix();

        expect(file.readAsBytesSync(), fixed);
        expect(file.lastModifiedSync(), time);
      });

      test(
          'leaves a project without the phase, or with the phase of 1.4.0, as '
          'it is', () {
        for (final text in [
          project,
          withCrashlyticsPhase(project, '1.4.0'),
        ]) {
          final bytes = utf8.encode(text);
          final time = write(bytes);

          fix();

          expect(file.readAsBytesSync(), bytes);
          expect(file.lastModifiedSync(), time);
        }
      });

      test('does nothing in an app without the Xcode project', () {
        fix();

        expect(app.listSync(), isEmpty);
      });

      test(
          'keeps every other byte, in any encoding, whatever the locale of '
          'Ruby', () {
        // Latin-1 bytes, which are not UTF-8, next to UTF-8 ones.
        final prefix = [...utf8.encode('// café\n'), 0xE9, 0xFF, 0x0A];
        final phase = utf8.encode(withCrashlyticsPhase(project, '1.4.1'));
        write([...prefix, ...phase]);

        fix(const {'LANG': 'C', 'LC_ALL': 'C'});

        expect(file.readAsBytesSync(), [
          ...prefix,
          ...utf8.encode(
            withCrashlyticsPhase(project, '1.4.1').replaceAll(
              crashlyticsScriptInBuildDirectory,
              crashlyticsScriptInApp,
            ),
          ),
        ]);
      });
    },
    skip: ruby == null ? 'Ruby is not on the PATH.' : null,
  );
}
