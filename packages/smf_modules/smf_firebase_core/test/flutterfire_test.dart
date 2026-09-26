@TestOn('vm')
library;

import 'package:smf_contracts/lego.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_core/src/preflight/flutterfire_cli.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'support/flutterfire.dart';

/// The versions of the Gradle plugins that flutterfire declares, from the
/// pubspec of firebase_core 4.15.0.
const _googleServices = '4.4.4';
const _crashlytics = '3.0.7';

/// A module that puts something into the Gradle sockets of the app entry.
final class _GradleModule extends SmfModule {
  const _GradleModule(this.id, this.contributions);

  final ModuleId id;
  final List<Contribution> contributions;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'Gradle of $id',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => contributions;
}

/// A module that adds the classpath of the Google services plugin as a
/// dependency of the app, which flutterfire takes for the plugin applied.
final _classpath = _GradleModule(const ModuleId('classpath'), [
  AppEntryRole.gradleAppDependencies.entry(
    'com.google.gms:google-services',
    '4.4.4',
  ),
]);

/// A module that declares and applies the Google services plugin itself.
final _plugin = _GradleModule(const ModuleId('plugin'), [
  AppEntryRole.gradleSettingsPlugins.entry(
    'com.google.gms.google-services',
    '4.4.2',
  ),
  AppEntryRole.gradleAppPlugins.key('com.google.gms.google-services'),
]);

/// The app of flutter_core, this module and [more] modules.
Future<ContractResult> _app([List<SmfModule> more = const []]) async {
  final modules = [
    const FlutterCoreModule(),
    const FirebaseCoreModule(),
    ...more,
  ];
  final result = await ContractHarness(ModuleRegistry(modules)).check(
    ContractCase(
      'firebase',
      requested: [for (final module in modules) module.descriptor.id],
    ),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError('The app has errors: ${result.errors.join('\n')}');
  }
  return result;
}

/// The Gradle files of [result] after `flutterfire configure`, with the
/// Crashlytics plugin if [crashlytics]; each problem names the contributors
/// of the Gradle sockets, which may have caused it.
({String settings, String app, List<String> problems}) _configure(
  ContractResult result, {
  bool crashlytics = false,
}) {
  final edits = FlutterfireGradle.configure(
    result.app!.texts,
    googleServicesVersion: _googleServices,
    crashlyticsVersion: crashlytics ? _crashlytics : null,
  );
  final contributors = {
    for (final socket in [
      AppEntryRole.gradleSettingsPlugins,
      AppEntryRole.gradleAppPlugins,
      AppEntryRole.gradleAppDependencies,
    ])
      for (final collected
          in result.validation!.socketOrders[socket]?.contributions ??
              const <Collected>[])
        '${collected.origin}',
  };
  return (
    settings: edits.settings,
    app: edits.app,
    problems: [
      for (final problem in edits.problems) _named(problem, contributors),
    ],
  );
}

/// [problem] with the contributors of the Gradle sockets.
String _named(FlutterfireProblem problem, Set<String> contributors) {
  final who = contributors.isEmpty ? 'nobody' : contributors.join(', ');
  return '$problem The Gradle sockets have contributions of: $who.';
}

