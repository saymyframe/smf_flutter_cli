@TestOn('vm')
library;

import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:fake_state/fake_state.dart';
import 'package:fixture_registry/fixture_registry.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

/// Set to rewrite the snapshots with what the pipeline renders now.
const _update = 'SMF_UPDATE_SNAPSHOTS';

/// The apps whose rendered files are kept as snapshots.
final _apps = <String, ContractCase>{
  'every_fixture_bloc': ContractCase(
    'every fixture with BLoC',
    requested: everyFixture(),
  ),
  'every_fixture_riverpod': ContractCase(
    'every fixture with Riverpod',
    requested: everyFixture(stateManager: FakeRiverpodModule.id),
  ),
  // No router, no DI, and the clock without the badge: the other branches
  // of the templates.
  'without_router': const ContractCase(
    'without a router',
    requested: [
      ModuleId('fake_sockets'),
      ModuleId('fake_overlap'),
      ModuleId('fake_events'),
      ModuleId('fake_crash'),
      ModuleId('fake_child'),
      ModuleId('fake_codegen'),
      ModuleId('fake_clock_user'),
    ],
  ),
};

/// The files of flutter_core that the fixtures change: the Dart code, the
/// pubspec, and the native files with sockets. The Xcode project shows only
/// its minimum iOS versions.
bool _shownOfAppEntry(String path) =>
    path.startsWith('lib/') ||
    path.startsWith('test/') ||
    const {
      'pubspec.yaml',
      AppEntryRole.androidManifestFile,
      AppEntryRole.infoPlistFile,
      AppEntryRole.gradleSettingsFile,
      AppEntryRole.gradleAppFile,
      AppEntryRole.xcodeProjectFile,
    }.contains(path);

/// The language version that `dart format` formats [app] with: the one of
/// the lower bound of its SDK constraint, but no later than the formatter of
/// the snapshots knows. Up to Dart 3.12, the styles of the versions after
/// 3.10 differ only where trailing commas are preserved, which the apps do
/// not ask for. Code with the syntax of a later version fails to format
/// until the formatter moves on with the analyzer of the pipeline.
Version _languageVersionOf(RenderedApp app) {
  final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;
  final environment = pubspec['environment'] as YamlMap;
  final sdk = VersionConstraint.parse(environment['sdk'] as String);
  final lower = (sdk as VersionRange).min!;
  final version = Version(lower.major, lower.minor, 0);
  final latest = DartFormatter.latestLanguageVersion;
  return version > latest ? latest : version;
}

/// The files of [app] as one text: each under a header with its path and
/// owner. Every file of the fixtures is shown, and the files of flutter_core
/// that they change; see [_shownOfAppEntry]. Dart files are formatted as
/// `dart format` formats the app, and the pubspec, XML and plist files must
/// parse.
String _snapshotOf(RenderedApp app) {
  final formatter = DartFormatter(languageVersion: _languageVersionOf(app));
  final buffer = StringBuffer();
  for (final file in app.files.values) {
    final path = file.path;
    final ofAppEntry = file.owner == const ModuleOrigin(FlutterCoreModule.id);
    if (ofAppEntry && !_shownOfAppEntry(path)) continue;
    buffer.writeln('=== $path (${file.owner}) ===');
    if (!file.isText) {
      buffer.writeln('<${file.bytes.length} bytes>');
      continue;
    }
    var text = file.text;
    if (path.endsWith('.dart')) {
      text = formatter.format(text, uri: path);
    } else if (path.endsWith('.xml') || path.endsWith('.plist')) {
      XmlDocument.parse(text);
    } else if (path.endsWith('.yaml')) {
      loadYaml(text, sourceUrl: Uri.file(path));
    } else if (path == AppEntryRole.xcodeProjectFile) {
      text = [
        for (final line in text.split('\n'))
          if (line.contains('IPHONEOS_DEPLOYMENT_TARGET')) line.trim(),
      ].join('\n');
    }
    buffer.write(text.endsWith('\n') ? text : '$text\n');
  }
  return buffer.toString();
}

void main() {
  final harness = ContractHarness(
    ModuleRegistry(fixtureModules()),
    context: const ModuleContext(
      appName: 'fixture_app',
      orgName: 'com.example',
      appIdentity: AppIdentity(
        androidApplicationId: 'com.example.fixture_app',
        iosBundleId: 'com.example.fixture-app',
        androidNamespace: 'com.example.fixture_app',
      ),
    ),
  );

  for (final MapEntry(key: name, value: contractCase) in _apps.entries) {
    test('the app with $contractCase renders as its snapshot', () async {
      final result = await harness.check(contractCase);
      expect(result.errors.map((issue) => '$issue'), isEmpty);

      final snapshot = _snapshotOf(result.app!);
      final file = File('test/snapshots/$name.txt');
      if (Platform.environment[_update] == '1') {
        file
          ..createSync(recursive: true)
          ..writeAsStringSync(snapshot);
      }
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Run the test with $_update=1 to write the snapshot.',
      );
      expect(
        snapshot,
        // Git may check the snapshot out with Windows line endings.
        file.readAsStringSync().replaceAll('\r\n', '\n'),
        reason: 'The rendered app differs from ${file.path}. If the change '
            'is intended, run the test with $_update=1 and review the diff.',
      );
    });
  }
}
