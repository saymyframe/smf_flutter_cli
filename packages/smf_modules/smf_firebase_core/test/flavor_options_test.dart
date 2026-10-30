// The options of Firebase of each flavor, run with the Dart SDK alone: the
// selector and the placeholders of the brick, with stand-ins for the libraries
// of Flutter and firebase_core, and with -DFLUTTER_APP_FLAVOR, as the flutter
// tool gives a build its flavor.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_core/src/configure.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'support/flutterfire.dart';

/// `appFlavor` as `packages/flutter/lib/src/services/flavor.dart` of Flutter
/// 3.44 has it.
const _services = '''
const String? appFlavor = String.fromEnvironment('FLUTTER_APP_FLAVOR') != ''
    ? String.fromEnvironment('FLUTTER_APP_FLAVOR')
    : null;
''';

/// A stand-in for what the placeholders read of Flutter. A test gives the
/// platform with -DPLATFORM.
const _foundation = '''
const bool kIsWeb = false;

enum TargetPlatform { android, fuchsia, iOS, linux, macOS, windows }

const TargetPlatform defaultTargetPlatform =
    String.fromEnvironment('PLATFORM') == 'ios'
        ? TargetPlatform.iOS
        : TargetPlatform.android;
''';

/// A stand-in for `FirebaseOptions` of firebase_core.
const _firebaseCore = '''
class FirebaseOptions {
  const FirebaseOptions({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
}
''';

/// What the app of the test runs: it prints the project and the id of the app
/// of its options, or the message of what the selector threw.
const _main = r'''
import 'package:contract_app/firebase_options_of_flavor.dart';

void main() {
  try {
    final options = firebaseOptionsOfFlavor;
    print('${options.projectId} ${options.appId}');
  } on UnsupportedError catch (error) {
    print('stopped: ${error.message}');
  }
}
''';

/// The project of the configured [flavor] in the tests.
String _projectOf(AppFlavor flavor) => 'smf-project-of-${flavor.name}';

