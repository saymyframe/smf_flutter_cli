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
/// The check runs `firebase --version` as the check of the Firebase CLI of
/// this package does, and takes the last line of its standard output that
/// is a version, of three numbers. Any later version passes, one of a later
/// major version too. A pre-release of the lowest version, such as
/// `15.6.0-rc.1`, comes before it.
///
/// Its description names the lowest version. For an older Firebase CLI, the
/// check tells which command it found and in which version
/// ([PreflightMissing.found]), and how to update it. It installs nothing:
/// the Firebase CLI of the machine may come from npm, from a standalone
/// binary or from a package manager, and other projects of the user run it
/// too, so the user updates it.
///
/// On a machine without the Firebase CLI the check reports it missing, and
/// when the command does not run, it says only that: the check of the
/// Firebase CLI of this package tells why, and offers the installation.
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

  /// Throws an [ArgumentError] when [minimum] is not three numbers, each
  /// within the 64 bits of an `int`, which is a mistake of the module that
  /// created the check.
  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    final lowest = _numbersOf(minimum);
    if (lowest == null) {
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
        if (_versionOn(line.trim()) case final version?) version,
    ].lastOrNull;
    if (printed == null) {
      return PreflightFailed(
        '"firebase --version" printed "${oneLine(tailOf(output, lines: 5))}", '
        'which is not a version.',
      );
    }
    if (_isBefore(printed, lowest)) {
      return PreflightMissing(
        found: '$firebase is ${printed.text}',
        instructions: _update,
      );
    }
    return const PreflightPassed();
  }
}

/// Three numbers with dots between them and nothing else, such as `15.6.0`.
final _threeNumbers = RegExp(r'^\d+\.\d+\.\d+$');

/// The three numbers of [version], or `null` if it is not three numbers and
/// nothing else, as the lowest version that a module may ask for is, or if
/// one of them is beyond the 64 bits of an `int`.
List<int>? _numbersOf(String version) {
  if (!_threeNumbers.hasMatch(version)) return null;
  final numbers = version.split('.').map(int.tryParse).nonNulls.toList();
  return numbers.length == 3 ? numbers : null;
}

/// A version as `firebase --version` prints it on a line of its own: three
/// numbers, then a pre-release after `-` and a build after `+`, if any,
/// such as `15.14.0`, `15.6.0-rc.1` or `15.6.0+build.5`.
final _version = RegExp(r'^(\d+\.\d+\.\d+)(-[^+\s]+)?(\+\S+)?$');

/// A version that `firebase --version` printed: the text of its line, its
/// three numbers and whether it is a pre-release.
typedef _Printed = ({String text, List<int> numbers, bool preRelease});

/// The version on [line] of the output of `firebase --version`, or `null`
/// if the line is not a version (see [_version]), or is one with a number
/// beyond the 64 bits of an `int`, which no version of the Firebase CLI has.
_Printed? _versionOn(String line) {
  final match = _version.firstMatch(line);
  if (match == null) return null;
  final numbers = _numbersOf(match[1]!);
  if (numbers == null) return null;
  return (text: line, numbers: numbers, preRelease: match[2] != null);
}

/// Whether [version] comes before the version of the numbers [lowest]: by
/// its numbers, and with the same numbers when it is a pre-release, which
/// may lack what the version itself has.
bool _isBefore(_Printed version, List<int> lowest) {
  for (var i = 0; i < 3; i++) {
    final number = version.numbers[i];
    if (number != lowest[i]) return number < lowest[i];
  }
  return version.preRelease;
}
