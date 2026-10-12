import 'dart:convert';

import 'package:file/file.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/pubspec.dart';
import 'package:smf_pipeline/src/resolver.dart';

/// The check of the Flutter SDK that every app needs, which the pipeline
/// runs before the checks of the modules.
///
/// It looks for `flutter` on the `PATH` and takes the `dart` of the same
/// SDK, so the formatter and `dart fix` match the Flutter that builds the
/// app; see [PipelineEnvironment.sdk]:
/// - the `dart` next to `flutter` once symbolic links are resolved, as in
///   `/usr/local/bin/flutter -> ~/flutter/bin/flutter`, if that directory
///   is the `bin` of a Flutter SDK: it has `cache/dart-sdk` or `internal`;
/// - otherwise, for a launcher such as the one of the snap, the `dart` of
///   the SDK that `flutter --version --machine` reports as `flutterRoot`.
///
/// A `dart` elsewhere, even next to a launcher, may belong to another SDK,
/// so it is never taken.
///
/// Running the launcher is more than reading the machine, since Flutter may
/// update itself or report analytics; with [explain], the check does not
/// run it and only records that the SDK is behind a launcher.
final class FlutterSdkCheck extends PreflightCheck {
  /// Creates the check, which reads [fileSystem].
  FlutterSdkCheck(FileSystem fileSystem, {this.explain = false})
      : _fileSystem = fileSystem;

  final FileSystem _fileSystem;

  /// Whether the run only explains, so the check must not run a launcher.
  final bool explain;

  /// The SDK the last [check] found, or `null` if it found none.
  FlutterSdk? found;

  /// The launcher of Flutter that the last [check] found and, with
  /// [explain], did not run, or `null`.
  String? launcher;

  @override
  String get id => 'flutter_sdk';

  @override
  String get description => 'Flutter SDK';

  @override
  bool get required => true;

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    found = null;
    launcher = null;
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

    /// The `dart` of [bin], if it is the `bin` directory of a Flutter SDK.
    Future<String?> dartIn(String bin) async {
      final path = context.join(bin, name);
      final isSdk = await _fileSystem
              .isDirectory(context.join(bin, 'cache', 'dart-sdk')) ||
          await _fileSystem.isDirectory(context.join(bin, 'internal'));
      return isSdk && await _fileSystem.isFile(path) ? path : null;
    }

    var dart = await dartIn(
      context.dirname(await _fileSystem.file(flutter).resolveSymbolicLinks()),
    );
    if (dart == null && explain) {
      launcher = flutter;
      return const PreflightPassed();
    }
    if (dart == null) {
      final root = await _flutterRoot(flutter, environment);
      if (root != null) dart = await dartIn(context.join(root, 'bin'));
    }
    if (dart == null) {
      return PreflightMissing(
        found: 'the Flutter SDK of $flutter has no dart',
        instructions: 'Reinstall Flutter, or run "flutter doctor".',
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
      );
      if (!result.succeeded) return null;
      // Flutter may print more around the JSON, such as the notice about
      // analytics that follows it on the first run.
      final output = result.stdout;
      final start = output.indexOf('{');
      final end = output.lastIndexOf('}');
      if (start < 0 || end < start) return null;
      final json = jsonDecode(output.substring(start, end + 1));
      return json is Map<String, Object?> && json['flutterRoot'] is String
          ? json['flutterRoot']! as String
          : null;
    } on SmfCancelledException {
      rethrow;
    } on Object {
      return null;
    }
  }
}

/// The problems of the Flutter [sdk] with the SDK constraints of the merged
/// [pubspec]: a Dart or Flutter version outside them fails `pub get`, so it
/// is an error before anything is generated.
///
/// A constraint that one module narrowed is that module's problem, so
/// lenient mode can leave it out. The hint suggests leaving it out only if
/// [canDoWithout] says that an app can be made without it.
List<SmfIssue> sdkVersionIssues(
  FlutterSdk? sdk,
  MergedPubspec pubspec, {
  bool Function(Set<ModuleId> modules) canDoWithout = _anyModules,
}) {
  if (sdk == null) return const [];
  final issues = <SmfIssue>[];
  void check(
    String name,
    String? version,
    VersionConstraint? constraint,
    List<ContributionOrigin> origins,
  ) {
    if (version == null || constraint == null) return;
    final Version parsed;
    try {
      parsed = Version.parse(version);
    } on FormatException {
      return;
    }
    if (constraint.allows(parsed)) return;
    final distinct = origins.toSet();
    final single = distinct.length == 1 ? distinct.single : null;
    final who = switch (distinct.length) {
      0 => 'The app needs',
      1 => '$single needs',
      _ => '${distinct.join(', ')} need',
    };
    issues.add(
      SmfIssue(
        '$who $name $constraint, but the Flutter SDK at ${sdk.flutter} has '
        '$name $version.',
        hint: _upgradeHint(single, canDoWithout),
        origin: single,
      ),
    );
  }

  check('Dart', sdk.dartVersion, pubspec.sdk, pubspec.sdkOrigins);
  check('Flutter', sdk.flutterVersion, pubspec.flutter, pubspec.flutterOrigins);
  return issues;
}

