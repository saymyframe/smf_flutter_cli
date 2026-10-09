import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/preflight/commands.dart';
import 'package:smf_firebase_core/src/preflight/firebase_cli.dart';

/// Checks that the Firebase CLI of the machine is [minimum] or later, for a
/// module that depends on this one and runs a command of the Firebase CLI
/// that older versions lack.
///
/// Such a module knows the lowest version that has its command, and this
/// package knows how to ask the Firebase CLI. So the module puts the check
/// into its own [Preflight] with that version, and names it in the
/// [PostGenStep.needs] of the step that runs the command, which takes only
/// checks of its own contributor:
///
/// ```dart
/// const version = FirebaseCliVersionCheck(minimum: '15.6.0');
///
/// const Preflight([version]),
/// PostGenStep(tool, arguments, skippable: true, needs: [version.id]),
/// ```
///
/// The check runs `firebase --version` as [FirebaseCliCheck] does, and takes
/// the last line of its output that is a version, of three numbers. Any
/// later version passes, one of a later major version too. A pre-release of
/// the lowest version, such as `15.6.0-rc.1`, comes before it.
///
/// Its description names the lowest version. For an older Firebase CLI, the
/// check tells which command it found and in which version
/// ([PreflightMissing.found]), and how to update it. It installs nothing:
/// SMF did not install that Firebase CLI, which may come from npm, from a
/// standalone binary or from a package manager, and which other projects of
/// the user run too.
///
/// On a machine without the Firebase CLI the check reports it missing, and
/// when the command does not run, it says only that: [FirebaseCliCheck]
/// tells why, and offers the installation.
final class FirebaseCliVersionCheck extends PreflightCheck {
  /// Creates the check of a Firebase CLI in the version [minimum] or later,
  /// which is three numbers, such as `15.6.0`.
  const FirebaseCliVersionCheck({required this.minimum});

  /// The lowest version of the Firebase CLI that the check accepts.
  final String minimum;

  @override
  String get id => 'firebase_cli_version';

  @override
  String get description => 'Firebase CLI $minimum or later';

  static const _update = 'Update it with "npm install -g firebase-tools" if '
      'npm installed it, or see '
      'https://firebase.google.com/docs/cli#update-cli.';

  /// Throws an [ArgumentError] when [minimum] is not three numbers, which is
  /// a mistake of the module that created the check.
  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    if (!_threeNumbers.hasMatch(minimum)) {
      throw ArgumentError.value(
        minimum,
        'minimum',
        'The lowest version of the Firebase CLI must be three numbers, such '
            'as 15.6.0',
      );
    }
    final firebase = await environment.findExecutable('firebase');
    if (firebase == null) {
      return const PreflightMissing(instructions: howToInstallFirebaseCli);
    }
    final (:output, :why) = await askFirebaseVersion(firebase, environment);
    if (why != null) {
      return const PreflightMissing(
        found: 'the Firebase CLI does not run',
        instructions: howToInstallFirebaseCli,
      );
    }
    final printed = [
      for (final line in output.split('\n'))
        if (_version.firstMatch(line.trim()) case final version?) version,
    ].lastOrNull;
    if (printed == null) {
      return PreflightFailed(
        '"firebase --version" printed "${oneLine(tailOf(output, lines: 5))}", '
        'which is not a version.',
      );
    }
    if (_isBefore(printed, minimum.split('.').map(int.parse).toList())) {
      return PreflightMissing(
        found: '$firebase is ${printed[0]}',
        instructions: _update,
      );
    }
    return const PreflightPassed();
  }
}

/// The lowest version that a module may ask for: three numbers and nothing
/// else, such as `15.6.0`.
final _threeNumbers = RegExp(r'^\d+\.\d+\.\d+$');

/// A version as `firebase --version` prints it on a line of its own: three
/// numbers, then a pre-release after `-` and a build after `+`, if any,
/// such as `15.14.0`, `15.6.0-rc.1` or `15.6.0+build.5`.
final _version = RegExp(r'^(\d+)\.(\d+)\.(\d+)(-[^+\s]+)?(\+\S+)?$');

/// Whether [version], a match of [_version], comes before the version of
/// the numbers [lowest]: by its numbers, and with the same numbers when it
/// is a pre-release, which may lack what the version itself has.
bool _isBefore(RegExpMatch version, List<int> lowest) {
  for (var i = 0; i < 3; i++) {
    final number = int.parse(version[i + 1]!);
    if (number != lowest[i]) return number < lowest[i];
  }
  return version[4] != null;
}
