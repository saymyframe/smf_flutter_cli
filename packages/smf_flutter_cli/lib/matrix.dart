/// The matrix of apps that the continuous integration of SMF generates
/// with `smf create` and analyzes with Flutter: every app that the contract
/// harness builds for a set of modules, and the apps with every module.
///
/// It serves the repository of SMF, and its API may change in any release.
library;

import 'dart:convert';
import 'dart:io' show Platform, Process, stdout;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:smf_contracts/core.dart';
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
/// subset of the roles it uses, and the apps with every module, one for each
/// combination of the providers of roles that take one
/// (see [ContractHarness.casesOfAll]).
///
/// Each app gets [roleOptions], the values of role options for every app,
/// the options of its case, and the answers of the harness to the
/// questions of the roles that they leave open (see
/// [ContractResult.answers]), such as `--start` with the first of several
/// screens that can start the app: `smf create` then makes the same
/// choices without a terminal. The harness renders each app in memory
/// first, so a case that it finds errors in is among the `failed` ones,
/// since its app could not be generated.
Future<({List<MatrixApp> apps, List<ContractResult> failed})> matrixOf(
  List<SmfModule> modules, {
  Map<String, String?> roleOptions = const {},
}) async {
  final harness = ContractHarness(
    ModuleRegistry(modules),
    roleOptions: roleOptions,
  );
  final results = [
    ...await harness.checkAll(),
    for (final contractCase in harness.casesOfAll())
      await harness.check(contractCase),
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
        roleOptions: {
          ...roleOptions,
          ...result.contractCase.roleOptions,
          ...result.answers,
        },
      ),
    );
  }
  return (apps: apps, failed: failed);
}

/// Tests that the matrix adds to the apps it generates and runs with
/// `flutter test`: the files of a [directory] for the apps that
/// [appliesTo] accepts.
///
/// They check what only a running app shows, such as that the start-up of
/// the app works with the platform side of its plugins mocked, and a
/// package keeps them, such as the package of the module they test. They
/// are not part of the apps that `smf create` generates.
final class MatrixAppTest {
  /// Creates the tests of the files in [directory] for the apps that
  /// [appliesTo] accepts.
  const MatrixAppTest(
    this.directory, {
    required this.appliesTo,
    this.devDependencies = const [],
    this.values,
  });

  /// The directory of the files that go into an app, each at its path
  /// relative to the directory, such as `test/firebase_core_test.dart`,
  /// over the file of the app at that path, if the app has one.
  ///
  /// In the text of each file, `{{app_name}}` becomes the name of the
  /// package of the app, and `{{<key>}}` the value of each key of the
  /// [values] of the app. Hidden files stay out. The files of the tests of
  /// an app may use those of other tests that the app always has too, such
  /// as the tests of a module that another depends on.
  final String directory;

  /// Whether the tests run in an app of the matrix.
  final bool Function(MatrixApp app) appliesTo;

  /// The packages that the tests use besides those of the app, which the
  /// matrix adds to the app as dev dependencies, such as the mocks of the
  /// platform side of a plugin.
  final List<String> devDependencies;

  /// The values of the placeholders of the files in an app of the matrix,
  /// besides `app_name`.
  final Map<String, String> Function(MatrixApp app)? values;
}