/// The hint of a version of the Flutter SDK outside the constraint of
/// [single], or of several contributors when it is `null`: to upgrade
/// Flutter, or else to leave out the module [single] if [canDoWithout] says
/// that an app can be made without it.
String _upgradeHint(
  ContributionOrigin? single,
  bool Function(Set<ModuleId> modules) canDoWithout,
) =>
    switch (single) {
      ModuleOrigin(:final module) when canDoWithout({module}) =>
        'Upgrade Flutter, or leave out $single.',
      _ => 'Upgrade Flutter.',
    };

/// A default of [runPreflight] and [sdkVersionIssues]: an app can be made
/// without any modules.
bool _anyModules(Set<ModuleId> modules) => true;

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
  const CheckResult(
    this.planned,
    this.status, {
    this.installed = false,
    this.setupFailure,
  });

  /// The check.
  final PlannedCheck planned;

  /// What the check found, after an installation if there was one.
  final PreflightStatus status;

  /// Whether the pipeline installed what the check found missing.
  final bool installed;

  /// Why setting up what the check found missing failed, if the user agreed
  /// to it and it failed; [status] is then what the check found before.
  final String? setupFailure;

  /// Whether the check passed.
  bool get passed => status is PreflightPassed;
}

/// The result of stage 6.
final class PreflightReport {
  /// Creates the report.
  const PreflightReport(
    this.results,
    this.issues, {
    this.versionIssues = const [],
  });

  /// The result of every check, in the order they ran.
  final List<CheckResult> results;

  /// A problem for every check that failed, an error for a required check
  /// and a warning otherwise, followed by [versionIssues].
  final List<SmfIssue> issues;

  /// The problems of the versions of the Flutter SDK with the SDK
  /// constraints of the pubspec; see [sdkVersionIssues].
  final List<SmfIssue> versionIssues;
}

/// The checks of the machine that the app needs: the Flutter SDK, then the
/// checks of every [Preflight] that applies among [collection]'s
/// contributions, which are those of the modules of [resolution] and of the
/// templates of its roles.
///
/// The checks of a module come after those of the modules it depends on,
/// directly or not, wherever the user named those: a module that comes
/// after one that depends on it has its checks right before those of the
/// first such module, and the other modules keep their order; see
/// [Resolution.dependenciesFirst]. A check may need what a check of such a
/// module installs, as a check of the version of a tool needs the tool, and
/// [runPreflight] runs again only the checks after an installation. The
/// checks of the templates of the roles come last, in the order of the
/// roles.
List<PlannedCheck> plannedChecks(
  Collection collection,
  FlutterSdkCheck sdkCheck,
  Resolution resolution,
) =>
    [
      PlannedCheck(sdkCheck, const PipelineOrigin()),
      for (final collected in [
        for (final module in resolution.dependenciesFirst)
          ...collection.ofModule(module.id),
        ...collection.all.where((c) => c.origin is! ModuleOrigin),
      ])
        if (collected.applies)
          if (collected.contribution case Preflight(:final checks))
            for (final check in checks) PlannedCheck(check, collected.origin),
    ];