void main() {
  test('repeats the flutterfire_cli that the module activates', () {
    expect(
      emulatedFlutterfireVersions,
      contains(flutterfireVersion),
      reason: 'Compare the files of flutterfire_cli that '
          'test/support/flutterfire.dart names with those of the new '
          'version, and update it.',
    );
  });

  group('flutterfire configure', () {
    late ContractResult result;
    late Map<String, String> texts;

    setUpAll(() async {
      result = await _app();
      texts = result.app!.texts;
    });

    test('edits the Kotlin files of the app', () {
      expect(texts, contains(FlutterfireGradle.rootPath));
      expect(texts, isNot(contains(FlutterfireGradle.groovyRootPath)));
    });

    test(
        'adds the Google services plugin after the Android plugin in the '
        'settings and in the app', () {
      final configured = _configure(result);

      expect(configured.problems, isEmpty);
      expect(
        configured.settings,
        contains(
          '    id("com.android.application") version "9.0.1" apply false\n'
          '    // START: FlutterFire Configuration\n'
          '    id("com.google.gms.google-services") version("4.4.4") '
          'apply false\n'
          '    // END: FlutterFire Configuration\n'
          '    id("org.jetbrains.kotlin.android")',
        ),
      );
      expect(
        configured.app,
        contains(
          'plugins {\n'
          '    id("com.android.application")\n'
          '    // START: FlutterFire Configuration\n'
          '    id("com.google.gms.google-services")\n'
          '    // END: FlutterFire Configuration\n'
          '    // The Flutter Gradle Plugin',
        ),
      );
    });

    test(
        'adds the Crashlytics plugin after the Google services plugin for an '
        'app with firebase_crashlytics', () {
      final configured = _configure(result, crashlytics: true);

      expect(configured.problems, isEmpty);
      expect(
        configured.settings,
        contains(
          '    id("com.google.gms.google-services") version("4.4.4") '
          'apply false\n'
          '    id("com.google.firebase.crashlytics") version("3.0.7") '
          'apply false\n'
          '    // END: FlutterFire Configuration\n',
        ),
      );
      expect(
        configured.app,
        contains(
          '    id("com.google.gms.google-services")\n'
          '    id("com.google.firebase.crashlytics")\n'
          '    // END: FlutterFire Configuration\n',
        ),
      );
    });

    test('changes nothing more when it runs again', () {
      final once = _configure(result, crashlytics: true);
      final twice = FlutterfireGradle.configure(
        {
          ...texts,
          FlutterfireGradle.settingsPath: once.settings,
          FlutterfireGradle.appPath: once.app,
        },
        googleServicesVersion: _googleServices,
        crashlyticsVersion: _crashlytics,
      );

      expect(twice.problems, isEmpty);
      expect(twice.settings, once.settings);
      expect(twice.app, once.app);
    });

    test('reads the ids of the app', () {
      final identity = ContractHarness.defaultContext.appIdentity;

      final appGradle = texts[FlutterfireGradle.appPath]!;
      expect(
        FlutterfireIds.androidApplicationIdOf(appGradle),
        identity.androidApplicationId,
      );
      expect(
        FlutterfireIds.iosBundleIdOf(texts[AppEntryRole.xcodeProjectFile]!),
        identity.iosBundleId,
      );
    });

    test('fills the options of each platform of the app in place', () {
      final options = texts['lib/firebase_options.dart']!;

      for (final platform in AppEntryRole.platforms) {
        expect(
          fillsOptionsInPlace(options, platform),
          isTrue,
          reason: platform,
        );
      }
      expect(
        fillsOptionsInPlace('class DefaultFirebaseOptions {}', 'ios'),
        isFalse,
      );
    });
  });

  group('with the Gradle sockets of other modules', () {
    test(
        'flutterfire adds the Crashlytics plugin after a Google services '
        'plugin that a module declares', () async {
      final configured = _configure(await _app([_plugin]), crashlytics: true);

      expect(configured.problems, isEmpty);
      expect(
        configured.settings,
        contains(
          '    id("com.google.gms.google-services") version("4.4.2") '
          'apply false\n'
          '    id("com.google.firebase.crashlytics") version("3.0.7") '
          'apply false\n',
        ),
      );
      expect(
        'id("com.google.gms.google-services")'.allMatches(configured.app),
        hasLength(1),
      );
    });

    test(
        'a problem names the contributors of the Gradle sockets, whose '
        'contribution may cause it', () async {
      final configured = _configure(await _app([_classpath]));

      expect(
        configured.problems.single,
        'android/app/build.gradle.kts: flutterfire configure takes the Google '
        'services plugin for applied and adds it nowhere, because '
        'android/app/build.gradle.kts names com.google.gms:google-services. '
        'The Gradle sockets have contributions of: classpath.',
      );
    });
  });

  group('the emulation reports', () {
    const settings = 'plugins {\n'
        '    id("com.android.application") version "9.0.1" apply false\n'
        '}\n';
    const app = 'plugins {\n    id("com.android.application")\n}\n';
    const files = {
      FlutterfireGradle.settingsPath: settings,
      FlutterfireGradle.appPath: app,
      FlutterfireGradle.rootPath: '',
    };

    List<String> problemsOf(Map<String, String> files) => [
          for (final problem in FlutterfireGradle.configure(
            files,
            googleServicesVersion: _googleServices,
            crashlyticsVersion: _crashlytics,
          ).problems)
            '$problem',
        ];

    test('the Groovy files, or no build script of the project', () {
      expect(problemsOf({...files, FlutterfireGradle.groovyRootPath: ''}), [
        startsWith('android/build.gradle: flutterfire configure edits the '
            'Groovy files'),
      ]);
      expect(problemsOf({...files}..remove(FlutterfireGradle.rootPath)), [
        startsWith('android/build.gradle.kts: flutterfire configure stops'),
      ]);
    });

    test('settings without the Android plugin', () {
      expect(
        problemsOf({
          ...files,
          FlutterfireGradle.settingsPath:
              'plugins {\n    alias(libs.plugins.android.application)\n}\n',
        }),
        [contains('older than 3.16.5')],
      );
    });

    test('an app module without a line that applies the Android plugin', () {
      expect(
        problemsOf({
          ...files,
          FlutterfireGradle.appPath:
              'plugins {\n    alias(libs.plugins.android.application)\n}\n',
        }),
        [contains('no line of android/app/build.gradle.kts starts with')],
      );
    });

    test('a Google services plugin that it cannot add Crashlytics after', () {
      expect(
        problemsOf({
          ...files,
          // Named, so the Google services plugin counts as applied, but not
          // on a line of its own.
          FlutterfireGradle.appPath:
              'plugins {\n    id("com.android.application")\n'
                  '    // id("com.google.gms.google-services")\n}\n',
          FlutterfireGradle.settingsPath: settings.replaceFirst(
            '\n}',
            '\n    id("com.google.gms.google-services") version "4.4.4" '
                'apply false\n}',
          ),
        }),
        [contains('leaves the Crashlytics plugin out')],
      );
      expect(
        problemsOf({
          ...files,
          FlutterfireGradle.settingsPath: settings.replaceFirst(
            '\n}',
            '\n    id("com.google.gms.google-services") version "4.4.4" '
                'apply false\n}',
          ),
        }),
        [contains('leaves the version of the Crashlytics plugin out')],
      );
    });
  });
}
