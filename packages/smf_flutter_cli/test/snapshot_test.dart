@TestOn('vm')
library;

import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

/// Set to rewrite the snapshots with what the pipeline renders now.
const _update = 'SMF_UPDATE_SNAPSHOTS';

/// The directory of the snapshots, one per app of the matrix.
final _directory = Directory('test/snapshots');

/// The files of the app entry that the snapshots show: the Dart code, the
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
/// owner. Every file of the modules is shown, and the files of the provider
/// of the app entry among [_shownOfAppEntry]. Dart files are formatted as
/// `dart format` formats the app, and the pubspec, XML and plist files must
/// parse.
String _snapshotOf(RenderedApp app, Set<ContributionOrigin> appEntry) {
  final formatter = DartFormatter(languageVersion: _languageVersionOf(app));
  final buffer = StringBuffer();
  for (final file in app.files.values) {
    final path = file.path;
    if (appEntry.contains(file.owner) && !_shownOfAppEntry(path)) continue;
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

/// The name of the snapshot of the app of [app].
String _fileNameOf(MatrixApp app) {
  final words = app.name.split(RegExp('[^A-Za-z0-9]+'));
  return '${words.where((word) => word.isNotEmpty).join('_')}.txt';
}

Future<void> main() async {
  final registry = ModuleRegistry(smfModules);
  final harness = ContractHarness(
    registry,
    context: const ModuleContext(
      appName: 'my_app',
      orgName: 'com.example',
      appIdentity: AppIdentity(
        androidApplicationId: 'com.example.my_app',
        iosBundleId: 'com.example.my-app',
        androidNamespace: 'com.example.my_app',
      ),
    ),
  );
  final appEntry = {
    for (final module in registry.providersOf(appEntryRole))
      ModuleOrigin(module.descriptor.id),
  };
  final (:apps, failed: _) = await matrixOf(smfModules);

  for (final app in apps) {
    test('the app of ${app.name} renders as its snapshot', () async {
      final result = await harness.check(
        ContractCase(
          app.name,
          requested: app.modules,
          roleOptions: app.roleOptions,
        ),
      );
      expect(result.errors.map((issue) => '$issue'), isEmpty);

      final snapshot = _snapshotOf(result.app!, appEntry);
      final file = File('${_directory.path}/${_fileNameOf(app)}');
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

  test('every snapshot belongs to an app of the matrix', () {
    final expected = {for (final app in apps) _fileNameOf(app)};
    final stale = [
      for (final file in _directory.listSync())
        if (file.path.endsWith('.txt') &&
            !expected.contains(file.uri.pathSegments.last))
          file.path,
    ];

    expect(stale, isEmpty, reason: 'Delete the snapshots of apps that went.');
  });
}
