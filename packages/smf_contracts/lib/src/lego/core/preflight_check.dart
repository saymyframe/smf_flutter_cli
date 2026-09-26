import 'package:smf_contracts/lego_core.dart';

/// One check of a [Preflight], such as "the Firebase CLI is installed".
///
/// The pipeline runs [check]. If it reports [PreflightMissing] with an
/// installer and the run is interactive, the pipeline asks the user and
/// calls [install]; otherwise it prints the instructions. With `--explain`
/// the pipeline only runs [check] and reports the result. A failed [required]
/// check stops generation, or drops the module in lenient mode; any other
/// failed check is a warning.
abstract base class PreflightCheck {
  /// Allows subclasses to have constant constructors.
  const PreflightCheck();

  /// A lower snake_case id of the check, unique in its module, by which a
  /// [PostGenStep] of the module [PostGenStep.needs] it.
  String get id;

  /// What the check looks for, such as `Firebase CLI`.
  String get description;

  /// Whether the module cannot work without it.
  bool get required => false;

  /// Checks the machine, and only reads it: it must not install anything,
  /// log in, ask the user or change files outside the temporary files of
  /// [SmfEnvironment.writeTempFile].
  ///
  /// `--explain` runs it to report the state of the machine without running
  /// anything else of the check, and the pipeline runs it again after
  /// [install] to confirm the installation.
  Future<PreflightStatus> check(SmfEnvironment environment);

  /// Installs what [check] found missing and returns where it is.
  ///
  /// The pipeline calls it only after [check] reported
  /// [PreflightMissing.installable] and the user agreed. The default throws an
  /// [UnsupportedError].
  Future<ToolInstall> install(SmfEnvironment environment) async {
    throw UnsupportedError('The preflight check $id cannot install anything.');
  }
}

/// The result of a [PreflightCheck].
sealed class PreflightStatus {
  const PreflightStatus();
}

/// Everything the check looks for is in place.
final class PreflightPassed extends PreflightStatus {
  /// Creates the result.
  const PreflightPassed();
}

/// Something is missing, and [instructions] say how to fix it.
final class PreflightMissing extends PreflightStatus {
  /// Creates the result; set [installable] if [PreflightCheck.install] can
  /// fix it.
  const PreflightMissing({
    required this.instructions,
    this.installable = false,
  });

  /// How the user can fix it by hand.
  final String instructions;

  /// Whether [PreflightCheck.install] can fix it.
  final bool installable;
}

/// The check itself could not run, for the reason in [message].
final class PreflightFailed extends PreflightStatus {
  /// Creates the result.
  const PreflightFailed(this.message);

  /// Why the check could not run.
  final String message;
}

/// What [PreflightCheck.install] installed.
final class ToolInstall {
  /// Creates the result of an installation.
  const ToolInstall({this.binDirs = const [], this.tool});

  /// Directories with the installed executables.
  ///
  /// The pipeline adds them to the `PATH` of later checks and of every
  /// [PostGenStep], so that tools which call each other find them.
  final List<String> binDirs;

  /// How to run the installed tool, if the check provides one.
  final ToolRef? tool;
}