void main() {
  late Map<String, String> brick;
  late Directory root;

  /// Writes [text] at [path] below the directory of the test.
  void write(String path, String text) {
    File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }

  /// The arguments of `dart` that give a build [flavor] on [platform].
  List<String> definesOf(String? flavor, String platform) => [
        if (flavor != null) '-DFLUTTER_APP_FLAVOR=$flavor',
        '-DPLATFORM=$platform',
      ];

  /// What the app prints in a build of [flavor] on [platform].
  Future<String> run(String? flavor, {String platform = 'android'}) async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      [...definesOf(flavor, platform), 'bin/main.dart'],
      workingDirectory: '${root.path}/app',
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    return '${result.stdout}'.trim();
  }

  /// Puts the options of the app in place: [configured] filled in by
  /// flutterfire and the others as the brick has them, and [selector] in place
  /// of the file of the brick.
  void placeOptions(Iterable<AppFlavor> configured, {String? selector}) {
    for (final flavor in AppEntryRole.flavors) {
      final path = 'lib/firebase_options_${flavor.name}.dart';
      write(
        'app/$path',
        configured.contains(flavor)
            ? fillOptions(brick[path]!, _projectOf(flavor))
            : brick[path]!,
      );
    }
    const file = FirebaseCoreModule.optionsSelectorFile;
    write('app/$file', selector ?? brick[file]!);
  }

  setUpAll(() async {
    const modules = [FlutterCoreModule(), FirebaseCoreModule()];
    final result = await ContractHarness(ModuleRegistry(modules)).check(
      const ContractCase('firebase_core', requested: [FirebaseCoreModule.id]),
    );
    expect(result.errors, isEmpty);
    brick = {
      for (final MapEntry(key: path, value: file) in result.app!.files.entries)
        if (path.startsWith('lib/firebase_options')) path: file.text,
    };

    root = Directory.systemTemp.createTempSync('smf_flavor_options');
    write('flutter/lib/services.dart', _services);
    write('flutter/lib/foundation.dart', _foundation);
    write('firebase_core/lib/firebase_core.dart', _firebaseCore);
    write('app/bin/main.dart', _main);
    write('app/pubspec.yaml', 'name: contract_app\n');
    write(
      'app/.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final (name, rootUri) in [
            ('contract_app', '../'),
            ('flutter', '../../flutter/'),
            ('firebase_core', '../../firebase_core/'),
          ])
            {
              'name': name,
              'rootUri': rootUri,
              'packageUri': 'lib/',
              'languageVersion': '3.6',
            },
        ],
      }),
    );
  });

  tearDownAll(() => root.deleteSync(recursive: true));

  test('the app has the selector and the options of each flavor of the role',
      () {
    expect(brick.keys.toSet(), {
      FirebaseCoreModule.optionsSelectorFile,
      for (final flavor in AppEntryRole.flavors)
        'lib/firebase_options_${flavor.name}.dart',
    });
  });

  test(
      'each placeholder keeps the form that flutterfire fills in place, and '
      'names no project', () {
    for (final flavor in AppEntryRole.flavors) {
      final placeholder = brick['lib/firebase_options_${flavor.name}.dart']!;
      for (final platform in const ['android', 'ios']) {
        expect(
          fillsOptionsInPlace(placeholder, platform),
          isTrue,
          reason: '${flavor.name} $platform',
        );
      }
      // flutterfire takes the first line with `);` for the end of a throw.
      for (final block
          in RegExp(r'throw UnsupportedError\((.*?)\n\s*\);', dotAll: true)
              .allMatches(placeholder)) {
        expect(block[1], isNot(contains(');')));
      }
      expect(placeholder, isNot(contains('static const FirebaseOptions')));
      expect(
        placeholder,
        contains(
          "'Run: ${configureCommandOf(flavor)}',",
        ),
        reason: flavor.name,
      );
    }
  });

  group('in a build of a flavor', () {
    test('takes the options of that flavor, on Android and on iOS', () async {
      placeOptions(AppEntryRole.flavors);

      for (final flavor in AppEntryRole.flavors) {
        final project = _projectOf(flavor);
        expect(await run(flavor.name), '$project 1:1:android:$project');
        expect(
          await run(flavor.name, platform: 'ios'),
          '$project 1:1:ios:$project',
        );
      }
    });

    test(
        'stops with the script and the flavor when that flavor is not '
        'configured, though another one is', () async {
      final others = AppEntryRole.flavors.skip(1);
      placeOptions(others);
      final flavor = AppEntryRole.flavors.first;

      for (final platform in const ['android', 'ios']) {
        expect(
          await run(flavor.name, platform: platform),
          'stopped: Firebase is not configured for the flavor ${flavor.name} '
          'on $platform. Run: ${configureCommandOf(flavor)}',
        );
      }
      expect(
        await run(others.first.name),
        startsWith(_projectOf(others.first)),
      );
    });

    test('stops for an unknown flavor, and says what to do with a new one',
        () async {
      placeOptions(AppEntryRole.flavors);

      expect(
        await run('other'),
        allOf(
          startsWith(
            'stopped: The app has no Firebase options for the flavor other.',
          ),
          contains(FirebaseCoreModule.configureScript),
          contains('this file'),
        ),
      );
    });

    test(
        'stops without a flavor, as a run from Xcode of the scheme Runner has '
        'none after flutter pub get, and says what gives it one', () async {
      placeOptions(AppEntryRole.flavors);

      expect(
        await run(null),
        allOf(
          startsWith(
            'stopped: The app has no Firebase options for the flavor null.',
          ),
          contains('the scheme Runner'),
          contains('ios/Flutter/Generated.xcconfig'),
          contains('select the scheme of a flavor'),
          contains('flutter build ios --config-only --flavor <flavor>'),
        ),
      );
    });

    test('a release keeps only the options of its own flavor', () async {
      placeOptions(AppEntryRole.flavors);
      for (final flavor in AppEntryRole.flavors) {
        final output = '${root.path}/${flavor.name}.aot';
        final compiled = await Process.run(
          Platform.resolvedExecutable,
          [
            'compile',
            'aot-snapshot',
            '--define=FLUTTER_APP_FLAVOR=${flavor.name}',
            '--define=PLATFORM=android',
            '--output=$output',
            'bin/main.dart',
          ],
          workingDirectory: '${root.path}/app',
        );
        expect(
          compiled.exitCode,
          0,
          reason: '${compiled.stdout}${compiled.stderr}',
        );

        final snapshot = latin1.decode(File(output).readAsBytesSync());
        expect(snapshot, contains(_projectOf(flavor)), reason: flavor.name);
        for (final other in AppEntryRole.flavors) {
          if (other != flavor) {
            expect(
              snapshot,
              isNot(contains(_projectOf(other))),
              reason: '${flavor.name} holds ${other.name}',
            );
          }
        }
      }
    });

    test('tells a selector that always takes one flavor apart', () async {
      final first = AppEntryRole.flavors.first;
      final other = AppEntryRole.flavors.last;
      placeOptions(
        AppEntryRole.flavors,
        selector: brick[FirebaseCoreModule.optionsSelectorFile]!.replaceAll(
          '${other.name}_options.DefaultFirebaseOptions',
          '${first.name}_options.DefaultFirebaseOptions',
        ),
      );

      expect(await run(other.name), startsWith(_projectOf(first)));
    });
  });
}