/// Stage 6 of the pipeline: runs [checks] on the machine.
///
/// First it runs [PreflightCheck.check] of every check, which only reads
/// the machine, with a progress "Checking the machine", since a check may
/// take a while, such as one that asks a service over the network; with
/// [explain], that is all. Then, when a check reports
/// something missing that it can install, the run is interactive and does
/// not skip external setup, the pipeline asks the user and installs it,
/// going through the checks in order: the directories of the installed
/// tools go into the environment's `PATH`, and the checks after an
/// installation run again, since they may need what it installed, each
/// with a progress that names it. A check before an installation does not
/// run again, so [checks] has each check after the checks that may install
/// what it needs, as [plannedChecks] orders them.
///
/// Nothing is installed when generation cannot go on anyway: when a
/// required check that nothing can fix fails for the pipeline itself, or
/// for any module with [strict], or for modules that [canDoWithout] says
/// no app can be made without, which lenient mode does not leave out
/// either. Nor for a module that lenient mode will leave out for such a
/// check. The pipeline does not know which installation a check needs, so
/// a failing required check is one that nothing can fix only when it can
/// install nothing itself and no check before it, of any contributor,
/// found something missing that it can install. When one did, a run that
/// may install offers the installations first, and the required check
/// stops the run, or has its module left out, only once it failed again
/// after them, also when none of them could have fixed it. Anything still
/// missing gets instructions: an error for a [PreflightCheck.required]
/// check, a warning otherwise.
///
/// The versions of the SDK are compared with the SDK constraints of
/// [pubspec] right after the checks, before anything is installed; see
/// [sdkVersionIssues].
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
  bool Function(Set<ModuleId> modules) canDoWithout = _anyModules,
  MergedPubspec? pubspec,
  Map<String, CheckResult>? known,
}) async {
  final canInstall =
      !explain && environment.interactive && !environment.skipExternalSetup;

  // Everything the checks find before anything is installed.
  final first = checks.every((planned) => known?[planned.key] != null)
      ? await _checkAll(checks, environment, known)
      : await _withProgress(
          environment.logger,
          'Checking the machine',
          () => _checkAll(checks, environment, known),
        );

  final doomed = _doomedBy(first);
  final versionIssues = pubspec == null
      ? const <SmfIssue>[]
      : sdkVersionIssues(
          environment.sdk,
          pubspec,
          canDoWithout: canDoWithout,
        );
  for (final issue in versionIssues) {
    doomed.add(issue.origin ?? const PipelineOrigin());
  }
  final doomedModules = {
    for (final origin in doomed)
      if (origin case ModuleOrigin(:final module)) module,
  };
  final hopeless = doomed.any((origin) => origin is PipelineOrigin) ||
      (strict && doomed.isNotEmpty) ||
      (doomedModules.isNotEmpty && !canDoWithout(doomedModules));

  final results = await _installMissing(
    checks,
    first,
    environment,
    known: known,
    mayInstall: (planned) =>
        canInstall && !hopeless && !doomed.contains(planned.origin),
  );
  return PreflightReport(
    results,
    [
      ..._checkIssues(results, environment.logger, explain: explain),
      ...versionIssues,
    ],
    versionIssues: versionIssues,
  );
}

/// The results of [checks] before anything is installed: those in [known],
/// and the results of running the others.
Future<List<CheckResult>> _checkAll(
  List<PlannedCheck> checks,
  PipelineEnvironment environment,
  Map<String, CheckResult>? known,
) async {
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
  return first;
}

/// The contributors that a failing required check among [results] dooms:
/// one that can install nothing itself, with no installable check before
/// it.
///
/// The rule is coarse. Any installable check before a failing required
/// check counts as one whose installation may fix it, whoever contributes
/// it. The checks that can fix it are among them, since they are those of
/// its own module and of the modules that its module depends on (see
/// [plannedChecks]), but so are the checks of modules that have nothing to
/// do with it. So a required check that no installation can fix does not
/// doom its contributor when such a check comes before it: the run offers
/// that installation before it stops, or leaves the module out.
Set<ContributionOrigin> _doomedBy(List<CheckResult> results) {
  final doomed = <ContributionOrigin>{};
  var installableBefore = false;
  for (final result in results) {
    if (_installable(result)) installableBefore = true;
    if (result.planned.check.required &&
        !result.passed &&
        !_installable(result) &&
        !installableBefore) {
      doomed.add(result.planned.origin);
    }
  }
  return doomed;
}

