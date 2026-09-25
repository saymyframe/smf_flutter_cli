import 'dart:convert';

import 'package:file/file.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/pubspec.dart';

/// The check of the Flutter SDK that every app needs, which the pipeline
/// runs before the checks of the modules.
///
/// It looks for `flutter` on the `PATH` and takes the `dart` of the same
/// SDK, so the formatter and `dart fix` match the Flutter that builds the
/// app; see [PipelineEnvironment.sdk]:
/// - the `dart` next to `flutter` once symbolic links are resolved, as in
///   `/usr/local/bin/flutter -> ~/flutter/bin/flutter`;
/// - otherwise, for a launcher such as the one of the snap, the `dart` of
///   the SDK that `flutter --version --machine` reports as `flutterRoot`.
///
/// A `dart` elsewhere on the `PATH` may belong to another SDK, so it is
/// never taken.
final class FlutterSdkCheck extends PreflightCheck {
  /// Creates the check, which reads [fileSystem].
  FlutterSdkCheck(FileSystem fileSystem) : _fileSystem = fileSystem;

  final FileSystem _fileSystem;

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
    final name = windows ? 'dart.bat' : 'dart';
    final context = _fileSystem.path;

    Future<String?> dartIn(String directory) async {
      final path = context.join(directory, name);
      return await _fileSystem.isFile(path) ? path : null;
    }

    var dart = await dartIn(
      context.dirname(await _fileSystem.file(flutter).resolveSymbolicLinks()),
    );
    if (dart == null) {
      final root = await _flutterRoot(flutter, environment);
      if (root != null) dart = await dartIn(context.join(root, 'bin'));
    }
    if (dart == null) {
      return PreflightMissing(
        instructions: 'The Flutter SDK of $flutter has no dart. Reinstall '
            'Flutter, or run "flutter doctor".',
      );
    }
    final versions = await _versions(context.dirname(context.dirname(dart)));
    found = FlutterSdk(
      flutter: flutter,
      dart: dart,
      flutterVersion: versions?['flutterVersion'],
      dartVersion: versions?['dartSdkVersion'],
    );
    return const PreflightPassed();
  }

  /// The versions that the SDK at [root] records in
  /// `bin/cache/flutter.version.json`, or `null` if it records none.
  Future<Map<String, String>?> _versions(String root) async {
    final file = _fileSystem.file(
      _fileSystem.path.join(root, 'bin', 'cache', 'flutter.version.json'),
    );
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, Object?>) return null;
      return {
        for (final MapEntry(:key, :value) in json.entries)
          if (value is String) key: value.split(' ').first,
      };
    } on Object {
      return null;
    }
  }

  /// The root of the SDK of [flutter], as `flutter --version --machine`
  /// reports it, or `null` if it cannot tell.
  static Future<String?> _flutterRoot(
    String flutter,
    SmfEnvironment environment,
  ) async {
    try {
      final result = await environment.processRunner.run(
        flutter,
        ['--version', '--machine'],
        runInShell: environment.operatingSystem == HostOperatingSystem.windows,
      );
      if (!result.succeeded) return null;
      final output = result.stdout;
      final start = output.indexOf('{');
      if (start < 0) return null;
      final json = jsonDecode(output.substring(start));
      return json is Map<String, Object?> && json['flutterRoot'] is String
          ? json['flutterRoot']! as String
          : null;
    } on Object {
      return null;
    }
  }
}

