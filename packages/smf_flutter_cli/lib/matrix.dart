/// The matrix of apps that CI generates with `smf create` and analyzes with
/// Flutter, so that every combination of modules that matters compiles.
library;

import 'dart:io';

import 'package:smf_contracts/lego_core.dart';
import 'package:smf_flutter_cli/src/cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';

/// An app of the matrix: the modules to ask for, which name every module of
/// the app so that no question is left, and the options of its roles.
final class MatrixApp {
  /// Creates the app that the contract harness built for [name].
  const MatrixApp(this.name, this.modules, {this.roleOptions = const {}});

  /// The case of the contract harness that the app comes from.
  final String name;

  /// The modules of the app.
  final List<ModuleId> modules;

  /// The values of role options by name.
  final Map<String, String?> roleOptions;

  /// The arguments of `smf create` that generate the app as [appName] in
  /// [directory], as CI does: without questions, external setup or the
  /// full `dart fix`, and failing instead of leaving out a module.
  List<String> createArguments(String appName, String directory) => [
        'create',
        appName,
        '-m',
        modules.join(','),
        for (final MapEntry(:key, :value) in roleOptions.entries)
          if (value != null) '--$key=$value',
        '-o',
        directory,
        '--on-conflict',
        'replace',
        '--no-input',
        '--skip-external-setup',
        '--no-dart-fix',
        '--strict',
      ];

  @override
  String toString() => '$name (${modules.join(', ')})';
}

/// The apps of the matrix of [modules]: every app that the contract harness
/// builds for them, which covers every module and every provider with each
/// subset of the roles it uses, and the app with as many modules as one app
/// can have.
///
/// A case that the harness finds errors in is among the `failed` ones, since
/// its app could not be generated.
Future<({List<MatrixApp> apps, List<ContractResult> failed})> matrixOf(
  List<SmfModule> modules,
) async {
  final harness = ContractHarness(ModuleRegistry(modules), render: false);
  final results = [
    ...await harness.checkAll(),
    await harness.check(harness.caseOfAll()),
  ];
  final apps = <MatrixApp>[];
  final failed = <ContractResult>[];
  final keys = <String>{};
  for (final result in results) {
    final resolution = result.resolution;
    if (result.errors.isNotEmpty || resolution == null) {
      failed.add(result);
      continue;
    }
    if (!keys.add(result.appKey!)) continue;
    apps.add(
      MatrixApp(
        '${result.contractCase}',
        [for (final module in resolution.modules) module.id],
        roleOptions: result.contractCase.roleOptions,
      ),
    );
  }
  return (apps: apps, failed: failed);
}

/// Generates the app of `smf create` with [arguments] and gives it to
/// [onCreated]; returns the exit code.
typedef MatrixCreate = Future<int> Function(
  List<String> arguments,
  void Function(GeneratedApp app) onCreated,
);

/// Analyzes the app in [directory] and returns the exit code and output of
/// the analyzer.
typedef MatrixAnalyze = Future<(int, String)> Function(String directory);

/// Generates every app of the [matrixOf] of [modules] in [directory], with
/// the options of CI, analyzes each with `flutter analyze`, and returns the
/// exit code: 0 if every app was generated with every module and has no
/// issue, 1 otherwise.
///
/// [log] gets what happens, by default the standard output; the apps stay
/// in [directory]. [create] and [analyze] are `smf create` of this CLI and
/// `flutter analyze`; tests may replace them.
Future<int> runMatrix(
  List<SmfModule> modules, {
  required String directory,
  void Function(String line)? log,
  MatrixCreate? create,
  MatrixAnalyze? analyze,
}) async {
  final say = log ?? (String line) => stdout.writeln(line);
  final createApp = create ??
      (arguments, onCreated) =>
          runCli(arguments, modules: modules, onCreated: onCreated);
  final analyzeApp = analyze ?? _flutterAnalyze;
  final (:apps, :failed) = await matrixOf(modules);
  final problems = [
    for (final result in failed)
      '${result.contractCase}: ${result.errors.join('; ')}',
  ];
  for (final (index, app) in apps.indexed) {
    final name = 'app_${index + 1}';
    say('\n=== $name: $app');
    GeneratedApp? created;
    final code = await createApp(
      app.createArguments(name, directory),
      (generated) => created = generated,
    );
    final generated = created;
    if (code != SmfExitCodes.success || generated == null) {
      problems.add('$name ($app): smf create exited with $code.');
      continue;
    }
    if (generated.leftOut.isNotEmpty) {
      problems.add(
        '$name ($app): smf create left out '
        '${generated.leftOut.map((leftOut) => leftOut.module).join(', ')}.',
      );
      continue;
    }
    final (analyzed, output) = await analyzeApp(generated.path);
    say(output.trim());
    if (analyzed != 0) {
      problems.add('$name ($app): flutter analyze exited with $analyzed.');
    }
  }
  say('\n${apps.length} apps generated in $directory.');
  if (problems.isEmpty) return 0;
  say('Problems:');
  problems.forEach(say);
  return 1;
}

Future<(int, String)> _flutterAnalyze(String directory) async {
  final result = await Process.run(
    'flutter',
    const ['analyze'],
    workingDirectory: directory,
    runInShell: Platform.isWindows,
  );
  return (result.exitCode, '${result.stdout}${result.stderr}');
}
