import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';

/// The check of the Flutter SDK that every app needs, which the pipeline
/// runs before the checks of the modules.
///
/// It looks for `flutter` on the `PATH` and takes the `dart` next to it,
/// so both come from the same SDK; see [PipelineEnvironment.sdk].
final class FlutterSdkCheck extends PreflightCheck {
  /// Creates the check.
  FlutterSdkCheck();

  /// The SDK the last [check] found, or `null` if it found none.
  FlutterSdk? found;

  @override
  String get id => 'flutter_sdk';

  @override
  String get description => 'Flutter SDK';

  @override
  bool get required => true;

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    found = null;
    final flutter = await environment.findExecutable('flutter');
    if (flutter == null) {
      return const PreflightMissing(
        instructions: 'Install Flutter '
            '(https://docs.flutter.dev/get-started/install) and add its bin '
            'directory to the PATH.',
      );
    }
    final windows = environment.operatingSystem == HostOperatingSystem.windows;
    final separator = windows ? r'\' : '/';
    final bin = flutter.substring(0, flutter.lastIndexOf(separator) + 1);
    final dart = await environment.findExecutable(
          '$bin${windows ? 'dart.bat' : 'dart'}',
        ) ??
        await environment.findExecutable('dart');
    if (dart == null) {
      return PreflightMissing(
        instructions: 'The Flutter SDK at $flutter has no dart next to it. '
            'Reinstall Flutter, or run "flutter doctor".',
      );
    }
    found = FlutterSdk(flutter: flutter, dart: dart);
    return const PreflightPassed();
  }
}

/// A preflight check with who needs it.
final class PlannedCheck {
  /// Creates the check [check] of [origin].
  const PlannedCheck(this.check, this.origin);

  /// The check.
  final PreflightCheck check;

  /// Who needs it: a module or the pipeline.
  final ContributionOrigin origin;

  /// A key that identifies the check across runs of the stage.
  String get key => '$origin/${check.id}';
}

/// The result of one check.
final class CheckResult {
  /// Creates the result.
  const CheckResult(this.planned, this.status, {this.installed = false});

  /// The check.
  final PlannedCheck planned;

  /// What the check found, after an installation if there was one.
  final PreflightStatus status;

  /// Whether the pipeline installed what the check found missing.
  final bool installed;

  /// Whether the check passed.
  bool get passed => status is PreflightPassed;
}

/// The result of stage 6.
final class PreflightReport {
  /// Creates the report.
  const PreflightReport(this.results, this.issues);

  /// The result of every check, in the order they ran.
  final List<CheckResult> results;

  /// A problem for every check that failed: an error for a required check,
  /// a warning otherwise.
  final List<SmfIssue> issues;
}

/// The checks of the machine that the app needs: the Flutter SDK, then the
/// checks of every [Preflight] among [collection]'s contributions that
/// applies, in the order of the modules.
List<PlannedCheck> plannedChecks(
  Collection collection,
  FlutterSdkCheck sdkCheck,
) =>
    [
      PlannedCheck(sdkCheck, const PipelineOrigin()),
      for (final collected in collection.applyingOf<Preflight>())
        for (final check in (collected.contribution as Preflight).checks)
          PlannedCheck(check, collected.origin),
    ];

/// Stage 6 of the pipeline: runs [checks] on the machine.
///
/// With [explain], it only runs [PreflightCheck.check], which only reads the
/// machine. Otherwise, when a check reports something missing that it can
/// install, and the run is interactive and does not skip external setup,
/// the pipeline asks the user and installs it; the directories of the
/// installed tools go into the environment's `PATH`. Anything still missing
/// gets instructions: an error for a [PreflightCheck.required] check, a
/// warning otherwise.
///
/// Checks whose keys are in [passed] passed in an earlier run of the stage
/// and are skipped; the keys of the checks that pass are added to it.
Future<PreflightReport> runPreflight(
  List<PlannedCheck> checks,
  PipelineEnvironment environment, {
  bool explain = false,
  Set<String>? passed,
}) async {
  final results = <CheckResult>[];
  final issues = <SmfIssue>[];
  final logger = environment.logger;

  for (final planned in checks) {
    final check = planned.check;
    if (passed != null && passed.contains(planned.key)) {
      results.add(CheckResult(planned, const PreflightPassed()));
      continue;
    }
    var status = await _statusOf(check, environment);
    var installed = false;
    if (!explain &&
        status is PreflightMissing &&
        status.installable &&
        environment.interactive &&
        !environment.skipExternalSetup) {
      final install = await environment.prompter.confirm(
        '${check.description} is missing (needed by ${planned.origin}). '
        'Install it now?',
        defaultValue: true,
      );
      if (install) {
        try {
          final result = await check.install(environment);
          environment.addBinDirs(result.binDirs);
          installed = true;
          status = await _statusOf(check, environment);
        } on Object catch (error) {
          status = PreflightFailed('The installation failed: $error');
        }
      }
    }
    final result = CheckResult(planned, status, installed: installed);
    results.add(result);
    if (result.passed) {
      passed?.add(planned.key);
      if (!explain) {
        logger.detail('✓ ${check.description}');
      }
      continue;
    }
    final problem = switch (status) {
      PreflightMissing(:final instructions) =>
        '${check.description} is missing. $instructions',
      PreflightFailed(:final message) =>
        '${check.description} could not be checked: $message',
      PreflightPassed() => '',
    };
    final origin = planned.origin is PipelineOrigin ? null : planned.origin;
    issues.add(
      check.required
          ? SmfIssue(problem, origin: origin)
          : SmfIssue.warning(problem, origin: origin),
    );
  }
  return PreflightReport(results, issues);
}

Future<PreflightStatus> _statusOf(
  PreflightCheck check,
  SmfEnvironment environment,
) async {
  try {
    return await check.check(environment);
  } on Object catch (error) {
    return PreflightFailed('$error');
  }
}
