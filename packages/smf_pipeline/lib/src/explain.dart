import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/order.dart';
import 'package:smf_pipeline/src/pipeline.dart';
import 'package:smf_pipeline/src/postgen.dart';
import 'package:smf_pipeline/src/preflight.dart';
import 'package:smf_pipeline/src/request.dart';
import 'package:smf_pipeline/src/resolver.dart';
import 'package:smf_pipeline/src/selection.dart';
import 'package:smf_pipeline/src/shell.dart';
import 'package:smf_pipeline/src/validation.dart';

/// The report of `--explain`: what the pipeline would generate and why, and
/// whether the machine is ready, as lines of text.
///
/// It shows:
/// - the app, its identifiers and its directory;
/// - every module with why it is in the app and its variant;
/// - every present role with its providers;
/// - the modules lenient mode left out;
/// - for every socket with more than one contributor, the order of the
///   contributors and the edges that decide it, and the same for the
///   post-generation steps;
/// - the dependencies of the merged pubspec, and the commands that run
///   after generation, quoted for a shell of [operatingSystem], each
///   follow-up of a step under it, and with the systems of a step that runs
///   only on some;
/// - the state of every preflight check, with instructions for what is
///   missing and what a missing required check would do.
final class Explanation {
  /// Creates the report of what the stages 1 to 6 found.
  const Explanation({
    required this.selection,
    required this.context,
    required this.resolution,
    required this.validation,
    required this.preflight,
    required this.leftOut,
    required this.strict,
    required this.operatingSystem,
    this.onConflict = OnConflict.prompt,
    this.sdkIssues = const [],
    this.codegen = const [],
  });

  /// What the user asked for, and where the app goes.
  final Selection selection;

  /// The app being generated.
  final ModuleContext context;

  /// The modules of the app and the roles they provide.
  final Resolution resolution;

  /// The orders of the contributions and the merged pubspec.
  final ValidationResult validation;

  /// The state of the machine.
  final PreflightReport preflight;

  /// The modules lenient mode left out.
  final List<LeftOut> leftOut;

  /// Whether the run is strict, so that a missing required check would stop
  /// it rather than leave out its module.
  final bool strict;

  /// The system whose shell the commands are quoted for.
  final HostOperatingSystem operatingSystem;

  /// What the run would do with a directory of the app that is not empty.
  final OnConflict onConflict;

  /// The problems of the versions of the Flutter SDK.
  final List<SmfIssue> sdkIssues;

  /// The modules that ask for code generation.
  final List<ContributionOrigin> codegen;

  /// The lines of the report.
  List<String> get lines => [
        ..._app(),
        ..._roles(),
        ..._leftOut(),
        ..._orders(),
        ..._dependencies(),
        ..._steps(),
        ..._machine(),
      ];

  List<String> _app() {
    final target = selection.target;
    final conflict = target.conflict ? _conflicts[onConflict]! : '';
    return [
      'App ${context.appName} of ${context.orgName}',
      '  Android application id: ${context.appIdentity.androidApplicationId}',
      '  iOS bundle id: ${context.appIdentity.iosBundleId}',
      '  Directory: ${target.path}$conflict',
      '',
      'Modules',
      for (final module in resolution.modules)
        '  ${module.id}: ${module.reason}${_variant(module)}',
    ];
  }

  List<String> _roles() {
    if (resolution.presentRoles.isEmpty) return const [];
    final lines = ['', 'Roles'];
    for (final role in resolution.presentRoles) {
      final providers = resolution.providersOf(role).map((m) => m.id);
      lines.add('  ${role.description}: ${providers.join(', ')}');
    }
    return lines;
  }

  List<String> _leftOut() {
    if (leftOut.isEmpty) return const [];
    return [
      '',
      'Left out (lenient mode)',
      for (final record in leftOut) '  ${record.module}: ${record.reason}',
    ];
  }

  List<String> _orders() {
    final ordered = [
      for (final MapEntry(key: socket, value: order)
          in validation.socketOrders.entries)
        if (_contributors(order).length > 1) ('$socket', order),
      if (_contributors(validation.postGenOrder).length > 1)
        ('post-generation steps', validation.postGenOrder),
    ];
    if (ordered.isEmpty) return const [];
    final lines = ['', 'Order of contributions'];
    for (final (name, order) in ordered) {
      lines.add('  $name: ${_contributors(order).join(', ')}');
      for (final edge in order.edges) {
        lines.add('    $edge');
      }
      if (order.cycle.isNotEmpty) {
        lines.add('    cycle: ${order.cycle.join(', ')}');
      }
    }
    return lines;
  }