/// Installs, in order, what the [checks] that [mayInstall] found missing,
/// [first], after asking the user, and checks again what failed after an
/// installation; returns the results, which go into [known] too. A check
/// with a result in [known] is left as it is.
Future<List<CheckResult>> _installMissing(
  List<PlannedCheck> checks,
  List<CheckResult> first,
  PipelineEnvironment environment, {
  required Map<String, CheckResult>? known,
  required bool Function(PlannedCheck planned) mayInstall,
}) async {
  final results = <CheckResult>[];
  var installed = false;
  for (final (index, planned) in checks.indexed) {
    var result = first[index];
    if (!(known?.containsKey(planned.key) ?? false)) {
      if (installed && !result.passed) {
        result = CheckResult(
          planned,
          await _checkAgain(planned.check, environment),
        );
      }
      if (mayInstall(planned) && _installable(result)) {
        result = await _install(result, environment);
        installed |= result.installed;
      }
    }
    known?[planned.key] = result;
    results.add(result);
  }
  return results;
}

/// The problems of the [results] that did not pass: an error for a
/// required check, a warning otherwise, which ends with why setting it up
/// failed, if it did. Unless it is an [explain] run, the checks that passed
/// are reported to the detailed log.
List<SmfIssue> _checkIssues(
  List<CheckResult> results,
  SmfLogger logger, {
  required bool explain,
}) {
  final issues = <SmfIssue>[];
  for (final result in results) {
    final check = result.planned.check;
    final state = switch (result.status) {
      PreflightPassed() => null,
      PreflightMissing(:final instructions, found: null) =>
        '${check.description} is missing. $instructions',
      PreflightMissing(:final instructions, :final found?) =>
        '${check.description} is needed, but $found. $instructions',
      PreflightFailed(:final message) =>
        '${check.description} could not be checked: $message',
    };
    if (state == null) {
      if (!explain) logger.detail('✓ ${check.description}');
      continue;
    }
    final problem = switch (result.setupFailure) {
      final failure? => '$state Setting it up failed: $failure',
      null => state,
    };
    final origin = result.planned.origin;
    final issueOrigin = origin is PipelineOrigin ? null : origin;
    issues.add(
      check.required
          ? SmfIssue(problem, origin: issueOrigin)
          : SmfIssue.warning(problem, origin: issueOrigin),
    );
  }
  return issues;
}

bool _installable(CheckResult result) => switch (result.status) {
      PreflightMissing(installable: true) => true,
      _ => false,
    };

/// Asks the user whether to set up what the check of [found] found
/// missing, and if they agree, installs it and checks again.
///
/// The question tells what the check found and how to set it up by hand,
/// such as which version the installation activates in place of the one
/// that is active. When setting it up fails, such as a login that the user
/// stops, what the check found still holds, and the result tells why the
/// setup failed; see [CheckResult.setupFailure].
Future<CheckResult> _install(
  CheckResult found,
  PipelineEnvironment environment,
) async {
  final planned = found.planned;
  final check = planned.check;
  final missing = found.status as PreflightMissing;
  final state = missing.found == null
      ? '${check.description} is missing (needed by ${planned.origin})'
      : '${check.description} is needed by ${planned.origin}, but '
          '${missing.found}';
  final agreed = await environment.prompter.confirm(
    '$state. ${missing.instructions} Set it up now?',
    defaultValue: true,
  );
  if (!agreed) return found;
  try {
    final result = await check.install(environment);
    environment.addBinDirs(result.binDirs);
    return CheckResult(
      planned,
      await _checkAgain(check, environment),
      installed: true,
    );
  } on SmfCancelledException {
    rethrow;
  } on Object catch (error) {
    return CheckResult(planned, found.status, setupFailure: '$error');
  }
}

/// Runs [check] again after an installation, with a progress that names it.
Future<PreflightStatus> _checkAgain(
  PreflightCheck check,
  SmfEnvironment environment,
) =>
    _withProgress(
      environment.logger,
      'Checking ${check.description} again',
      () => _statusOf(check, environment),
    );

/// Runs [body] with a progress of [message], which fails if [body] throws,
/// such as when the user interrupts the run.
Future<T> _withProgress<T>(
  SmfLogger logger,
  String message,
  Future<T> Function() body,
) async {
  final progress = logger.progress(message);
  try {
    final result = await body();
    progress.complete();
    return result;
  } on Object {
    progress.fail();
    rethrow;
  }
}

Future<PreflightStatus> _statusOf(
  PreflightCheck check,
  SmfEnvironment environment,
) async {
  try {
    return await check.check(environment);
  } on SmfCancelledException {
    rethrow;
  } on Object catch (error) {
    return PreflightFailed('$error');
  }
}
