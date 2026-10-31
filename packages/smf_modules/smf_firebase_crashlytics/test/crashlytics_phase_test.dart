// The script of the app that fixes the build phase for Crashlytics, run with
// `dart` as the script that configures a flavor runs it, in a directory
// without the packages of the app, on the Xcode project of an app of SMF with
// Crashlytics. flutterfire changes the Xcode project only on macOS, so the
// script changes it only there.
@TestOn('vm')
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

void main() {
  late String project;
  late String script;
  late Directory root;
  late Directory app;
  late File file;

  /// What the script says when it fixed the phase, and when there was nothing
  /// to fix.
  const fixed = 'Fixed the Crashlytics phase in '
      '${AppEntryRole.xcodeProjectFile}\n';
  const nothing = 'Nothing to fix in ${AppEntryRole.xcodeProjectFile}\n';

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
    script = result.app!.texts[crashlyticsPhaseFixScript]!;
  });

  setUp(() {
    root = Directory.systemTemp.createTempSync('smf_phase_');
    // A space and a letter beyond ASCII, as the jobs of CI have them.
    app = Directory('${root.path}/my app é')..createSync();
    File('${app.path}/$crashlyticsPhaseFixScript')
      ..createSync(recursive: true)
      ..writeAsStringSync(script);
    file = File('${app.path}/${AppEntryRole.xcodeProjectFile}');
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// Runs the script in [app], or in [directory], with [environment] added to
  /// that of the test.
  ProcessResult fix({
    String? directory,
    Map<String, String> environment = const {},
  }) {
    final result = Process.runSync(
      Platform.resolvedExecutable,
      ['${app.path}/$crashlyticsPhaseFixScript'],
      workingDirectory: directory ?? app.path,
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
    'the script that fixes the build phase for Crashlytics, on macOS,',
    () {
      test(
          'points the phase of flutterfire_cli 1.4.1 at the upload script in '
          'the app, and changes nothing else', () {
        final before = withCrashlyticsPhase(project, '1.4.1');
        write(utf8.encode(before));

        expect(fix().stdout, fixed);

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
        final bytes = file.readAsBytesSync();
        final time = write(bytes);

        expect(fix().stdout, nothing);

        expect(file.readAsBytesSync(), bytes);
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

          expect(fix().stdout, nothing);

          expect(file.readAsBytesSync(), bytes);
          expect(file.lastModifiedSync(), time);
        }
      });

      test('does nothing in an app without the Xcode project', () {
        expect(fix().stdout, nothing);

        expect(file.existsSync(), isFalse);
      });

      test('keeps every other byte, in any encoding, whatever the locale', () {
        // Latin-1 bytes, which are not UTF-8, next to UTF-8 ones.
        final prefix = [...utf8.encode('// café\n'), 0xE9, 0xFF, 0x0A];
        final phase = withCrashlyticsPhase(project, '1.4.1');
        write([...prefix, ...utf8.encode(phase)]);

        fix(environment: const {'LANG': 'C', 'LC_ALL': 'C'});

        expect(file.readAsBytesSync(), [
          ...prefix,
          ...utf8.encode(
            phase.replaceAll(
              crashlyticsScriptInBuildDirectory,
              crashlyticsScriptInApp,
            ),
          ),
        ]);
      });

      test('finds the app from any directory', () {
        write(utf8.encode(withCrashlyticsPhase(project, '1.4.1')));

        expect(fix(directory: root.path).stdout, fixed);

        expect(
          file.readAsStringSync(),
          isNot(contains(crashlyticsScriptInBuildDirectory)),
        );
      });
    },
    testOn: 'mac-os',
  );

  test(
    'says nothing and changes nothing on another system, where flutterfire '
    'leaves the Xcode project as it is',
    () {
      final bytes = utf8.encode(withCrashlyticsPhase(project, '1.4.1'));
      final time = write(bytes);

      final result = fix();

      expect(result.stdout, isEmpty);
      expect(result.stderr, isEmpty);
      expect(file.readAsBytesSync(), bytes);
      expect(file.lastModifiedSync(), time);
    },
    testOn: '!mac-os',
  );
}