/// Copies the files of [tests] into the app of the matrix [app], generated
/// in [directory] with the package [packageName], with the placeholders
/// of the files filled, and returns the paths of the files in the app; see
/// [MatrixAppTest.directory].
///
/// Throws a [MatrixAppTestException], before it copies anything, if a file
/// keeps a placeholder that no value fills, or if two of the [tests] have
/// a file at the same path.
List<String> addAppTests(
  List<MatrixAppTest> tests, {
  required MatrixApp app,
  required String directory,
  required String packageName,
  FileSystem fileSystem = const LocalFileSystem(),
}) {
  final context = fileSystem.path;
  final texts = <String, String>{};
  final owners = <String, String>{};
  for (final test in tests) {
    final values = {'app_name': packageName, ...?test.values?.call(app)};
    final root = fileSystem.directory(test.directory);
    final files = [
      for (final entity in root.listSync(recursive: true))
        if (entity is File &&
            !context
                .split(context.relative(entity.path, from: root.path))
                .any((part) => part.startsWith('.')))
          entity,
    ]..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final path = context.relative(file.path, from: root.path);
      if (owners[path] case final other?) {
        throw MatrixAppTestException(
          'The tests of $other and ${test.directory} both have $path.',
        );
      }
      owners[path] = test.directory;
      texts[path] = _filled(file.readAsStringSync(), values, test, path);
    }
  }
  for (final MapEntry(key: path, value: text) in texts.entries) {
    fileSystem.file(context.join(directory, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }
  return [...texts.keys];
}

/// [text], the file at [path] of [test], with the placeholders of [values]
/// filled; throws a [MatrixAppTestException] if it keeps another.
String _filled(
  String text,
  Map<String, String> values,
  MatrixAppTest test,
  String path,
) {
  var filled = text;
  for (final MapEntry(:key, :value) in values.entries) {
    filled = filled.replaceAll('{{$key}}', value);
  }
  if (_placeholder.firstMatch(filled) case final match?) {
    throw MatrixAppTestException(
      'The tests of ${test.directory} keep ${match[0]} in $path: no value '
      'fills it.',
    );
  }
  return filled;
}

/// A problem of the files of [MatrixAppTest]s, which [addAppTests] finds
/// before it copies them into an app.
final class MatrixAppTestException implements Exception {
  /// Creates the exception with [message].
  const MatrixAppTestException(this.message);

  /// What is wrong with the files.
  final String message;

  @override
  String toString() => message;
}

/// A placeholder of the files of a [MatrixAppTest], such as `{{app_name}}`.
final _placeholder = RegExp(r'\{\{\s*[A-Za-z_]\w*\s*\}\}');

/// The `flutter` commands that run [tests] in an app once their files are
/// in it: `flutter pub add` of their dev dependencies, if they have any;
/// `flutter analyze`, since the tests follow the rules of the analysis of
/// the app too; and `flutter test`, which runs every test of the app.
List<List<String>> appTestCommands(List<MatrixAppTest> tests) {
  final devDependencies = {for (final test in tests) ...test.devDependencies};
  return [
    if (devDependencies.isNotEmpty)
      ['pub', 'add', for (final package in devDependencies) 'dev:$package'],
    const ['analyze'],
    const ['test'],
  ];
}

/// Runs `flutter` with [arguments] in [directory] and returns the exit code
/// and the output.
typedef MatrixFlutter = Future<(int, String)> Function(
  List<String> arguments,
  String directory,
);

/// Adds [tests] to [generated], the app of the matrix [app], with
/// [addAppTests], and runs the [appTestCommands] with [flutter] until one
/// fails; returns its exit code and the output up to it, which says which
/// command failed, or 0 and the output of all. A problem of the files of
/// the tests is a failure too, with the exit code 1.
Future<(int, String)> runAppTests(
  GeneratedApp generated,
  MatrixApp app,
  List<MatrixAppTest> tests, {
  MatrixFlutter flutter = _flutter,
  FileSystem fileSystem = const LocalFileSystem(),
}) async {
  final List<String> added;
  try {
    added = addAppTests(
      tests,
      app: app,
      directory: generated.path,
      packageName: generated.name,
      fileSystem: fileSystem,
    );
  } on MatrixAppTestException catch (error) {
    return (1, error.message);
  }
  final output = StringBuffer('Added the tests ${added.join(', ')}.\n');
  for (final arguments in appTestCommands(tests)) {
    final (code, text) = await flutter(arguments, generated.path);
    output.write(text);
    if (code != 0) {
      output.write('\nflutter ${arguments.join(' ')} exited with $code.');
      return (code, '$output');
    }
  }
  return (0, '$output');
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

/// Adds [tests] to [generated], the app of the matrix [app], and runs them
/// with `flutter test`; returns the exit code of the first command that
/// fails and the output up to it, or 0 and the output of all.
typedef MatrixTest = Future<(int, String)> Function(
  GeneratedApp generated,
  MatrixApp app,
  List<MatrixAppTest> tests,
);

/// The commands that [runMatrix] runs for each app, which tests of the
/// matrix may replace; each left `null` is the real one.
final class MatrixCommands {
  /// Creates the commands, with the real one for each left `null`.
  const MatrixCommands({this.create, this.analyze, this.test});

  /// Generates an app: by default `smf create` of this CLI with the modules
  /// of the matrix.
  final MatrixCreate? create;

  /// Analyzes an app: by default `flutter analyze`.
  final MatrixAnalyze? analyze;

  /// Adds the tests that apply to an app and runs them: by default
  /// [runAppTests].
  final MatrixTest? test;
}

/// Generates every app of the [matrixOf] of [modules] with [roleOptions] in
/// [directory], with the options of CI, analyzes each with
/// `flutter analyze`, and, in an app that some of the [appTests] apply to,
/// adds them and runs every test of the app with `flutter test`. Returns
/// the exit code: 0 if every app was generated with every module and every
/// step that the options of CI do not leave for later, has no issue and
/// passes its tests, and each of the [appTests] applies to some app; 1
/// otherwise.
///
/// With [only], it checks only the apps of the matrix with those names,
/// such as `every module (bloc)`, and runs the [appTests] that apply to
/// them; a name that no app of the matrix has is a problem too.
///
/// [log] gets what happens, by default the standard output; the apps stay
/// in [directory], with the tests. [commands] run for each app.
Future<int> runMatrix(
  List<SmfModule> modules, {
  required String directory,
  Map<String, String?> roleOptions = const {},
  List<MatrixAppTest> appTests = const [],
  Set<String>? only,
  void Function(String line)? log,
  MatrixCommands commands = const MatrixCommands(),
}) async {
  final run = _MatrixRun(
    directory: directory,
    appTests: appTests,
    say: log ?? (String line) => stdout.writeln(line),
    create: commands.create ??
        (arguments, onCreated) => runCli(
              arguments,
              modules: modules,
              banner: false,
              onCreated: onCreated,
            ),
    analyze:
        commands.analyze ?? (directory) => _flutter(['analyze'], directory),
    test: commands.test ?? runAppTests,
  );
  final (:apps, :failed) = await matrixOf(modules, roleOptions: roleOptions);
  final problems = [
    for (final result in failed)
      '${result.contractCase}: ${result.errors.join('; ')}',
    for (final name in only ?? const <String>{})
      if (!apps.any((app) => app.name == name))
        'No app of the matrix is $name.',
  ];
  final checked = <MatrixApp>[];
  for (final (index, app) in apps.indexed) {
    if (only != null && !only.contains(app.name)) continue;
    checked.add(app);
    // An app keeps its number in the matrix when only some are checked.
    problems.addAll(await run.check(app, 'app_${index + 1}'));
  }
  // Tests that apply to no app would leave CI without saying so. Those of
  // the apps that are not checked run where the whole matrix is.
  for (final test in appTests) {
    if (!apps.any(test.appliesTo)) {
      problems.add('The tests of ${test.directory} apply to no app.');
    }
  }
  run.say('\n${checked.length} apps generated in $directory.');
  if (problems.isEmpty) return 0;
  run.say('Problems:');
  problems.forEach(run.say);
  return 1;
}

/// A run of [runMatrix], which checks one app after another.
final class _MatrixRun {
  _MatrixRun({
    required this.directory,
    required this.appTests,
    required this.say,
    required this.create,
    required this.analyze,
    required this.test,
  });

  final String directory;
  final List<MatrixAppTest> appTests;
  final void Function(String line) say;
  final MatrixCreate create;
  final MatrixAnalyze analyze;
  final MatrixTest test;

  /// Generates [app] as [name] in the directory, analyzes it and runs its
  /// tests, and returns the problems found.
  Future<List<String>> check(MatrixApp app, String name) async {
    say('\n=== $name: $app');
    GeneratedApp? created;
    final code = await create(
      app.createArguments(name, directory),
      (generated) => created = generated,
    );
    final generated = created;
    if (code != SmfExitCodes.success || generated == null) {
      return ['$name ($app): smf create exited with $code.'];
    }
    if (generated.leftOut.isNotEmpty) {
      final leftOut = generated.leftOut.map((leftOut) => leftOut.module);
      return ['$name ($app): smf create left out ${leftOut.join(', ')}.'];
    }
    final problems = [
      for (final step in generated.skippedSteps)
        if (step.failed) '$name ($app): the step $step.',
    ];
    final (analyzed, output) = await analyze(generated.path);
    say(output.trim());
    if (analyzed != 0) {
      return problems
        ..add('$name ($app): flutter analyze exited with $analyzed.');
    }
    final tests = [
      for (final test in appTests)
        if (test.appliesTo(app)) test,
    ];
    if (tests.isEmpty) return problems;
    final (tested, testOutput) = await test(generated, app, tests);
    say(testOutput.trim());
    if (tested != 0) {
      problems
          .add('$name ($app): its tests failed with the exit code $tested.');
    }
    return problems;
  }
}

// Tests have no Flutter SDK.
// coverage:ignore-start
Future<(int, String)> _flutter(List<String> arguments, String directory) async {
  final result = await Process.run(
    'flutter',
    arguments,
    workingDirectory: directory,
    runInShell: Platform.isWindows,
    // Flutter writes UTF-8, on Windows too.
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  return (result.exitCode, '${result.stdout}${result.stderr}');
}
// coverage:ignore-end
