/// The edits that `flutterfire configure` of flutterfire_cli 1.4.0 makes to
/// the Gradle files of a Flutter app in the Kotlin DSL, in the form that the
/// templates of Flutter 3.16.5 and newer have: it adds the Google services
/// plugin, and the Crashlytics plugin to an app that uses Firebase
/// Crashlytics, after lines that its regular expressions find (see its
/// `lib/src/firebase/firebase_android_writes.dart`).
///
/// Where flutterfire finds no such line, it leaves the plugin out without an
/// error, and the app fails only when it runs. So the templates of these
/// files keep those lines, and what modules put into them must not break
/// them.
abstract final class FlutterfireGradle {
  /// The Gradle settings of the app, where flutterfire declares the plugins
  /// with their versions.
  static const settingsPath = 'android/settings.gradle.kts';

  /// The build script of the app module, where flutterfire applies the
  /// plugins.
  static const appPath = 'android/app/build.gradle.kts';

  static const _start = '// START: FlutterFire Configuration';
  static const _end = '// END: FlutterFire Configuration';

  /// What flutterfire looks for in the settings to treat them as the
  /// settings of Flutter 3.16.5 and newer.
  static const _androidPlugin = 'id("com.android.application")';

  static final _appAndroidPlugin = RegExp(
    r'^\s*id\s*\(\s*"com\.android\.application"\s*\)',
    multiLine: true,
  );
  static final _settingsAndroidPlugin = RegExp(
    r'^.*id\("com\.android\.application"\).*',
    multiLine: true,
  );
  static final _appGoogleServices = RegExp(
    r'''(?:(^[\s]*?apply[\s]*\(plugin[\s]*=[\s]*"{1}com\.google\.gms\.google-services"\){1})|(^[\s]*?id[\s]*\("com\.google\.gms\.google-services"\)))''',
    multiLine: true,
  );
  static final _settingsGoogleServices = RegExp(
    "id\\(([\"']com\\.google\\.gms\\.google-services[\"'])\\) "
    "version\\(([\"']\\d+\\.\\d+\\.\\d+[\"'])\\) apply false",
  );

  /// [settings] and [app] after flutterfire adds both plugins, with the
  /// versions it falls back to when it cannot read those of firebase_core.
  ///
  /// Throws a [FlutterfireGradleException] where flutterfire would leave a
  /// plugin out.
  static ({String settings, String app}) configure({
    required String settings,
    required String app,
  }) {
    if (!settings.contains(_androidPlugin)) {
      throw const FlutterfireGradleException(
        settingsPath,
        'flutterfire configure would take $settingsPath for the settings of '
        'a Flutter app older than 3.16.5 and leave the Firebase plugins out '
        'of it, because it declares no plugin as $_androidPlugin.',
      );
    }

    // The Google services plugin, after the Android plugin.
    var configuredApp = app;
    var configuredSettings = settings;
    if (!app.contains('com.google.gms:google-services')) {
      if (!_appAndroidPlugin.hasMatch(app)) {
        throw const FlutterfireGradleException(
          appPath,
          'flutterfire configure would leave the Firebase plugins out of '
          '$appPath, because no line there starts with $_androidPlugin.',
        );
      }
      if (!app.contains('com.google.gms.google-services')) {
        configuredApp = _insertAfter(
          app,
          _appAndroidPlugin,
          '\n    $_start\n    id("com.google.gms.google-services")\n    $_end',
          path: appPath,
          plugin: 'the Google services plugin',
          line: 'a line that starts with $_androidPlugin',
        );
      }
      if (!_appGoogleServices.hasMatch(settings)) {
        configuredSettings = _insertAfter(
          settings,
          _settingsAndroidPlugin,
          '\n    $_start\n'
          '    id("com.google.gms.google-services") version("4.3.15") '
          'apply false\n'
          '    $_end',
          path: settingsPath,
          plugin: 'the Google services plugin',
          line: 'a line with $_androidPlugin',
        );
      }
    }

    // The Crashlytics plugin, after the Google services plugin.
    if (configuredApp.contains('com.google.firebase.crashlytics')) {
      return (settings: configuredSettings, app: configuredApp);
    }
    configuredApp = _insertAfter(
      configuredApp,
      _appGoogleServices,
      '\n    id("com.google.firebase.crashlytics")',
      path: appPath,
      plugin: 'the Crashlytics plugin',
      line: 'a line that starts with id("com.google.gms.google-services")',
    );
    configuredSettings = _insertAfter(
      configuredSettings,
      _settingsGoogleServices,
      '\n    id("com.google.firebase.crashlytics") version("2.8.1") '
      'apply false',
      path: settingsPath,
      plugin: 'the Crashlytics plugin',
      line: 'id("com.google.gms.google-services") version("x.y.z") '
          'apply false',
    );
    return (settings: configuredSettings, app: configuredApp);
  }

  /// [text] with [inserted] after the first match of [pattern].
  static String _insertAfter(
    String text,
    RegExp pattern,
    String inserted, {
    required String path,
    required String plugin,
    required String line,
  }) {
    final match = pattern.firstMatch(text);
    if (match == null) {
      throw FlutterfireGradleException(
        path,
        'flutterfire configure would leave $plugin out of $path, because it '
        'finds no $line there.',
      );
    }
    return text.replaceRange(match.end, match.end, inserted);
  }
}

/// A Gradle file where `flutterfire configure` would leave a Firebase plugin
/// out; see [FlutterfireGradle].
final class FlutterfireGradleException implements Exception {
  /// Creates the exception for the file at [path].
  const FlutterfireGradleException(this.path, this.message);

  /// The path of the file, relative to the root of the app.
  final String path;

  /// What flutterfire would do and why.
  final String message;

  @override
  String toString() => message;
}