/// The problems of the Flutter [sdk] with the SDK constraints of the merged
/// [pubspec]: a Dart or Flutter version outside them fails `pub get`, so it
/// is an error before anything is generated.
List<SmfIssue> sdkVersionIssues(FlutterSdk? sdk, MergedPubspec pubspec) {
  if (sdk == null) return const [];
  final issues = <SmfIssue>[];
  void check(String name, String? version, VersionConstraint? constraint) {
    if (version == null || constraint == null) return;
    final Version parsed;
    try {
      parsed = Version.parse(version);
    } on FormatException {
      return;
    }
    if (!constraint.allows(parsed)) {
      issues.add(
        SmfIssue(
          'The modules need $name $constraint, but the Flutter SDK at '
          '${sdk.flutter} has $name $version.',
          hint: 'Upgrade Flutter, or leave out the module that needs a newer '
              'one.',
        ),
      );
    }
  }

  check('Dart', sdk.dartVersion, pubspec.sdk);
  check('Flutter', sdk.flutterVersion, pubspec.flutter);
  return issues;
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
/// First it runs [PreflightCheck.check] of every check, which only reads
/// the machine; with [explain], that is all. Then, when a check reports
/// something missing that it can install, the run is interactive and does
/// not skip external setup, the pipeline asks the user and installs it,
/// going through the checks in order: the directories of the installed
/// tools go into the environment's `PATH`, and the checks after an
/// installation run again, since they may need what it installed.
///
/// Nothing is installed when generation cannot go on anyway: when a
/// required check that nothing can fix fails for the pipeline itself, or
/// for any module with [strict]. Nor for a module that lenient mode will
/// leave out for such a check. Anything still missing gets instructions: an
/// error for a [PreflightCheck.required] check, a warning otherwise.
///
/// [known] holds the results of an earlier run of the stage by
/// [PlannedCheck.key]: a check with a result there is not run again, so the
/// user is asked about an installation once. The results of this run are
/// added to it.
Future<PreflightReport> runPreflight(
  List<PlannedCheck> checks,
  PipelineEnvironment environment, {
  bool explain = false,
  bool strict = false,
  Map<String, CheckResult>? known,
}) async {
  final logger = environment.logger;
  final canInstall =
      !explain && environment.interactive && !environment.skipExternalSetup;

  // Everything the checks find before anything is installed.
  final first = <CheckResult>[];
  for (final planned in checks) {
    final result = known?[planned.key] ??
        CheckResult(planned, await _statusOf(planned.check, environment));
    first.add(result);
    // The checks after it and their tools use the SDK from now on.
    if (planned.check case FlutterSdkCheck(:final found?)) {
      environment.sdk = found;
    }
  }

  // The contributors that a failing required check dooms: one that no
  // installation before it can fix.
  final doomed = <ContributionOrigin>{};
  var installableBefore = false;
  for (final result in first) {
    if (_installable(result)) installableBefore = true;
    if (result.planned.check.required &&
        !result.passed &&
        !_installable(result) &&
        !installableBefore) {
      doomed.add(result.planned.origin);
    }
  }
  final hopeless = doomed.any((origin) => origin is PipelineOrigin) ||
      (strict && doomed.isNotEmpty);

  final results = <CheckResult>[];
  var installed = false;
  for (final (index, planned) in checks.indexed) {
    var result = first[index];
    if (!(known?.containsKey(planned.key) ?? false)) {
      if (installed && !result.passed) {
        result = CheckResult(
          planned,
          await _statusOf(planned.check, environment),
        );
      }
      if (canInstall &&
          !hopeless &&
          !doomed.contains(planned.origin) &&
          _installable(result)) {
        result = await _install(result, environment);
        installed |= result.installed;
      }
    }
    known?[planned.key] = result;
    results.add(result);
  }

  final issues = <SmfIssue>[];
  for (final result in results) {
    final check = result.planned.check;
    if (result.passed) {
      if (!explain) logger.detail('✓ ${check.description}');
      continue;
    }
    final problem = switch (result.status) {
      PreflightMissing(:final instructions) =>
        '${check.description} is missing. $instructions',
      PreflightFailed(:final message) =>
        '${check.description} could not be checked: $message',
      PreflightPassed() => '',
    };
    final origin = result.planned.origin;
    final issueOrigin = origin is PipelineOrigin ? null : origin;
    issues.add(
      check.required
          ? SmfIssue(problem, origin: issueOrigin)
          : SmfIssue.warning(problem, origin: issueOrigin),
    );
  }
  return PreflightReport(results, issues);
}

bool _installable(CheckResult result) => switch (result.status) {
      PreflightMissing(installable: true) => true,
      _ => false,
    };

/// Asks the user whether to install what the check of [found] found
/// missing, and if they agree, installs it and checks again.
Future<CheckResult> _install(
  CheckResult found,
  PipelineEnvironment environment,
) async {
  final planned = found.planned;
  final check = planned.check;
  final agreed = await environment.prompter.confirm(
    '${check.description} is missing (needed by ${planned.origin}). '
    'Install it now?',
    defaultValue: true,
  );
  if (!agreed) return found;
  try {
    final result = await check.install(environment);
    environment.addBinDirs(result.binDirs);
    return CheckResult(
      planned,
      await _statusOf(check, environment),
      installed: true,
    );
  } on Object catch (error) {
    return CheckResult(
      planned,
      PreflightFailed('The installation failed: $error'),
    );
  }
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
