// The script that makes the icon runs here for real, as the step of the module
// and a developer run it: with the Dart VM, over the Xcode project of an app
// that the module rendered, with the flavors of the app entry. The workspace
// cannot depend on flutter_launcher_icons, since the packages of its root need
// a later cli_util than the tool does, so a stand-in takes the place of the
// package, which changes the Xcode project as the tool does.
//
// A test starts the Dart VM, so it gets more time than a test has by default.
@TestOn('vm')
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_launcher_icons/smf_launcher_icons.dart';
import 'package:smf_launcher_icons/src/readme.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The setting that flutter_launcher_icons 0.14.4 damages.
const _setting = 'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS';

/// The stand-in for the library that the script imports: what
/// `changeIosLauncherIcon` of the tool does with the Xcode project, in version
/// 0.14.4, once its arguments ask for no failure.
///
/// The tool exits with 2 when it cannot make the icon, before the script gets
/// to its fix, and with `FAIL` in the environment so does the stand-in.
const _standIn = r"""
import 'dart:io';

Future<void> createIconsFromArguments(List<String> arguments) async {
  if (Platform.environment.containsKey('FAIL')) exit(2);
  final file = File('ios/Runner.xcodeproj/project.pbxproj');
  final lines = await file.readAsLines();
  var onConfigurationSection = false;
  String? currentConfig;
  for (var x = 0; x < lines.length; x++) {
    final line = lines[x];
    if (line.contains('/* Begin XCBuildConfiguration section */')) {
      onConfigurationSection = true;
    }
    if (line.contains('/* End XCBuildConfiguration section */')) {
      onConfigurationSection = false;
    }
    if (onConfigurationSection) {
      final match = RegExp('.*/\\* (.*)\.xcconfig \\*/;').firstMatch(line);
      if (match != null) currentConfig = match.group(1);
      if (currentConfig != null && line.contains('ASSETCATALOG')) {
        lines[x] = line.replaceAll(RegExp('\=(.*);'), '= AppIcon;');
      }
    }
  }
  await file.writeAsString('${lines.join('\n')}\n');
}
""";

void main() {
  late RenderedApp app;
  late String project;
  late Directory directory;

  /// Writes the files of the app that the script reads into [directory], the
  /// Xcode project with [xcodeProject], and runs the script there.
  Future<ProcessResult> runScript(
    String xcodeProject, {
    Map<String, String> environment = const {},
  }) async {
    File('${directory.path}/${AppEntryRole.xcodeProjectFile}')
      ..createSync(recursive: true)
      ..writeAsStringSync(xcodeProject);
    File('${directory.path}/$updateScript')
      ..createSync(recursive: true)
      ..writeAsStringSync(app.files[updateScript]!.text);
    File(
      '${directory.path}/stand_in/lib/main.dart',
    )
      ..createSync(recursive: true)
      ..writeAsStringSync(_standIn);
    File('${directory.path}/.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'flutter_launcher_icons',
              'rootUri': '../stand_in',
              'packageUri': 'lib/',
              'languageVersion': '3.6',
            },
          ],
        }),
      );
    return Process.run(
      Platform.resolvedExecutable,
      [updateScript],
      workingDirectory: directory.path,
      environment: environment,
    );
  }

  /// The Xcode project of the test after the script ran.
  String projectAfter() =>
      File('${directory.path}/${AppEntryRole.xcodeProjectFile}')
          .readAsStringSync();

  setUpAll(() async {
    final result = await ContractHarness(
      ModuleRegistry(const [FlutterCoreModule(), LauncherIconsModule()]),
    ).check(
      const ContractCase(
        'launcher_icons',
        requested: [LauncherIconsModule.id],
      ),
    );
    if (result.errors.isNotEmpty || result.app == null) {
      throw StateError('The app has errors: ${result.errors.join('\n')}');
    }
    app = result.app!;
    project = app.files[AppEntryRole.xcodeProjectFile]!.text;
  });

  setUp(() {
    directory = Directory.systemTemp.createTempSync('update_app_icon_test');
    addTearDown(() => directory.deleteSync(recursive: true));
  });

  test(
      'the project of the app has the setting that the tool damages, in the '
      'configurations of its flavors too', () {
    expect(
      RegExp('$_setting = YES;').allMatches(project).length,
      greaterThan(3),
    );
  });

  test('leaves the Xcode project as it was, byte for byte', () async {
    final result = await runScript(project);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    final before = const LineSplitter().convert(project);
    final after = const LineSplitter().convert(projectAfter());
    expect(
      [
        for (var line = 0; line < before.length; line++)
          if (before[line] != after[line]) after[line],
      ],
      isEmpty,
      reason: 'The script repairs the build setting that the tool damages.',
    );
    expect(projectAfter(), project);
  });

  test(
      'keeps a NO that a developer set in a configuration that the tool '
      'changes', () async {
    final last = project.lastIndexOf('$_setting = YES;');
    final withNo =
        project.replaceFirst('$_setting = YES;', '$_setting = NO;', last);
    expect(withNo, isNot(project));

    final result = await runScript(withNo);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(projectAfter(), withNo);
  });

  test('repairs what an earlier run of the tool itself left', () async {
    final last = project.lastIndexOf('$_setting = YES;');
    final damaged =
        project.replaceFirst('$_setting = YES;', '$_setting = AppIcon;', last);
    expect(damaged, isNot(project));

    final result = await runScript(damaged);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(projectAfter(), project);
  });

  test('ends with the exit code of the tool and changes nothing itself',
      () async {
    final result = await runScript(project, environment: {'FAIL': '1'});

    expect(result.exitCode, 2);
    expect(projectAfter(), project);
  });
}
