/// What `flutterfire configure` of flutterfire_cli 1.4 does with the files
/// of the app that SMF generates, repeated in the tests: it finds places in
/// them with regular expressions, and leaves out without an error what it
/// finds no place for.
///
/// It follows `lib/src/firebase/firebase_android_writes.dart` (the Gradle
/// files), `lib/src/flutter_app.dart` (the application id and the bundle
/// id) and `lib/src/firebase/firebase_dart_configuration_write.dart` (the
/// options) of flutterfire_cli 1.4.0, which 1.4.1 did not change. When the
/// module activates a newer flutterfire_cli, compare these files of the two
/// versions and update this file; the tests check that the module activates
/// a 1.4 version.
library;

/// The version of flutterfire_cli that this file repeats.
const flutterfireVersion = '1.4';

/// Where `flutterfire configure` leaves something out, and why.
final class FlutterfireProblem {
  /// Creates the problem of the file at [path].
  const FlutterfireProblem(this.path, this.message);

  /// The path of the file, from the root of the app.
  final String path;

  /// What flutterfire would do and why.
  final String message;

  @override
  String toString() => '$path: $message';
}

/// The Gradle files of the app after `flutterfire configure`, and the
/// plugins it would leave out.
typedef GradleEdits = ({
  String settings,
  String app,
  List<FlutterfireProblem> problems,
});

/// The edits of `flutterfire configure` to the Gradle files of an app in
/// the Kotlin DSL, as flutter create has written them since Flutter 3.29,
/// with the plugins declared in `android/settings.gradle.kts`.
abstract final class FlutterfireGradle {
  /// The Gradle settings, where flutterfire declares the plugins with their
  /// versions.
  static const settingsPath = 'android/settings.gradle.kts';

  /// The build script of the app module, where flutterfire applies them.
  static const appPath = 'android/app/build.gradle.kts';

  /// The build script of the project in the Kotlin DSL, whose presence
  /// makes flutterfire edit the Kotlin files.
  static const rootPath = 'android/build.gradle.kts';

  /// The build script of the project in the Groovy DSL, which flutterfire
  /// looks for first.
  static const groovyRootPath = 'android/build.gradle';

  static const _start = '// START: FlutterFire Configuration';
  static const _end = '// END: FlutterFire Configuration';

  static const _androidPlugin = 'id("com.android.application")';
  static const _googleServicesClassPath = 'com.google.gms:google-services';
  static const _googleServices = 'com.google.gms.google-services';
  static const _crashlyticsClassPath =
      'com.google.firebase:firebase-crashlytics-gradle';
  static const _crashlytics = 'com.google.firebase.crashlytics';

  static final _appAndroidPlugin = RegExp(
    r'^\s*id\s*\(\s*"com\.android\.application"\s*\)',
    multiLine: true,
  );
  static final _appGoogleServices = RegExp(
    r'''(?:(^[\s]*?apply[\s]*\(plugin[\s]*=[\s]*"{1}com\.google\.gms\.google-services"\){1})|(^[\s]*?id[\s]*\("com\.google\.gms\.google-services"\)))''',
    multiLine: true,
  );
  static final _settingsAndroidPlugin = RegExp(
    r'^.*id\("com\.android\.application"\).*',
    multiLine: true,
  );
  static final _settingsGoogleServices = RegExp(
    "id\\(([\"']com\\.google\\.gms\\.google-services[\"'])\\) "
    "version\\(([\"']\\d+\\.\\d+\\.\\d+[\"'])\\) apply false",
  );

