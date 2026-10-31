// The script of the app that configures a flavor, as firebase_core generates
// it, with what this module adds to an app, and a stand-in for
// `flutterfire configure` that writes the build phase for Crashlytics again in
// each run, as flutterfire_cli 1.4.1 does on macOS. flutterfire runs once for
// each build configuration of a flavor only there, and only there it changes
// the Xcode project, so the test runs only there.
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

/// `flutterfire configure` for the tests: it takes the phase out of the Xcode
/// project, wherever it is, and adds it again from the file that
/// `FAKE_FLUTTERFIRE_PHASE` names, and it notes each run there too.
const _standIn = r'''
import 'dart:io';

void main(List<String> arguments) {
  final phase = Platform.environment['FAKE_FLUTTERFIRE_PHASE']!;
  File('$phase.log').writeAsStringSync(
    '${arguments.where((a) => a.startsWith('--ios-build-config=')).single}\n',
    mode: FileMode.append,
  );
  final file = File('ios/Runner.xcodeproj/project.pbxproj');
  const end = '/* End PBXShellScriptBuildPhase section */';
  file.writeAsStringSync(
    file
        .readAsStringSync()
        .replaceAll(
          RegExp(
            r'\t\t[0-9A-F]{24} /\* FlutterFire: "flutterfire '
            r'upload-crashlytics-symbols" \*/ = \{.*?\n\t\t\};\n',
            dotAll: true,
          ),
          '',
        )
        .replaceFirst(end, '${File(phase).readAsStringSync()}$end'),
  );
}
''';

void main() {
  late Directory root;
  late String pubCache;
  late File phase;
  late Directory app;
  late File project;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('smf_configure_phase');
    pubCache = '${root.path}/pub_cache';
    phase = File('${root.path}/phase.txt')
      ..writeAsStringSync(crashlyticsPhases['1.4.1']!);

    final standIn = Directory('${root.path}/flutterfire_cli')..createSync();
    File('${standIn.path}/pubspec.yaml').writeAsStringSync('''
name: flutterfire_cli
version: 1.4.1
environment:
  sdk: ">=3.6.0 <4.0.0"
executables:
  flutterfire: flutterfire
''');
    File('${standIn.path}/bin/flutterfire.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(_standIn);
    final activated = await Process.run(
      Platform.resolvedExecutable,
      ['pub', 'global', 'activate', '--source', 'path', standIn.path],
      environment: {'PUB_CACHE': pubCache},
    );
    expect(activated.exitCode, 0, reason: '${activated.stderr}');

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
    app = Directory('${root.path}/my app é')..createSync();
    for (final MapEntry(key: path, value: file) in result.app!.files.entries) {
      if (path.startsWith('tool/') ||
          path.startsWith('lib/firebase_options_') ||
          path == AppEntryRole.xcodeProjectFile) {
        File('${app.path}/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync(file.text);
      }
    }
    project = File('${app.path}/${AppEntryRole.xcodeProjectFile}');
  });

  tearDownAll(() => root.deleteSync(recursive: true));

  for (final flavor in AppEntryRole.flavors) {
    test(
        'the script leaves the phase working for flutter build ipa after the '
        'flavor ${flavor.name}, whichever flavor came before it', () async {
      final log = File('${phase.path}.log');
      if (log.existsSync()) log.deleteSync();

      final run = await Process.run(
        Platform.resolvedExecutable,
        [
          FirebaseCoreModule.configureScript,
          flavor.name,
          '--project=my-project',
        ],
        workingDirectory: app.path,
        environment: {
          'PUB_CACHE': pubCache,
          'FAKE_FLUTTERFIRE_PHASE': phase.path,
        },
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
      expect(log.readAsLinesSync(), [
        for (final configuration in flavor.xcodeConfigurations)
          '--ios-build-config=$configuration',
      ]);
      final text = project.readAsStringSync();
      expect(crashlyticsPhaseName.allMatches(text), isNotEmpty);
      expect(
        text,
        isNot(contains(crashlyticsScriptInBuildDirectory)),
        reason: 'flutter build ipa does not find the upload script there.',
      );
      expect(crashlyticsScriptInApp.allMatches(text), hasLength(2));
    });
  }
}