  List<String> _dependencies() {
    final pubspec = validation.pubspec;
    final lines = <String>[];
    for (final (title, dependencies) in [
      ('Dependencies', pubspec.dependencies),
      ('Dev dependencies', pubspec.devDependencies),
    ]) {
      if (dependencies.isEmpty) continue;
      lines
        ..add('')
        ..add(title);
      for (final dependency in dependencies.values) {
        final version = dependency.source == PubspecSource.sdk
            ? 'from the ${dependency.sdk} SDK'
            : dependency.constraintText ?? 'any';
        lines.add(
          '  ${dependency.package} $version '
          '(${dependency.origins.toSet().join(', ')})',
        );
      }
    }
    return lines;
  }

  List<String> _steps() {
    final steps = [
      if (codegen.isNotEmpty)
        '  dart ${codegenArguments.join(' ')} (${codegen.toSet().join(', ')})',
      for (final collected in validation.postGenOrder.contributions)
        if (collected.contribution case final PostGenStep step)
          ..._stepLines(step, collected.origin, operatingSystem),
    ];
    if (steps.isEmpty) return const [];
    return ['', 'After generation', ...steps];
  }

  List<String> _machine() => [
        '',
        'Machine',
        for (final result in preflight.results) ..._checkLines(result),
        for (final issue in sdkIssues) '  ✗ ${issue.message}',
      ];

  /// The lines of the preflight check of [result]: its state, and what a
  /// required check that is not ready would do.
  List<String> _checkLines(CheckResult result) {
    final check = result.planned.check;
    final origin = result.planned.origin;
    final by = origin is PipelineOrigin ? '' : ' (for $origin)';
    final lines = <String>[];
    switch (result.status) {
      case PreflightPassed():
        lines.add('  ✓ ${check.description}$by');
        if (check case FlutterSdkCheck(:final launcher?)) {
          lines.add(
            '    $launcher is a launcher; a run asks it where the SDK is.',
          );
        }
      case PreflightMissing(:final instructions, :final installable):
        lines
          ..add('  ✗ ${check.description}$by: missing')
          ..add('    $instructions');
        if (installable) {
          lines.add('    An interactive run offers to install it.');
        }
      case PreflightFailed(:final message):
        lines.add('  ✗ ${check.description}$by: $message');
    }
    if (!result.passed && check.required) {
      lines.add(
        origin is ModuleOrigin && !strict
            ? '    Generation would leave out ${origin.module}.'
            : '    Generation would stop.',
      );
    }
    return lines;
  }
}

const Map<OnConflict, String> _conflicts = {
  OnConflict.prompt: ' (exists and is not empty; a run asks what to do, '
      'or --on-conflict decides)',
  OnConflict.replace: ' (exists and is not empty; the new app would replace '
      'it)',
  OnConflict.copy: ' (exists and is not empty; the app would go into a new '
      'directory next to it)',
  OnConflict.cancel: ' (exists and is not empty; generation would stop)',
};

String _variant(ResolvedModule module) =>
    module.variant == null ? '' : ', variant for ${module.variant}';

List<String> _contributors(ContributionOrder order) => {
      for (final collected in order.contributions)
        contributorName(collected.origin),
    }.toList();

/// The lines of [step] of [origin] under `After generation`: its command,
/// quoted for a shell of [system], with the systems it runs on if it runs
/// only on some, then, a level deeper each, those of its follow-ups, which
/// run once it succeeded; [depth] is the level of [step].
Iterable<String> _stepLines(
  PostGenStep step,
  ContributionOrigin origin,
  HostOperatingSystem system, {
  int depth = 0,
}) sync* {
  final command = [
    step.tool.executable,
    ...step.tool.argumentsFor(step.arguments),
  ].map((argument) => shellQuoted(argument, system)).join(' ');
  final systems = [for (final host in step.hosts) _systemNames[host]];
  final where = systems.isEmpty ? '' : ', on ${systems.join(', ')}';
  yield '  ${'  ' * depth}${depth == 0 ? '' : 'then '}$command '
      '($origin$where)';
  for (final next in step.followUps) {
    yield* _stepLines(next, origin, system, depth: depth + 1);
  }
}

/// The names of the operating systems in the text of `--explain`.
const Map<HostOperatingSystem, String> _systemNames = {
  HostOperatingSystem.macos: 'macOS',
  HostOperatingSystem.linux: 'Linux',
  HostOperatingSystem.windows: 'Windows',
  HostOperatingSystem.other: 'other systems',
};