  /// The Gradle files among [files], by path, after flutterfire adds the
  /// Google services plugin, and the Crashlytics plugin when
  /// [crashlyticsVersion] is given, as for an app that depends on
  /// firebase_crashlytics; flutterfire takes the versions from the pubspec
  /// of the latest firebase_core in the pub cache.
  static GradleEdits configure(
    Map<String, String> files, {
    required String googleServicesVersion,
    String? crashlyticsVersion,
  }) {
    final problems = <FlutterfireProblem>[];
    var settings = files[settingsPath] ?? '';
    var app = files[appPath] ?? '';
    GradleEdits result() => (settings: settings, app: app, problems: problems);

    if (files.containsKey(groovyRootPath)) {
      problems.add(
        const FlutterfireProblem(
          groovyRootPath,
          'flutterfire configure edits the Groovy files of an app that has '
          '$groovyRootPath, and leaves the Kotlin files as they are.',
        ),
      );
      return result();
    }
    if (!files.containsKey(rootPath)) {
      problems.add(
        const FlutterfireProblem(
          rootPath,
          'flutterfire configure stops with an error, because the app has '
          'neither $groovyRootPath nor $rootPath.',
        ),
      );
      return result();
    }
    if (!settings.contains(_androidPlugin)) {
      problems.add(
        const FlutterfireProblem(
          settingsPath,
          'flutterfire configure takes $settingsPath for the settings of a '
          'Flutter app older than 3.16.5 and declares no plugin in it, '
          'because it has no $_androidPlugin.',
        ),
      );
      return result();
    }

    // The Google services plugin.
    if (app.contains(_googleServicesClassPath)) {
      problems.add(
        const FlutterfireProblem(
          appPath,
          'flutterfire configure takes the Google services plugin for applied '
          'and adds it nowhere, because $appPath names '
          '$_googleServicesClassPath.',
        ),
      );
      return result();
    }
    final androidPlugin = _appAndroidPlugin.firstMatch(app);
    if (androidPlugin == null) {
      problems.add(
        const FlutterfireProblem(
          appPath,
          'flutterfire configure leaves the Firebase plugins out, because no '
          'line of $appPath starts with $_androidPlugin.',
        ),
      );
      return result();
    }
    if (!app.contains(_googleServices)) {
      app = app.replaceRange(
        androidPlugin.end,
        androidPlugin.end,
        '\n    $_start\n    id("$_googleServices")\n    $_end',
      );
    }
    if (!settings.contains(_appGoogleServices)) {
      final match = _settingsAndroidPlugin.firstMatch(settings)!;
      settings = settings.replaceRange(
        match.end,
        match.end,
        '\n    $_start\n'
        '    id("$_googleServices") version("$googleServicesVersion") '
        'apply false\n'
        '    $_end',
      );
    }

    // The Crashlytics plugin, after the Google services plugin.
    if (crashlyticsVersion == null || app.contains(_crashlytics)) {
      return result();
    }
    final googleServices = _appGoogleServices.firstMatch(app);
    if (googleServices == null) {
      problems.add(
        const FlutterfireProblem(
          appPath,
          'flutterfire configure leaves the Crashlytics plugin out, because '
          'no line of $appPath starts with id("$_googleServices").',
        ),
      );
      return result();
    }
    app = app.replaceRange(
      googleServices.end,
      googleServices.end,
      '\n    id("$_crashlytics")',
    );
    if (!settings.contains(RegExp(_crashlyticsClassPath))) {
      final match = _settingsGoogleServices.firstMatch(settings);
      if (match == null) {
        problems.add(
          const FlutterfireProblem(
            settingsPath,
            'flutterfire configure leaves the version of the Crashlytics '
            'plugin out, because $settingsPath has no '
            'id("$_googleServices") version("x.y.z") apply false.',
          ),
        );
        return result();
      }
      settings = settings.replaceRange(
        match.end,
        match.end,
        '\n    id("$_crashlytics") version("$crashlyticsVersion") apply false',
      );
    }
    return result();
  }
}

/// The ids of the Android and iOS apps that `flutterfire configure` reads
/// from the files of the app, when no option gives them.
abstract final class FlutterfireIds {
  /// The application id in the Kotlin build script of the app module.
  static String? androidApplicationIdOf(String appGradle) => RegExp(
        r'''applicationId[\s]?=[\s]?"{1}(?<applicationId>([A-Za-z]{1}[A-Za-z\d_]*\.)+[A-Za-z][A-Za-z\d_]*)"{1}''',
      ).firstMatch(appGradle)?.namedGroup('applicationId');

  /// The first bundle id of the Xcode project.
  static String? iosBundleIdOf(String project) => RegExp(
        r'''^[\s]*PRODUCT_BUNDLE_IDENTIFIER\s=\s(?<bundleId>[A-Za-z\d_\-\.]+)[;]*$''',
        multiLine: true,
      ).firstMatch(project)?.namedGroup('bundleId');
}

/// Whether `flutterfire configure --overwrite-firebase-options` puts the
/// options of [platform], such as `android` or `ios`, into [options], the
/// text of `lib/firebase_options.dart`, in place: it finds the case of the
/// platform in `DefaultFirebaseOptions.currentPlatform`, then the throw
/// after it, which it replaces with a return. Otherwise it writes the whole
/// file anew.
bool fillsOptionsInPlace(String options, String platform) {
  final lines = options.split('\n');
  final label = switch (platform) {
    'ios' => 'iOS',
    'macos' => 'macOS',
    _ => platform,
  };
  final start = lines.indexWhere(
    (line) => line.contains(
      platform == 'web' ? 'if (kIsWeb)' : 'case TargetPlatform.$label:',
    ),
  );
  if (start == -1) return false;
  final error = lines.indexWhere(
    (line) =>
        line.contains('throw UnsupportedError(') ||
        line.contains('throw UnimplementedError('),
    start,
  );
  return error != -1 && lines.indexWhere((l) => l.contains(');'), error) != -1;
}
