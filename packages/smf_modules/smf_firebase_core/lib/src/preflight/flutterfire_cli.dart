import 'package:smf_contracts/lego.dart';
import 'package:smf_firebase_core/src/preflight/commands.dart';

/// The version of flutterfire_cli that [FlutterfireCliCheck] activates.
///
/// The tests of the module repeat the edits that this version makes to the
/// Gradle files of the app. It is exact, rather than a range such as
/// `^1.4.0`: `cmd.exe`, which runs `dart.bat` on Windows, would read `^`,
/// `<` and `>` in the argument as its own.
const flutterfireVersion = '1.4.1';

/// The lowest version of flutterfire_cli that the check accepts, which
/// writes `lib/firebase_options.dart` in the form of the placeholder.
const minimumFlutterfireVersion = '1.4.0';

/// How the module runs the FlutterFire CLI: through the Dart of the Flutter
/// SDK, which finds a globally activated package without
/// `~/.pub-cache/bin` on the `PATH`.
const flutterfireTool = ToolRef(
  'dart',
  prefixArgs: ['pub', 'global', 'run', 'flutterfire_cli:flutterfire'],
);

/// Checks that the FlutterFire CLI is activated globally, as its
/// documentation installs it, in a version between
/// [minimumFlutterfireVersion] and the next major one.
///
/// `dart pub global list` tells. The tests of the module repeat the changes
/// that flutterfire_cli 1.4 makes to the app; a later 1.x version that is
/// active already is used as it is. The check can activate
/// [flutterfireVersion] in place of an older version, but never in place of
/// a newer major one, which other apps of the user may need: the build
/// phases that flutterfire adds to their Xcode projects run the active one.
final class FlutterfireCliCheck extends PreflightCheck {
  /// Creates the check.
  const FlutterfireCliCheck();

  @override
  String get id => 'flutterfire_cli';

  @override
  String get description => 'FlutterFire CLI';

  static const _activate =
      'dart pub global activate flutterfire_cli $flutterfireVersion';

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    final dart = await environment.findExecutable('dart');
    if (dart == null) {
      return const PreflightFailed('dart of the Flutter SDK was not found.');
    }
    final result = await environment.processRunner.run(
      dart,
      const ['pub', 'global', 'list'],
    );
    if (!result.succeeded) {
      return PreflightFailed(
        '${endOf(
          'dart pub global list',
          result.exitCode,
          environment.operatingSystem,
        )}.',
      );
    }
    final active = RegExp(r'^flutterfire_cli (\S+)', multiLine: true)
        .firstMatch(result.stdout)?[1];
    if (active == null) {
      return const PreflightMissing(
        instructions: 'Activate it with "$_activate".',
        installable: true,
      );
    }
    final major = _numbersOf(active)?.first;
    if (major == null) {
      return PreflightFailed(
        '"dart pub global list" reported flutterfire_cli "$active", which is '
        'not a version.',
      );
    }
    if (isSupportedFlutterfireVersion(active)) return const PreflightPassed();
    if (major > _numbersOf(minimumFlutterfireVersion)!.first) {
      return PreflightMissing(
        instructions: 'flutterfire_cli $active is active, but SMF works with '
            '$minimumFlutterfireVersion or a later 1.x version, and does not '
            'replace a newer one, which other apps may need. To use one, '
            'activate it with "$_activate".',
      );
    }
    return PreflightMissing(
      instructions: 'flutterfire_cli $active is active, but the app needs '
          '$minimumFlutterfireVersion or a later 1.x version: activate one '
          'with "$_activate".',
      installable: true,
    );
  }

  /// Activates [flutterfireVersion] with `dart pub global activate`.
  @override
  Future<ToolInstall> install(SmfEnvironment environment) async {
    final dart = await environment.findExecutable('dart');
    if (dart == null) {
      throw const PreflightSetupException(
        'dart of the Flutter SDK was not found.',
      );
    }
    const activating = 'Activating the FlutterFire CLI';
    final progress = environment.logger.progress(activating);
    final SmfProcessResult result;
    try {
      result = await environment.processRunner.run(
        dart,
        const [
          'pub',
          'global',
          'activate',
          'flutterfire_cli',
          flutterfireVersion,
        ],
      );
    } on Object {
      progress.fail(activating);
      rethrow;
    }
    if (!result.succeeded) {
      progress.fail(activating);
      throw PreflightSetupException(
        failureOf(_activate, result, environment.operatingSystem),
      );
    }
    progress.complete('Activated the FlutterFire CLI $flutterfireVersion');
    return const ToolInstall(tool: flutterfireTool);
  }
}

/// Whether [version] of flutterfire_cli is [minimumFlutterfireVersion] or a
/// later 1.x version.
bool isSupportedFlutterfireVersion(String version) {
  final numbers = _numbersOf(version);
  final minimum = _numbersOf(minimumFlutterfireVersion)!;
  if (numbers == null || numbers[0] != minimum[0]) return false;
  for (var i = 1; i < numbers.length; i++) {
    if (numbers[i] != minimum[i]) return numbers[i] > minimum[i];
  }
  return true;
}

/// The major, minor and patch numbers of [version], or `null` if it does
/// not start with them.
List<int>? _numbersOf(String version) {
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(version);
  return match == null
      ? null
      : [for (var i = 1; i <= 3; i++) int.parse(match[i]!)];
}
