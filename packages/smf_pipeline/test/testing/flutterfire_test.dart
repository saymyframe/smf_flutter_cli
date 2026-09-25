import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  // The plugins blocks of the Gradle files of `flutter create` 3.44.
  const settings = '''
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}
''';
  const app = '''
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
''';

  Matcher failsIn(String path, String message) => throwsA(
        isA<FlutterfireGradleException>()
            .having((e) => e.path, 'path', path)
            .having((e) => e.message, 'message', message),
      );

  group('FlutterfireGradle.configure', () {
    test('adds both plugins after the Android plugin', () {
      final configured = FlutterfireGradle.configure(
        settings: settings,
        app: app,
      );

      expect(
        configured.settings,
        contains(
          '    id("com.android.application") version "9.0.1" apply false\n'
          '    // START: FlutterFire Configuration\n'
          '    id("com.google.gms.google-services") version("4.3.15") '
          'apply false\n'
          '    id("com.google.firebase.crashlytics") version("2.8.1") '
          'apply false\n'
          '    // END: FlutterFire Configuration\n'
          '    id("org.jetbrains.kotlin.android")',
        ),
      );
      expect(
        configured.app,
        contains(
          '    id("com.android.application")\n'
          '    // START: FlutterFire Configuration\n'
          '    id("com.google.gms.google-services")\n'
          '    id("com.google.firebase.crashlytics")\n'
          '    // END: FlutterFire Configuration\n'
          '    // The Flutter Gradle Plugin',
        ),
      );
    });

    test('changes nothing the second time', () {
      final once = FlutterfireGradle.configure(settings: settings, app: app);
      final twice = FlutterfireGradle.configure(
        settings: once.settings,
        app: once.app,
      );

      expect(twice.settings, once.settings);
      expect(twice.app, once.app);
    });

    test('needs the Android plugin in the settings', () {
      expect(
        () => FlutterfireGradle.configure(
          settings: settings.replaceFirst(
            'id("com.android.application") version "9.0.1"',
            'alias(libs.plugins.android.application)',
          ),
          app: app,
        ),
        failsIn(
          FlutterfireGradle.settingsPath,
          'flutterfire configure would take android/settings.gradle.kts for '
          'the settings of a Flutter app older than 3.16.5 and leave the '
          'Firebase plugins out of it, because it declares no plugin as '
          'id("com.android.application").',
        ),
      );
    });

    test('needs a line that starts with the Android plugin in the app', () {
      expect(
        () => FlutterfireGradle.configure(
          settings: settings,
          app: app.replaceFirst(
            '    id("com.android.application")',
            '    alias(libs.plugins.android.application)',
          ),
        ),
        failsIn(
          FlutterfireGradle.appPath,
          'flutterfire configure would leave the Firebase plugins out of '
          'android/app/build.gradle.kts, because no line there starts with '
          'id("com.android.application").',
        ),
      );
    });

    test('needs the version of the Google services plugin in parentheses', () {
      // Declared by the app, the plugin stays as it is, and flutterfire
      // looks for the form it writes itself to add Crashlytics after it.
      expect(
        () => FlutterfireGradle.configure(
          settings: settings.replaceFirst(
            '\n}',
            '\n    id("com.google.gms.google-services") version "4.4.2" '
                'apply false\n}',
          ),
          app: app,
        ),
        failsIn(
          FlutterfireGradle.settingsPath,
          'flutterfire configure would leave the Crashlytics plugin out of '
          'android/settings.gradle.kts, because it finds no '
          'id("com.google.gms.google-services") version("x.y.z") apply false '
          'there.',
        ),
      );
      expect(
        FlutterfireGradle.configure(
          settings: settings.replaceFirst(
            '\n}',
            '\n    id("com.google.gms.google-services") version("4.4.2") '
                'apply false\n}',
          ),
          app: app,
        ).settings,
        contains(
          '    id("com.google.gms.google-services") version("4.4.2") '
          'apply false\n'
          '    id("com.google.firebase.crashlytics") version("2.8.1") '
          'apply false\n',
        ),
      );
    });
  });
}
