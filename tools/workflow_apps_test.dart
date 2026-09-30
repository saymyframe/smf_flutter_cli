// Checks that the workflows of GitHub Actions, and the scripts of
// .github/scripts that they run, choose the apps they check by role, rather
// than by hand, and know no module but in its own tests.
//
// A module is independent of the others, and a role may get another
// provider at any time, such as a second app entry, which owns the Android
// and Xcode projects. So the workflows take the apps they generate, build
// and start from the matrix tools, whose plan gives the apps with every
// module of a covering of the combinations of the providers of the roles
// that take one, and a new provider gets its apps without a change of the
// workflows. The check fails when a step of a workflow, or a script of
// .github/scripts:
// - selects an app of a matrix tool by its name, such as
//   'every module (bloc)', which names the provider of each role that has
//   several and changes when another role gets a second provider, also
//   through a variable that holds the path of the tool; the tools select
//   them with --every-module, or generate them with --create;
// - refers by its name to an app that the --create of a matrix tool
//   generates, in a command or as its working directory, such as
//   "$apps/android_app": --create names the app with the first provider of
//   each role as it is told, such as android_app, and each of the others
//   after the providers that set it apart, such as android_app_riverpod, so
//   such a step would leave out the apps of the other providers;
//   .github/scripts/each_app.sh runs a command for each app of a directory;
// - runs smf create itself, or names the modules of an app with -m, as in
//   `-m go_router,home` or `-mgo_router,home`, which a second provider of a
//   role that every app has turns into an error, and which leaves out the
//   providers it does not name; the check of the CLI from pub.dev runs smf
//   with the arguments that the matrix of its release lists
//   (packages/smf_flutter_cli/tool/every_module_apps.dart), which the check
//   does not read;
// - refers to the package of a module, but in a step that runs the tests of
//   that module, or in one that refers to it only to run a tool of the
//   module with dart run, which prints what the step needs to know of the
//   module, such as the version of a program that the module installs on
//   the machine of a user, rather than the step repeating it.
// A step that must do one of these is an exception below, with the reason.
// The words of a command are read as its shell reads them: bash, or
// PowerShell, where `\` is a character of a path rather than an escape.
//
// The apps with every module are many: one for each combination of the
// providers of the roles that take one, the product of their numbers. So a
// job of the plan, which runs the matrix tools with --plan, chooses the
// apps that CI builds, archives and starts, and the shards of the matrices,
// and every other job takes one app or one shard of it from the matrix of
// the job, `${{ fromJSON(needs.<plan>.outputs.<list>) }}`. No job then
// takes longer as the apps get more, only the number of jobs grows. The
// check also fails when a step of a workflow, or a script of
// .github/scripts, runs a matrix tool that generates or checks apps in one
// job for a whole selection of them: --create without --app, --every-module
// without --app or --shard, or the matrix without --shard, as a job that
// generates every app into a directory and then builds or starts each; when
// the --app or the --shard of a step does not come from the matrix of its
// job that the plan gives; and when a job or a step computes its
// timeout-minutes, as from the number of apps that it takes.
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The steps that may refer to the package of a module, by the name of the
/// step and the package, with the reason. Each runs tests of the module.
const modulePaths = {
  ('Compare the brick of flutter_core with flutter create', 'smf_flutter_core'):
      'The test of flutter_core that compares its brick with the app of '
          'flutter create of the pinned Flutter.',
  (
    'Configure the app with every module with Firebase for Android',
    'smf_firebase_core',
  ): 'The test of firebase_core that configures the app of the job with '
      'Firebase with the command of its README, before CI starts it.',
  (
    'Configure the app with every module with Firebase for iOS',
    'smf_firebase_core',
  ): 'The test of firebase_core that configures the app of the job with '
      'Firebase with the command of its README, before CI starts it.',
  ('Archive the app with every module', 'smf_firebase_crashlytics'):
      'The test of firebase_crashlytics that archives the app of the job '
          'with the build phase for Crashlytics fixed by the command of its '
          'README.',
  (
    'Fix the build phase for Crashlytics of the app with every module',
    'smf_firebase_crashlytics',
  ): 'The test of firebase_crashlytics that fixes the build phase for '
      'Crashlytics that flutterfire added to the app of the job with the '
      'command of its README, before CI starts it.',
  ('Install the Firebase CLI with the script of SMF', 'smf_firebase_core'):
      'The test of firebase_core that runs its install script of the '
          'Firebase CLI on Windows for real.',
};

/// The steps that may run a tool of the package of a module with dart run,
/// by the name of the step and the path of the tool from the root of the
/// repository, with the reason. Each tool prints what the step needs to
/// know of the module, and the step refers to the package for nothing else.
const moduleTools = {
  (
    'Install the Firebase CLI and the FlutterFire CLI',
    'packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart',
  ): 'The version of the FlutterFire CLI that firebase_core activates on the '
      'machine of a user, which the step activates for the apps of its job.',
  (
    'Run the FlutterFire CLI through dart.bat, and find it as SMF does',
    'packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart',
  ): 'The version of the FlutterFire CLI that firebase_core activates on the '
      'machine of a user, and the name of its check of the machine, which '
      'the step finds in what smf create --explain says.',
};

/// The problems of the [workflow], the text of the workflow [file] of
/// GitHub Actions: the steps that select an app of a matrix tool by its
/// name, that refer by its name to an app that the --create of a matrix
/// tool generates in their job, that run smf create themselves or name the
/// modules of an app with -m, and that refer to the package of a module,
/// other than the exceptions of [modulePaths] and [moduleTools]. The
/// exceptions that apply to a step go into [used].
List<String> problemsOf(
  String workflow, {
  required String file,
  Set<Object>? used,
}) {
  final problems = <String>[];
  final root = loadYaml(workflow) as YamlMap;
  for (final MapEntry(key: job, :value) in (root['jobs'] as YamlMap).entries) {
    final definition = value as YamlMap;
    final steps = [
      for (final step in definition['steps'] as YamlList? ?? YamlList())
        step as YamlMap,
    ];
    final scripts = [
      for (final step in steps)
        _Script(
          '$file, job $job, step "${_nameOf(step)}"',
          '${step['run'] ?? ''}',
          powerShell: _isPowerShell(
            step['shell'] ??
                _default(definition, 'shell') ??
                _default(root, 'shell'),
          ),
          workingDirectory: step['working-directory'] ??
              _default(definition, 'working-directory') ??
              _default(root, 'working-directory'),
          environment: {
            ..._map(root['env']),
            ..._map(definition['env']),
            ..._map(step['env']),
          },
        ),
    ];
    // The apps of --create of the job, by the name they were given.
    final created = {for (final script in scripts) ...script.createdNames};
    for (final (index, step) in steps.indexed) {
      final script = scripts[index];
      final name = _nameOf(step);
      problems.addAll(script.problems(created));
      // The tools of modules that the step may run, and runs.
      final tools = {
        for (final (named, tool) in moduleTools.keys)
          if (named == name && _runOf(tool).hasMatch(script.text)) tool,
      };
      for (final tool in tools) {
        used?.add((name, tool));
      }
      for (final package in _modulePackages(step, tools)) {
        final exception = (name, package);
        if (!modulePaths.containsKey(exception)) {
          problems.add(
            _modulePackage(script.where, package, 'Only a step that runs'),
          );
        } else if (!script.text.contains('dart test')) {
          problems.add(
            '${script.where} refers to the package $package of a module, but '
            'runs no test of it with dart test.',
          );
        } else {
          used?.add(exception);
        }
      }
    }
  }
  return problems;
}

/// The problems of [script], the text of the script [file] of
/// .github/scripts, of bash, or of PowerShell with [powerShell]: as those
/// of a step of a workflow (see [problemsOf]), where the apps of --create
/// are those that the script generates, with no exception.
List<String> scriptProblemsOf(
  String script, {
  required String file,
  bool powerShell = false,
}) {
  final checked = _Script(file, script, powerShell: powerShell);
  return [
    ...checked.problems(checked.createdNames),
    for (final package in _packagesIn(script))
      _modulePackage(file, package, 'Only a step of a workflow that runs'),
  ];
}

/// The name of [step] in the problems: its name, or else the action it
/// uses or its command.
String _nameOf(YamlMap step) =>
    '${step['name'] ?? step['uses'] ?? step['run']}';

/// The problem that [where] refers to the package [package] of a module,
/// which only [who] the tests of the module, or a tool of it, may.
String _modulePackage(String where, String package, String who) =>
    '$where refers to the package $package of a module. $who the tests of '
    'the module, or a tool of it that prints what the step needs to know of '
    'the module, may, as an exception of tools/workflow_apps_test.dart with '
    'its reason.';

/// A script to check: the `run` of a step, or a script of .github/scripts.
final class _Script {
  _Script(
    this.where,
    this.text, {
    required bool powerShell,
    Object? workingDirectory,
    Map<String, String> environment = const {},
  })  : commands = commandsOf(text, powerShell: powerShell),
        workingDirectory =
            workingDirectory == null ? null : '$workingDirectory',
        _environment = environment;

  /// Where the script is, for the problems.
  final String where;

  /// The text of the script.
  final String text;

  /// The words of each command of the script.
  final List<List<String>> commands;

  /// The directory the script runs in, if it is given.
  final String? workingDirectory;

  final Map<String, String> _environment;

  /// The variables that hold the path of a matrix tool, of the environment
  /// or assigned in the script, as `tool=packages/smf_flutter_cli/tool/matrix.dart`
  /// in bash or `$tool = 'packages\smf_flutter_cli\tool\matrix.dart'` in
  /// PowerShell.
  late final Set<String> _toolVariables = {
    for (final MapEntry(:key, :value) in _environment.entries)
      if (_toolPath.hasMatch(value)) key,
    for (final words in commands)
      for (final (index, word) in words.indexed)
        if (_assignment.firstMatch(word) case final match?
            when _toolPath.hasMatch(match[2]!))
          match[1]!
        else if (index + 2 < words.length &&
            words[index + 1] == '=' &&
            _toolPath.hasMatch(words[index + 2]))
          if (_variableOf(word) case final variable?) variable,
  };

  /// Whether [word] is the path of a matrix tool, or a variable that holds
  /// it.
  bool _isTool(String word) =>
      _toolPath.hasMatch(word) || _toolVariables.contains(_variableOf(word));

  /// The names that the script gives the apps it generates with the
  /// --create of a matrix tool.
  late final Set<String> createdNames = {
    for (final words in commands)
      if (_createdName(words, _isTool) case final name?) name,
  };

  /// The problems of the script, with the names [created] of the apps of
  /// --create that the script may see.
  List<String> problems(Set<String> created) => [
        for (final words in commands) ..._problemsOf(words, created),
        if (workingDirectory case final directory?)
          if (_appsNamed([directory], created).isNotEmpty)
            _namedApp(where, directory),
      ];

  List<String> _problemsOf(List<String> words, Set<String> created) => [
        if (_namesOfApps(words, _isTool) case final names when names.isNotEmpty)
          _selected(where, names),
        if (_createdName(words, _isTool) == null)
          for (final word in _appsNamed(words, created)) _namedApp(where, word),
        if (_runsSmfCreate(words)) _byHand(where, 'runs smf create itself'),
        if (_namesModules(words))
          _byHand(where, 'names the modules of an app with -m'),
      ];
}

/// The problem that [where] selects the apps [names] of a matrix tool by
/// their names.
String _selected(String where, List<String> names) =>
    '$where selects apps of a matrix tool by name: ${names.join(', ')}. '
    'Select the apps with every module with --every-module, or generate '
    'them with --create.';

/// The problem that [where] generates an app of modules that it selects by
/// hand, as [what] says.
String _byHand(String where, String what) =>
    '$where $what. Generate the apps with the --create of '
    'packages/smf_flutter_cli/tool/matrix.dart, which names a provider of '
    'every role: the app of the plan of the job with --app, or the apps of '
    'a covering of the combinations of the providers of the roles that take '
    'one.';

/// The problem that [where] refers to an app of --create by its name, in
/// [word].
String _namedApp(String where, String word) =>
    '$where refers to an app of the --create of a matrix tool by its name: '
    '$word. --create generates one app for each combination of the '
    'providers of the roles that take one, named after the providers other '
    'than the first of their roles, so a new provider gets an app that '
    'this leaves out. Run a command for each app of the directory with '
    '.github/scripts/each_app.sh.';

/// The path of a matrix tool, such as
/// packages/smf_flutter_cli/tool/matrix.dart.
final _toolPath = RegExp(r'tool[/\\]matrix\.dart$');

/// An assignment of bash, `name=value`, or of PowerShell, `$name=value`,
/// with the name and the value.
final _assignment = RegExp(r'^\$?(?:env:)?([A-Za-z_]\w*)=(.*)$');

/// The name of the variable that [word] refers to, if it is a reference to
/// one: `$name` or `${name}` of bash, `$env:name` or `${env:name}` of
/// PowerShell, or `${{ env.name }}` of GitHub Actions.
String? _variableOf(String word) => switch (RegExp(
      r'^\$(?:\{\{\s*env\.(\w+)\s*\}\}|\{(?:env:)?(\w+)\}|(?:env:)?(\w+))$',
    ).firstMatch(word)) {
      final match? => match[1] ?? match[2] ?? match[3],
      null => null,
    };

/// Whether [shell], the shell of a step, is PowerShell.
bool _isPowerShell(Object? shell) => shell == 'pwsh' || shell == 'powershell';

/// The value of [key] in the `defaults.run` of [definition], a workflow or
/// one of its jobs.
Object? _default(YamlMap definition, String key) =>
    switch (definition['defaults']) {
      {'run': final YamlMap run} => run[key],
      _ => null,
    };

/// The variables of [environment], the `env` of a workflow, a job or a
/// step, if it has one, as texts.
Map<String, String> _map(Object? environment) => {
      if (environment case final YamlMap map)
        for (final MapEntry(:key, :value) in map.entries) '$key': '$value',
    };

/// The words of each command of [script], a script of bash, or of
/// PowerShell with [powerShell], as far as the check needs them: the words
/// in quotes without the quotes, with the character that the escape
/// character of the shell escapes (`\` in bash, which in double quotes
/// escapes only `$`, a backtick, `"` and `\`, and a backtick in
/// PowerShell, where `\` is a character like any other, as in its paths),
/// the lines that end with the escape character joined with the next, a
/// variable such as `${name}` or `${{ env.name }}` kept in its word, and a
/// command ended by a new line, `;`, `|`, `&`, a parenthesis, a brace or a
/// redirection. Comments stay out.
List<List<String>> commandsOf(String script, {bool powerShell = false}) {
  final escape = powerShell ? '`' : r'\';
  final text = script.replaceAll(
    RegExp('${RegExp.escape(escape)}\\r?\\n'),
    ' ',
  );
  final commands = <List<String>>[];
  var words = <String>[];
  final word = StringBuffer();
  var inWord = false;
  String? quote;
  void endWord() {
    if (inWord) words.add('$word');
    word.clear();
    inWord = false;
  }

  void endCommand() {
    endWord();
    if (words.isNotEmpty) commands.add(words);
    words = [];
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quote != null) {
      if (char == quote) {
        quote = null;
      } else if (quote == '"' &&
          char == escape &&
          i + 1 < text.length &&
          (powerShell || r'$`"\'.contains(text[i + 1]))) {
        word.write(text[++i]);
      } else {
        word.write(char);
      }
    } else if (char == escape && i + 1 < text.length) {
      word.write(text[++i]);
      inWord = true;
    } else if (char == '"' || char == "'") {
      quote = char;
      inWord = true;
    } else if (char == r'$' && text.startsWith('{', i + 1)) {
      // A variable, such as ${name} or ${{ env.name }}, whose braces end
      // no command.
      final close = text.startsWith('{{', i + 1) ? '}}' : '}';
      final end = text.indexOf(close, i);
      final next = end < 0 ? text.length : end + close.length;
      word.write(text.substring(i, next));
      inWord = true;
      i = next - 1;
    } else if (char == '#' && !inWord) {
      final end = text.indexOf('\n', i);
      i = end < 0 ? text.length : end - 1;
    } else if (char == '>' || char == '<') {
      // The number of a stream before a redirection, as in 2>&1, is no
      // argument.
      if (RegExp(r'^\d+$').hasMatch('$word')) {
        word.clear();
        inWord = false;
      }
      endCommand();
    } else if ('\n;|&(){}'.contains(char)) {
      endCommand();
    } else if (char == ' ' || char == '\t' || char == '\r') {
      endWord();
    } else {
      word.write(char);
      inWord = true;
    }
  }
  endCommand();
  return commands;
}

/// The arguments that the command [words] gives a matrix tool, which
/// [isTool] finds, if it runs one; `null` otherwise, as for a command that
/// assigns the path of the tool to a variable of PowerShell.
List<String>? _argumentsOfTool(
  List<String> words,
  bool Function(String) isTool,
) {
  for (final (index, word) in words.indexed) {
    if (!isTool(word)) continue;
    final arguments = words.sublist(index + 1);
    return arguments.firstOrNull == '=' ? null : arguments;
  }
  return null;
}

/// The names of apps that the command [words] gives a matrix tool, if it
/// runs one, which [isTool] finds: the arguments after its directory, or
/// after the directory of --every-module.
List<String> _namesOfApps(List<String> words, bool Function(String) isTool) =>
    switch (_choiceOf(_argumentsOfTool(words, isTool)).arguments) {
      ['--every-module', _, ...final names] => names,
      [final directory, ...final names] when !directory.startsWith('-') =>
        names,
      _ => const [],
    };

/// The name that the command [words] gives the apps it generates with the
/// --create of a matrix tool, which [isTool] finds, if it does: the name of
/// the app with the first provider of each role, such as start_app, which
/// the name of each of the others starts with, such as start_app_riverpod.
String? _createdName(List<String> words, bool Function(String) isTool) =>
    switch (_choiceOf(_argumentsOfTool(words, isTool)).arguments) {
      ['--create', '--without-external-steps', _, final name, ...] => name,
      ['--create', _, final name, ...] => name,
      _ => null,
    };

/// The options of the matrix tools that choose the apps of a run, each with
/// a value: the combinations of the providers that its apps with every
/// module cover, one of them by its name, or a shard of them.
const _choiceOptions = {'--combinations', '--app', '--shard'};

/// [arguments], the arguments of a matrix tool, without the options of
/// [_choiceOptions] among the options before its directory, and those
/// options with their values; no arguments for `null`.
({List<String> arguments, Map<String, String> choice}) _choiceOf(
  List<String>? arguments,
) {
  final rest = <String>[];
  final choice = <String, String>{};
  final given = arguments ?? const <String>[];
  var index = 0;
  while (index < given.length && given[index].startsWith('-')) {
    final option = given[index];
    if (_choiceOptions.contains(option) && index + 1 < given.length) {
      choice[option] = given[index + 1];
      index += 2;
    } else {
      rest.add(option);
      index++;
    }
  }
  return (arguments: [...rest, ...given.skip(index)], choice: choice);
}

/// What the command [words] does with a matrix tool, which [isTool] finds,
/// when it generates or checks, in the one job that runs it, a whole
/// selection of apps rather than one app of the plan or a shard of it:
/// --create without --app, --every-module without --app or --shard, or the
/// matrix without --shard. `null` for any other command, as for one that
/// lists the tests of the apps or adds them to an app, prints the plan, or
/// only explains what smf create would generate.
String? _wholeSelection(List<String> words, bool Function(String) isTool) {
  final (:arguments, :choice) = _choiceOf(_argumentsOfTool(words, isTool));
  return switch (arguments) {
    ['--create', ...final rest]
        when !rest.contains('--explain') && !choice.containsKey('--app') =>
      'generates every app with every module of a selection (--create '
          'without --app)',
    ['--every-module', ...]
        when !choice.containsKey('--app') && !choice.containsKey('--shard') =>
      'checks every app with every module of a selection (--every-module '
          'without --app or --shard)',
    [final directory, ...]
        when !directory.startsWith('-') && !choice.containsKey('--shard') =>
      'checks every app of a matrix (without --shard)',
    _ => null,
  };
}

/// The problem that [where] does [what], as [_wholeSelection] finds it.
String _whole(String where, String what) =>
    '$where $what. A job that builds, archives or starts apps with every '
    'module takes one app of the plan with --app, and a job that checks the '
    'apps of a matrix takes a shard of it with --shard, from the matrix of '
    'the job, which the plan gives with '
    r'${{ fromJSON(needs.<plan>.outputs.<list>) }}: so no job takes longer '
    'as the apps get more, only the number of jobs grows.';

/// The problems of the matrix tools that [script] runs: a run of
/// [_wholeSelection], and, in a job whose matrix has the keys [planKeys]
/// from the plan, all of them for `*`, an --app or a --shard of a run that
/// generates or checks apps that does not come from the matrix of the plan,
/// directly or through a variable of the environment of the step. A run
/// that only explains what smf create would generate may take an app of the
/// plan as it likes. A script of .github/scripts, which has no matrix, has
/// no [planKeys] and takes them as it is given them.
List<String> _planProblemsOfScript(_Script script, Set<String>? planKeys) {
  final problems = <String>[];
  for (final words in script.commands) {
    if (_wholeSelection(words, script._isTool) case final what?) {
      problems.add(_whole(script.where, what));
    }
    final (:arguments, :choice) = _choiceOf(
      _argumentsOfTool(words, script._isTool),
    );
    if (planKeys == null || arguments.contains('--explain')) continue;
    for (final option in ['--app', '--shard']) {
      final value = choice[option];
      if (value == null) continue;
      final key = _matrixKeyOf(value) ??
          switch (_variableOf(value)) {
            final variable? => _matrixKeyOf(script._environment[variable]),
            null => null,
          };
      if (key == null || !(planKeys.contains(key) || planKeys.contains('*'))) {
        problems.add(
          '${script.where} takes $option $value, which is no value of a '
          'matrix of its job that the plan gives: take it from '
          r'${{ matrix.<key> }} of a matrix of '
          r'${{ fromJSON(needs.<plan>.outputs.<list>) }}, directly or through '
          'a variable of the environment of the step.',
        );
      }
    }
  }
  return problems;
}

/// The key of the value of the matrix that [text] is, `${{ matrix.<key> }}`,
/// if it is one.
String? _matrixKeyOf(String? text) => text == null
    ? null
    : RegExp(r'^\$\{\{\s*matrix\.([\w-]+)\s*\}\}$').firstMatch(text)?[1];

/// A matrix, or a value of one, from the output of a job:
/// `${{ fromJSON(needs.<job>.outputs.<output>) }}`, with the job and the
/// output.
final _fromPlan = RegExp(
  r'^\$\{\{\s*fromJSON\(\s*needs\.([\w-]+)\.outputs\.([\w-]+)\s*\)\s*\}\}$',
);

/// The problems of the plan in [workflow], the text of the workflow [file]
/// of GitHub Actions: a step that runs a matrix tool for a whole selection
/// of apps in one job, or takes an --app or a --shard that does not come
/// from the matrix of its job that the plan gives, a matrix that takes an
/// output of a job that the job of the matrix does not need or that has no
/// such output, and a job or a step that computes its timeout-minutes.
List<String> planProblemsOf(String workflow, {required String file}) {
  final problems = <String>[];
  final root = loadYaml(workflow) as YamlMap;
  final jobs = root['jobs'] as YamlMap;
  for (final MapEntry(key: job, :value) in jobs.entries) {
    final definition = value as YamlMap;
    final where = '$file, job $job';
    final needs = switch (definition['needs']) {
      final String job => {job},
      final YamlList list => {for (final job in list) '$job'},
      _ => const <String>{},
    };
    // The keys of the matrix of the job that the plan gives, or * for all.
    final planKeys = <String>{};
    void fromPlan(Object? text, String key) {
      final match = _fromPlan.firstMatch('${text ?? ''}');
      if (match == null) return;
      final [needed, output] = [match[1]!, match[2]!];
      if (!needs.contains(needed)) {
        problems.add(
          '$where takes its matrix from needs.$needed.outputs.$output, but '
          '$needed is not among the needs of the job.',
        );
      } else if (!(((jobs[needed] as YamlMap?)?['outputs'] as YamlMap?)
              ?.containsKey(output) ??
          false)) {
        problems.add(
          '$where takes its matrix from needs.$needed.outputs.$output, but '
          'the job $needed has no output $output.',
        );
      } else if (_secretOf(jobs[needed] as YamlMap) case final secret?) {
        problems.add(
          '$where takes its matrix from needs.$needed.outputs.$output, but '
          'the job $needed refers to the secret $secret. The runner hides the '
          'lines of each secret that a job refers to in the outputs of the '
          'job, and leaves out an output that has one of them, such as the { '
          'of a key in JSON, so the matrix would have no value: refer to the '
          'secret in a job of its own.',
        );
      }
      planKeys.add(key);
    }

    switch ((definition['strategy'] as YamlMap?)?['matrix']) {
      case final YamlMap matrix:
        for (final MapEntry(:key, :value) in matrix.entries) {
          fromPlan(value, key == 'include' ? '*' : '$key');
        }
      case final Object matrix:
        fromPlan(matrix, '*');
    }
    if (definition['timeout-minutes'] case final Object minutes
        when minutes is! int) {
      problems.add(_computedTimeout(where, minutes));
    }
    for (final step in definition['steps'] as YamlList? ?? YamlList()) {
      final map = step as YamlMap;
      final script = _Script(
        '$where, step "${_nameOf(map)}"',
        '${map['run'] ?? ''}',
        powerShell: _isPowerShell(
          map['shell'] ??
              _default(definition, 'shell') ??
              _default(root, 'shell'),
        ),
        environment: {
          ..._map(root['env']),
          ..._map(definition['env']),
          ..._map(map['env']),
        },
      );
      if (map['timeout-minutes'] case final Object minutes
          when minutes is! int) {
        problems.add(_computedTimeout(script.where, minutes));
      }
      problems.addAll(_planProblemsOfScript(script, planKeys));
    }
  }
  return problems;
}

/// The tool that writes what the apps of a directory build their native
/// side with, for a platform, into a file whose hash keys the caches of the
/// native builds:
/// `dart tools/native_build.dart <platform> <directory of apps> <file>`.
const nativeBuildTool = 'tools/native_build.dart';

/// The variable of the environment of a workflow, in its `env`, with how
/// many MB a build must add to the cache of its native build that its job
/// restored for the job to save the cache: the one place that gives it,
/// with its reason.
const nativeCacheThreshold = 'NATIVE_CACHE_SAVE_ABOVE_MB';

/// The inputs of a reusable workflow that let its jobs save the caches of
/// the native builds.
const nativeCacheSaveInputs = ['save_gradle_cache', 'save_swiftpm_cache'];

/// The condition of a value of an input of [nativeCacheSaveInputs] that
/// keeps the saves to the runs on main.
const _onMain = "github.ref == 'refs/heads/main'";

/// The problems of the caches of the native builds in [workflow], the text
/// of the workflow [file] of GitHub Actions: of what the package manager of
/// the platform of a job downloads for the native build, Gradle on Linux,
/// for Android, and Swift Package Manager on macOS, for iOS, whose cache of
/// the repositories of packages xcodebuild keeps in
/// ~/Library/Caches/org.swift.swiftpm.
/// - A job on Linux or macOS that generates an app with --create, to build,
///   archive or start it, and restores no such cache. Without it each such
///   job downloads the same plugins again, such as the Firebase SDK, and
///   Maven Central answers 403 to a runner that downloads too much.
/// - A job that restores the cache but never saves it, and a step that
///   saves it only in some jobs of its matrix, by a condition on the
///   strategy or the matrix of the job, such as `strategy.job-index == 0`.
///   What the app of another job needs beyond the cache that the job
///   restores, such as the native side of a plugin that the app that saves
///   the cache does not have, would never get into a cache, and each run
///   would download it again.
/// - A step that saves the cache under a key that does not depend on the
///   app that its job builds: a key without the hash of the file that
///   [nativeBuildTool] writes for the platform of the job, after the step
///   that generates the apps with --create, if the job has one. A step that
///   saves the cache with the key of the step that restored it,
///   `steps.<id>.outputs.cache-primary-key`, takes the key of that step.
///   The jobs whose apps build with the same then share one cache, and the
///   app of a job that builds with something else, such as another plugin
///   or other versions of Gradle and its plugins, gets a cache of its own.
/// - A step that saves the cache whenever its job did not find the key of
///   its app, rather than only when the build added more than
///   [nativeCacheThreshold] MB to the cache that the job restored: its
///   condition must take an output of a step between the step of its key
///   and it that compares the size of the cache with the threshold, and
///   with the size that a step after the step of its key measured. A cache
///   is saved whole, over 1 GB for Gradle, so a job whose app needs a few
///   MB more than the cache of another app would store a near copy of it
///   in the 10 GB of caches of the repository. And a workflow that compares
///   with the threshold without setting it in its `env`.
List<String> nativeCacheProblemsOf(String workflow, {required String file}) {
  final problems = <String>[];
  final root = loadYaml(workflow) as YamlMap;
  final jobs = root['jobs'] as YamlMap;
  if (!_map(root['env']).containsKey(nativeCacheThreshold) &&
      workflow.contains(RegExp(r'\$\{?' + nativeCacheThreshold))) {
    problems.add(_noThreshold(file));
  }
  for (final MapEntry(key: job, :value) in jobs.entries) {
    final definition = value as YamlMap;
    final native = _nativeCacheOf('${definition['runs-on']}');
    if (native == null) continue;
    final (:manager, :path, :platform) = native;
    final steps = [
      for (final step in definition['steps'] as YamlList? ?? YamlList())
        step as YamlMap,
    ];
    final uses = [for (final step in steps) _cacheUseOf(step, path)];
    final restores = uses.any((use) => use?.restores ?? false);
    if (_generatesApps(definition) && !restores) {
      problems.add(_uncached(file, job, manager, path));
    } else if (restores && !uses.any((use) => use?.saves ?? false)) {
      problems.add(_neverSaved(file, job, manager, path));
    }
    for (final (index, step) in steps.indexed) {
      if (!(uses[index]?.saves ?? false)) continue;
      final where = '$file, job $job, step "${_nameOf(step)}"';
      if (step['if'] case final Object condition
          when RegExp(r'\b(?:strategy|matrix)\.').hasMatch('$condition')) {
        problems.add(_someJobs(where, manager, '$condition'));
      }
      final (key, keyed) = _keyOf(steps, index);
      if (!_byApp(key, steps, keyed, platform)) {
        problems.add(_notByApp(where, manager, key, platform));
      }
      if (!_byGrowth(steps, index, keyed)) {
        problems.add(_notByGrowth(where, manager));
      }
    }
  }
  return problems;
}

/// The problem that the workflow [file] compares what builds add to the
/// caches of their native builds with [nativeCacheThreshold] without setting
/// it.
String _noThreshold(String file) =>
    '$file compares what the builds add to the caches of their native builds '
    'with $nativeCacheThreshold, but does not set it in its env, the one '
    'place that gives it with its reason.';

/// The problem that [where] saves the cache of [manager] whenever its job
/// did not find the key of its app.
String _notByGrowth(String where, String manager) =>
    '$where saves the cache of $manager whenever the job did not find the '
    'key of its app, rather than only when its build added more than '
    '\$$nativeCacheThreshold MB to the cache that the job restored. A cache '
    'is saved whole, over 1 GB for Gradle, so a job whose app needs a few MB '
    'more than the cache of another app would store a near copy of that '
    'cache in the 10 GB of caches of the repository. Measure the cache after '
    'the step that restores it, and save it only when a step after the '
    'build finds that the build added more than that.';

/// Whether the step [index] of [steps], which saves a cache under the key
/// of the step [keyed], saves it only when the build added more than
/// [nativeCacheThreshold] MB to it: whether its condition takes an output of
/// a step between them that compares with the threshold, and that takes
/// an output of a step between the step [keyed] and it, which measured the
/// cache that the job restored.
bool _byGrowth(List<YamlMap> steps, int index, int keyed) {
  Iterable<int> outputsIn(Iterable<Object?> texts) => [
        for (final text in texts)
          for (final match in RegExp(r'steps\.([\w-]+)\.outputs\.')
              .allMatches('${text ?? ''}'))
            steps.indexWhere((step) => step['id'] == match[1]),
      ];
  return outputsIn([steps[index]['if']]).any(
    (growth) =>
        growth > keyed &&
        growth < index &&
        '${steps[growth]['run'] ?? ''}'.contains(nativeCacheThreshold) &&
        outputsIn([steps[growth]['run'], ..._map(steps[growth]['env']).values])
            .any((restored) => restored > keyed && restored < growth),
  );
}

/// The problems of the saves of the caches of the native builds in
/// [workflows], the texts of the workflows of GitHub Actions by the names of
/// their files: a reusable workflow whose input of [nativeCacheSaveInputs]
/// is true by default, and a job that calls one with such an input that is
/// neither false nor kept to the runs on main, `github.ref ==
/// 'refs/heads/main'`. A run of a pull request, or a run by hand on another
/// branch, saves its caches for its own ref, where only its own later runs
/// find them, so they only duplicate those of main in the 10 GB of caches of
/// the repository.
List<String> nativeCacheSaveProblemsOf(Map<String, String> workflows) {
  final problems = <String>[];
  final roots = {
    for (final MapEntry(:key, :value) in workflows.entries)
      key: loadYaml(value) as YamlMap,
  };
  // The reusable workflows with such inputs.
  final saving = <String>{};
  for (final MapEntry(key: file, value: root) in roots.entries) {
    final inputs = switch (root['on']) {
      {'workflow_call': {'inputs': final YamlMap inputs}} => inputs,
      _ => YamlMap(),
    };
    for (final input in nativeCacheSaveInputs) {
      if (inputs[input] case final YamlMap definition) {
        saving.add(file);
        if (definition['default'] == true) {
          problems.add(_savesByDefault(file, input));
        }
      }
    }
  }
  for (final MapEntry(key: file, value: root) in roots.entries) {
    for (final MapEntry(key: job, :value)
        in (root['jobs'] as YamlMap? ?? YamlMap()).entries) {
      final called = '${(value as YamlMap)['uses'] ?? ''}'.split('/').last;
      if (!saving.contains(called)) continue;
      for (final input in nativeCacheSaveInputs) {
        if ((value['with'] as YamlMap?)?[input] case final Object given
            when given != false && !'$given'.contains(_onMain)) {
          problems.add(_savesOutsideMain(file, job, called, input, given));
        }
      }
    }
  }
  return problems;
}

/// The problem that the reusable workflow [file] saves the caches of the
/// native builds by default, by its input [input].
String _savesByDefault(String file, String input) =>
    '$file lets its jobs save the caches of the native builds by default '
    '($input: true), so a workflow that calls it without the input saves '
    'them in any run, such as that of a pull request: make it false by '
    'default, and let the workflows that call it pass it for the runs on '
    'main.';

/// The problem that the job [job] of the workflow [file] calls the workflow
/// [called] with the input [input] [given], which lets it save the caches
/// of the native builds outside the runs on main.
String _savesOutsideMain(
  String file,
  Object? job,
  String called,
  String input,
  Object given,
) =>
    '$file, job $job calls $called with $input: $given, which lets it save '
    'the caches of the native builds in other runs than those on main. A run '
    'of a pull request, or a run by hand on another branch, saves them for '
    'its own ref, where only its own later runs find them, so they only '
    'duplicate those of main in the 10 GB of caches of the repository: keep '
    'the input to \${{ $_onMain }}, with any other condition of the '
    'workflow.';

/// The problem that the job [job] of the workflow [file] generates an app
/// to build and restores no cache of [manager], whose path has [path].
String _uncached(String file, Object? job, String manager, String path) =>
    '$file, job $job generates an app with --create to build it for its '
    'platform, but restores no cache of $manager ($path): each job would '
    'download the same packages again.';

/// The problem that the job [job] of the workflow [file] restores the cache
/// of [manager], whose path has [path], and never saves it.
String _neverSaved(String file, Object? job, String manager, String path) =>
    '$file, job $job restores the cache of $manager ($path) but never saves '
    'it, so what its app needs beyond the cache that it restores, such as '
    'the native side of a plugin that the apps of the jobs that save the '
    'cache do not have, is downloaded again in every run: save the cache of '
    'its app, under the key of the app, when the workflow lets it.';

/// The problem that [where] saves the cache of [manager] only in the jobs
/// of its matrix that [condition] lets through.
String _someJobs(String where, String manager, String condition) =>
    '$where saves the cache of $manager only in some jobs of its matrix '
    '(if: $condition), so what the apps of the other jobs need beyond the '
    'cache that they restore is downloaded again in every run: let every '
    'job save the cache of its app, under the key of the app, when the '
    'workflow lets it.';

/// The problem that [where] saves the cache of [manager] under [key], which
/// does not depend on the app for [platform] that its job builds.
String _notByApp(
  String where,
  String manager,
  String key,
  String platform,
) =>
    '$where saves the cache of $manager under the key $key, which does not '
    'depend on the app that the job builds. Take the key from the hash of '
    'the file that `dart $nativeBuildTool $platform <directory of apps> '
    '<file>` writes once the apps of the job are generated, so that the '
    'jobs whose apps build with the same share one cache, and a job whose '
    'app builds with another plugin or another native project saves a '
    'cache of its own.';

/// The package manager of the native builds on the runner [runsOn], a part
/// of the path of its cache, and the platform of the builds as
/// [nativeBuildTool] takes it, or `null` for a runner that builds none.
({String manager, String path, String platform})? _nativeCacheOf(
  String runsOn,
) =>
    switch (runsOn) {
      final label when label.startsWith('ubuntu') => (
          manager: 'Gradle',
          path: '.gradle/',
          platform: 'android',
        ),
      final label when label.startsWith('macos') => (
          manager: 'Swift Package Manager',
          path: 'org.swift.swiftpm',
          platform: 'ios',
        ),
      _ => null,
    };

/// Whether a step of [job] generates apps with --create.
bool _generatesApps(YamlMap job) => [
      for (final step in job['steps'] as YamlList? ?? YamlList())
        '${(step as YamlMap)['run'] ?? ''}',
    ].any((run) => run.contains('--create'));

/// Whether [step] restores and whether it saves a cache whose path has
/// [path], or `null` for a step that does neither: actions/cache restores
/// the cache and saves it at the end of the job, actions/cache/restore only
/// restores it, and actions/cache/save only saves it.
({bool restores, bool saves})? _cacheUseOf(YamlMap step, String path) {
  if (!'${(step['with'] as YamlMap?)?['path'] ?? ''}'.contains(path)) {
    return null;
  }
  return switch ('${step['uses'] ?? ''}') {
    final uses when uses.startsWith('actions/cache/restore@') => (
        restores: true,
        saves: false,
      ),
    final uses when uses.startsWith('actions/cache/save@') => (
        restores: false,
        saves: true,
      ),
    final uses when uses.startsWith('actions/cache@') => (
        restores: true,
        saves: true,
      ),
    _ => null,
  };
}

/// The key of the cache of the step [index] of [steps], and the index of
/// the step whose key it is: that of the step that restored the cache for
/// a key `${{ steps.<id>.outputs.cache-primary-key }}`, as a step that only
/// saves the cache takes it, and its own otherwise.
(String, int) _keyOf(List<YamlMap> steps, int index) {
  String keyOf(YamlMap step) => '${(step['with'] as YamlMap?)?['key'] ?? ''}';
  final key = keyOf(steps[index]);
  final restored = RegExp(
    r'^\$\{\{\s*steps\.([\w-]+)\.outputs\.cache-primary-key\s*\}\}$',
  ).firstMatch(key.trim());
  final source = restored == null
      ? -1
      : steps.indexWhere((step) => step['id'] == restored[1]);
  return source < 0 || source >= index
      ? (key, index)
      : (keyOf(steps[source]), source);
}

/// Whether [key], the key of the step [index] of [steps], depends on the
/// apps for [platform] of the job: whether it hashes with hashFiles a file
/// that a step between the last before it that generates apps with
/// --create, if there is one, and it writes with [nativeBuildTool] for
/// [platform].
bool _byApp(String key, List<YamlMap> steps, int index, String platform) {
  final generated = steps
      .sublist(0, index)
      .lastIndexWhere((step) => '${step['run'] ?? ''}'.contains('--create'));
  final written = {
    for (final step in steps.sublist(generated + 1, index))
      for (final words in commandsOf('${step['run'] ?? ''}'))
        if (_nativeBuildFileOf(words, platform) case final file?) file,
  };
  return {
    for (final call in RegExp(r'hashFiles\(([^)]*)\)').allMatches(key))
      for (final file in RegExp(r'''(['"])(.*?)\1''').allMatches(call[1]!))
        file[2]!,
  }.any(written.contains);
}

/// The file that the command [words] writes with [nativeBuildTool] for
/// [platform], if it runs the tool for it: its third argument, after the
/// platform and the directory of the apps.
String? _nativeBuildFileOf(List<String> words, String platform) {
  final tool = words.indexWhere(
    (word) => RegExp(r'(^|[/\\])tools[/\\]native_build\.dart$').hasMatch(word),
  );
  return tool >= 0 && tool + 3 < words.length && words[tool + 1] == platform
      ? words[tool + 3]
      : null;
}

/// The first secret that the job [job] refers to, such as
/// `FIREBASE_SERVICE_ACCOUNT` of `secrets.FIREBASE_SERVICE_ACCOUNT`, or
/// `null` if it refers to none.
String? _secretOf(YamlMap job) =>
    RegExp(r'secrets\.([\w-]+)').firstMatch(job.span.text)?[1];

/// The problem that [where] computes its timeout-minutes, [minutes].
String _computedTimeout(String where, Object minutes) =>
    '$where computes its timeout-minutes, $minutes. A job takes a fixed '
    'number of apps of the plan, one or a shard, so its time does not grow '
    'with the number of apps: give it a fixed number of minutes.';

/// The problems of the plan in [script], the text of the script [file] of
/// .github/scripts, of bash, or of PowerShell with [powerShell]: a run of a
/// matrix tool for a whole selection of apps, as in a step of a workflow
/// (see [planProblemsOf]). A script has no matrix to take the app or the
/// shard from, so it takes them as it is given them.
List<String> scriptPlanProblemsOf(
  String script, {
  required String file,
  bool powerShell = false,
}) =>
    _planProblemsOfScript(
      _Script(file, script, powerShell: powerShell),
      null,
    );

/// The words of [words] that refer to an app of [names], the names of the
/// apps of --create, by a part of their path: the name, or the name with
/// providers after it.
Iterable<String> _appsNamed(Iterable<String> words, Set<String> names) =>
    words.where(
      (word) => word.split(RegExp(r'[/\\]')).any(
            (part) => names.any(
              (name) => part == name || part.startsWith('${name}_'),
            ),
          ),
    );

/// The index of the word of the command [words] that runs smf, or -1:
/// bin/smf_flutter.dart of its package, `smf_flutter_cli:<executable>` of
/// dart pub global run, or the program of the command, after the
/// assignments of variables and a program that runs another, such as env,
/// if it is smf, by its name or its path. Another word smf is an argument,
/// such as the name of a virtual device.
int _smfIndex(List<String> words) {
  final entry = words.indexWhere(
    (word) => RegExp(
      r'(^|[/\\])bin[/\\]smf_flutter\.dart$|^smf_flutter_cli:\w+$',
    ).hasMatch(word),
  );
  if (entry >= 0) return entry;
  final program = words.indexWhere(
    (word) =>
        !_assignment.hasMatch(word) &&
        !const {'env', 'exec', 'nohup', 'time'}.contains(word),
  );
  return program >= 0 &&
          RegExp(r'(^|[/\\])smf(\.bat|\.exe)?$').hasMatch(words[program])
      ? program
      : -1;
}

/// Whether the command [words] runs smf create.
bool _runsSmfCreate(List<String> words) {
  final smf = _smfIndex(words);
  return smf >= 0 && smf + 1 < words.length && words[smf + 1] == 'create';
}

/// Whether the command [words] names the modules of an app with the option
/// of `smf create`: -m or --modules anywhere, and -m with its value
/// attached, as in -mgo_router,home, in a command that runs smf, since
/// other programs have options of their own that start with -m, such as
/// the -mindepth of find.
bool _namesModules(List<String> words) {
  final smf = _smfIndex(words);
  return [
    for (final (index, word) in words.indexed)
      word == '-m' ||
          word == '--modules' ||
          word.startsWith('--modules=') ||
          (smf >= 0 && index > smf && word.startsWith('-m')),
  ].contains(true);
}

/// The packages of modules that [step] refers to by path in its command,
/// its working directory, its environment and its inputs: a directory
/// right in packages/smf_modules, but not a pattern for any of them, nor
/// the path of one of [tools] in a run of it with dart run in its command.
Set<String> _modulePackages(YamlMap step, Set<String> tools) => {
      for (final text in [
        tools.fold(
          '${step['run'] ?? ''}',
          (run, tool) => run.replaceAll(_runOf(tool), 'dart run'),
        ),
        step['working-directory'],
        if (step['env'] case final YamlMap env) ...env.values,
        if (step['with'] case final YamlMap inputs) ...inputs.values,
      ])
        ..._packagesIn('${text ?? ''}'),
    };

/// A run of the tool at [path], a path from the root of the repository,
/// with dart run: the path with either separator, maybe in quotes.
RegExp _runOf(String path) => RegExp(
      r'''\bdart\s+run\s+(["']?)'''
      '${path.split('/').map(RegExp.escape).join(r'[/\\]')}'
      r'\1(?![\w.])',
    );

/// The packages of modules that [text] refers to by path.
Set<String> _packagesIn(String text) => {
      for (final match
          in RegExp(r'packages[/\\]smf_modules[/\\](\w+)').allMatches(text))
        match[1]!,
    };

void main() {
  String workflow(String steps) => 'jobs:\n  a:\n    steps:\n$steps';

  group('reads the commands of a script', () {
    test(r'of bash, where \ escapes a character', () {
      expect(
        commandsOf(r'''
dart run "packages\smf\a \"b\" \$c" d\ e ${f} "${{ env.G }}" # h
x=$(echo "$y") && z || w; v > log
'''),
        [
          [
            'dart',
            'run',
            r'packages\smf\a "b" $c',
            'd e',
            r'${f}',
            r'${{ env.G }}',
          ],
          [r'x=$'],
          ['echo', r'$y'],
          ['z'],
          ['w'],
          ['v'],
          ['log'],
        ],
      );
    });

    test(r'of PowerShell, where a backtick escapes a character and \ is none',
        () {
      expect(
        commandsOf(
          r'''
dart run "packages\smf_flutter_cli\tool\matrix.dart" `
  "$env:RUNNER_TEMP\SMF apps" 'every module (bloc)' "a `"b`""
$tool = 'packages\smf_flutter_cli\tool\matrix.dart'
''',
          powerShell: true,
        ),
        [
          [
            'dart',
            'run',
            r'packages\smf_flutter_cli\tool\matrix.dart',
            r'$env:RUNNER_TEMP\SMF apps',
            'every module (bloc)',
            'a "b"',
          ],
          [r'$tool', '=', r'packages\smf_flutter_cli\tool\matrix.dart'],
        ],
      );
    });
  });

  group('finds a step that selects an app of a matrix tool by name', () {
    test('in bash and in PowerShell', () {
      expect(
        problemsOf(
          workflow(r'''
      - name: Non-ASCII
        run: |
          apps="$RUNNER_TEMP/SMF apps застосунки é"
          dart run packages/smf_flutter_cli/tool/matrix.dart "$apps" 'every module (riverpod)'
      - name: Windows
        shell: pwsh
        run: |
          $PSNativeCommandUseErrorActionPreference = $true
          dart run packages/smf_flutter_cli/tool/matrix.dart "$env:RUNNER_TEMP\SMF apps" 'every module (bloc)'
          dart run packages\smf_pipeline\fixture_registry\tool\matrix.dart `
            --every-module "$env:RUNNER_TEMP\SMF apps" fake_codegen
          dart run "packages\smf_flutter_cli\tool\matrix.dart" "$env:RUNNER_TEMP\SMF apps" 'every module (riverpod)'
'''),
          file: 'apps.yml',
        ),
        [
          equals(
            'apps.yml, job a, step "Non-ASCII" selects apps of a matrix tool '
            'by name: every module (riverpod). Select the apps with every '
            'module with --every-module, or generate them with --create.',
          ),
          startsWith(
            'apps.yml, job a, step "Windows" selects apps of a matrix tool by '
            'name: every module (bloc).',
          ),
          startsWith(
            'apps.yml, job a, step "Windows" selects apps of a matrix tool by '
            'name: fake_codegen.',
          ),
          startsWith(
            'apps.yml, job a, step "Windows" selects apps of a matrix tool by '
            'name: every module (riverpod).',
          ),
        ],
      );
    });

    test('in PowerShell, the shell of every step of the job', () {
      expect(
        problemsOf(
          r'''
jobs:
  windows:
    defaults:
      run:
        shell: pwsh
    steps:
      - name: Windows
        run: dart run "packages\smf_flutter_cli\tool\matrix.dart" "$env:RUNNER_TEMP\SMF apps" 'every module (bloc)'
''',
          file: 'apps.yml',
        ),
        [
          startsWith(
            'apps.yml, job windows, step "Windows" selects apps of a matrix '
            'tool by name: every module (bloc).',
          ),
        ],
      );
    });

    test('through a variable that holds the path of the tool', () {
      expect(
        problemsOf(
          workflow(r'''
      - name: Bash
        run: |
          tool=packages/smf_flutter_cli/tool/matrix.dart
          dart run "$tool" "$apps" 'every module (bloc)'
          dart run ${tool} "$apps" 'every module (riverpod)'
      - name: Environment
        env:
          TOOL: packages/smf_flutter_cli/tool/matrix.dart
        run: dart run "$TOOL" "$apps" first_app
      - name: PowerShell
        shell: pwsh
        run: |
          $tool = 'packages\smf_flutter_cli\tool\matrix.dart'
          dart run $tool "$env:RUNNER_TEMP\SMF apps" 'every module (bloc)'
          $env:TOOL='packages\smf_flutter_cli\tool\matrix.dart'
          dart run $env:TOOL "$env:RUNNER_TEMP\SMF apps" second_app
'''),
          file: 'apps.yml',
        ),
        [
          startsWith(
            'apps.yml, job a, step "Bash" selects apps of a matrix tool by '
            'name: every module (bloc).',
          ),
          startsWith(
            'apps.yml, job a, step "Bash" selects apps of a matrix tool by '
            'name: every module (riverpod).',
          ),
          startsWith(
            'apps.yml, job a, step "Environment" selects apps of a matrix '
            'tool by name: first_app.',
          ),
          startsWith(
            'apps.yml, job a, step "PowerShell" selects apps of a matrix tool '
            'by name: every module (bloc).',
          ),
          startsWith(
            'apps.yml, job a, step "PowerShell" selects apps of a matrix tool '
            'by name: second_app.',
          ),
        ],
      );
    });

    test('but not the ways of the tools to select them by role', () {
      expect(
        problemsOf(
          workflow(r'''
      - name: Matrix
        run: dart run packages/smf_flutter_cli/tool/matrix.dart "$RUNNER_TEMP/SMF apps"
      - name: Every module
        run: |
          # With every module; 'every module (bloc)' is one of them.
          dart run packages/smf_flutter_cli/tool/matrix.dart --every-module "$apps" 2>&1 | tee log
          tool=packages/smf_flutter_cli/tool/matrix.dart
          dart run "$tool" --create --without-external-steps "$apps" start_app > out
          for app in "$apps"/*/; do
            dart run packages/smf_flutter_cli/tool/matrix.dart --add-app-tests \
              "${app%/}" packages/smf_flutter_cli/app_tests/start
          done
          matrix="$(dart run packages/smf_flutter_cli/tool/matrix.dart --app-tests)"
          other=packages/smf_flutter_cli/tool/flutter_versions.dart
          dart run "$other" "$apps" 'every module (bloc)'
'''),
          file: 'apps.yml',
        ),
        isEmpty,
      );
    });
  });

  group('finds a step that refers to an app of --create by its name', () {
    test('in a command and as its working directory', () {
      expect(
        problemsOf(
          workflow(r'''
      - name: Generate
        run: |
          dart run packages/smf_flutter_cli/tool/matrix.dart --create "$RUNNER_TEMP/apps" android_app
          dart run packages/smf_flutter_cli/tool/matrix.dart --create --without-external-steps "$RUNNER_TEMP/SMF apps/firebase" firebase_start_app --org com.saymyframe.ci
      - name: Build
        run: cd "$RUNNER_TEMP/apps/android_app" && flutter build apk --debug
      - name: Start
        working-directory: ${{ runner.temp }}/SMF apps/firebase/firebase_start_app
        run: flutter test
      - name: Start the second
        run: .github/scripts/start_app.sh "$RUNNER_TEMP\SMF apps\firebase\firebase_start_app_riverpod" 480
'''),
          file: 'apps.yml',
        ),
        [
          equals(
            'apps.yml, job a, step "Build" refers to an app of the --create '
            r'of a matrix tool by its name: $RUNNER_TEMP/apps/android_app. '
            '--create generates one app for each combination of the '
            'providers of the roles that take one, named after the providers '
            'other than the first of their roles, so a new provider gets an '
            'app that this leaves out. Run a command for each app of the '
            'directory with .github/scripts/each_app.sh.',
          ),
          startsWith(
            'apps.yml, job a, step "Start" refers to an app of the --create '
            r'of a matrix tool by its name: ${{ runner.temp }}/SMF '
            'apps/firebase/firebase_start_app.',
          ),
          startsWith(
            'apps.yml, job a, step "Start the second" refers to an app of the '
            r'--create of a matrix tool by its name: $RUNNER_TEMP\SMF '
            r'apps\firebase\firebase_start_app_riverpod.',
          ),
        ],
      );
    });

    test(
        'but not the directory of the apps, nor a word that only starts like '
        'the name, nor the name in another job', () {
      expect(
        problemsOf(
          r'''
jobs:
  a:
    steps:
      - name: Generate
        run: dart run packages/smf_flutter_cli/tool/matrix.dart --create "$RUNNER_TEMP/SMF apps/start" start_app
      - name: Start
        run: |
          .github/scripts/each_app.sh "$RUNNER_TEMP/SMF apps/start" \
            "$GITHUB_WORKSPACE/.github/scripts/start_app.sh" android emulator-5554 480
          echo start_apps
  b:
    steps:
      - name: Compare
        run: |
          (cd "$RUNNER_TEMP" && flutter create --org com.example --no-pub start_app)
          SMF_FLUTTER_CREATE_APP="$RUNNER_TEMP/start_app" flutter test
''',
          file: 'apps.yml',
        ),
        isEmpty,
      );
    });
  });

  test('finds a step that runs smf create itself', () {
    expect(
      problemsOf(
        workflow(r'''
      - name: Create
        run: |
          smf create my_app --no-input
          "$bin/smf" create my_app --no-input
      - name: From source
        run: dart run packages/smf_flutter_cli/bin/smf_flutter.dart create probe --explain
      - name: Global
        shell: pwsh
        run: dart pub global run smf_flutter_cli:smf_flutter create probe --explain
      - name: Others
        run: |
          flutter create --org com.example --no-pub my_app
          udid="$(xcrun simctl create 'SMF start' "$device_type" "$runtime")"
          echo no | avdmanager create avd --name smf
          dart pub global activate smf_flutter_cli
          smf --version
          smf "${arguments[@]}"
'''),
        file: 'apps.yml',
      ),
      [
        startsWith(
          'apps.yml, job a, step "Create" runs smf create itself. Generate the '
          'apps with the --create of packages/smf_flutter_cli/tool/matrix.dart',
        ),
        startsWith('apps.yml, job a, step "Create" runs smf create itself.'),
        startsWith(
          'apps.yml, job a, step "From source" runs smf create itself.',
        ),
        startsWith('apps.yml, job a, step "Global" runs smf create itself.'),
      ],
    );
  });

  test('finds a step that names the modules of an app by hand', () {
    expect(
      problemsOf(
        workflow(r'''
      - name: Build an app with every module for Android
        run: |
          dart run packages/smf_flutter_cli/bin/smf_flutter.dart create android_app \
            -m go_router,home,bottom_tabs,bloc,get_it,event_bus,firebase_crashlytics,firebase_analytics \
            -o "$RUNNER_TEMP/SMF apps" --no-input --skip-external-setup --no-dart-fix --strict
      - name: macOS
        run: |
          smf() {
            dart run packages/smf_flutter_cli/bin/smf_flutter.dart create "$@" --no-input
          }
          smf plain_app -m go_router,home,bottom_tabs,riverpod,get_it,event_bus
      - name: Probe
        run: $explain = dart run packages/smf_flutter_cli/bin/smf_flutter.dart create probe --modules=firebase_core --explain | Out-String
      - name: Attached
        run: smf create app -mgo_router,home,bloc --no-input
      - name: Others
        run: |
          echo "minutes=$((10 * $(find "$apps" -mindepth 1 -maxdepth 1 -type d | wc -l)))"
          find "$apps" -mindepth 1 -maxdepth 1 -type d
          nohup "$ANDROID_HOME/emulator/emulator" -avd smf -memory 3072 > "$RUNNER_TEMP/emulator.log" 2>&1 &
'''),
        file: 'apps.yml',
      ),
      [
        startsWith(
          'apps.yml, job a, step "Build an app with every module for '
          'Android" runs smf create itself.',
        ),
        startsWith(
          'apps.yml, job a, step "Build an app with every module for '
          'Android" names the modules of an app with -m. Generate the apps '
          'with the --create of packages/smf_flutter_cli/tool/matrix.dart,',
        ),
        startsWith('apps.yml, job a, step "macOS" runs smf create itself.'),
        startsWith('apps.yml, job a, step "macOS" names the modules'),
        startsWith('apps.yml, job a, step "Probe" runs smf create itself.'),
        startsWith('apps.yml, job a, step "Probe" names the modules'),
        startsWith('apps.yml, job a, step "Attached" runs smf create itself.'),
        startsWith('apps.yml, job a, step "Attached" names the modules'),
      ],
    );
  });

  test(
      'finds a step that refers to the package of a module, but one that '
      'runs its tests as an exception', () {
    final used = <Object>{};

    expect(
      problemsOf(
        workflow(r'''
      - name: Cache Gradle
        uses: actions/cache@v6
        with:
          key: gradle-${{ hashFiles('packages/smf_modules/*/bricks/*/__brick__/android/**') }}
      - name: Compare the brick of flutter_core with flutter create
        run: |
          cd packages/smf_modules/smf_flutter_core
          SMF_FLUTTER_CREATE_APP="$RUNNER_TEMP/my_app" dart test test/flutter_create_test.dart
      - name: Archive the app with every module
        working-directory: packages/smf_modules/smf_firebase_crashlytics
        run: dart run tool/archive.dart
      - name: Start the app with every module
        env:
          SMF_APP: packages/smf_modules/smf_firebase_crashlytics/app
        working-directory: ${{ runner.temp }}/SMF apps/firebase_start_app
        run: dart test packages\smf_modules\smf_home_flutter\test
'''),
        file: 'apps.yml',
        used: used,
      ),
      [
        equals(
          'apps.yml, job a, step "Archive the app with every module" refers '
          'to the package smf_firebase_crashlytics of a module, but runs no '
          'test of it with dart test.',
        ),
        equals(
          'apps.yml, job a, step "Start the app with every module" refers to '
          'the package smf_home_flutter of a module. Only a step that runs '
          'the tests of the module, or a tool of it that prints what the step '
          'needs to know of the module, may, as an exception of '
          'tools/workflow_apps_test.dart with its reason.',
        ),
        startsWith(
          'apps.yml, job a, step "Start the app with every module" refers to '
          'the package smf_firebase_crashlytics of a module.',
        ),
      ],
    );
    expect(used, {
      (
        'Compare the brick of flutter_core with flutter create',
        'smf_flutter_core'
      ),
    });
  });

  test(
      'passes a step that runs a tool of a module as an exception, but finds '
      'one that refers to the package for something else, or that another '
      'step runs', () {
    const install = 'Install the Firebase CLI and the FlutterFire CLI';
    const explain =
        'Run the FlutterFire CLI through dart.bat, and find it as SMF does';
    const tool =
        'packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart';
    final used = <Object>{};

    expect(
      problemsOf(
        r'''
jobs:
  linux:
    steps:
      - name: Install the Firebase CLI and the FlutterFire CLI
        run: |
          version="$(dart run packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart | jq -er .version)"
          dart pub global activate flutterfire_cli "$version"
  windows:
    steps:
      - name: Run the FlutterFire CLI through dart.bat, and find it as SMF does
        shell: pwsh
        run: |
          $flutterfire = dart run "packages\smf_modules\smf_firebase_core\tool\flutterfire_version.dart" | ConvertFrom-Json
          dart pub global activate flutterfire_cli $flutterfire.version
''',
        file: 'apps.yml',
        used: used,
      ),
      isEmpty,
    );
    expect(used, {(install, tool), (explain, tool)});

    used.clear();
    expect(
      problemsOf(
        '''
jobs:
  linux:
    steps:
      - name: Install the Firebase CLI and the FlutterFire CLI
        run: |
          dart run packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart > version.json
          cat packages/smf_modules/smf_firebase_core/lib/src/preflight/flutterfire_cli.dart
  macos:
    steps:
      - name: Install the Firebase CLI and the FlutterFire CLI
        working-directory: packages/smf_modules/smf_firebase_core
        run: dart run tool/flutterfire_version.dart
  windows:
    steps:
      - name: Run the FlutterFire CLI through dart.bat, and find it as SMF does
        run: cat packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart
      - name: Activate the FlutterFire CLI
        run: dart run packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart
  other:
    steps:
      - name: Run the FlutterFire CLI through dart.bat, and find it as SMF does
        run: dart run packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart.old
''',
        file: 'apps.yml',
        used: used,
      ),
      [
        startsWith(
          'apps.yml, job linux, step "$install" refers to the package '
          'smf_firebase_core of a module. Only a step that runs the tests of '
          'the module, or a tool of it',
        ),
        startsWith(
          'apps.yml, job macos, step "$install" refers to the package '
          'smf_firebase_core of a module.',
        ),
        startsWith(
          'apps.yml, job windows, step "$explain" refers to the package '
          'smf_firebase_core of a module.',
        ),
        startsWith(
          'apps.yml, job windows, step "Activate the FlutterFire CLI" refers '
          'to the package smf_firebase_core of a module.',
        ),
        startsWith(
          'apps.yml, job other, step "$explain" refers to the package '
          'smf_firebase_core of a module.',
        ),
      ],
    );
    expect(used, {(install, tool)});
  });

  test('finds the same in a script of .github/scripts', () {
    expect(
      scriptProblemsOf(
        r'''
#!/usr/bin/env bash
set -euo pipefail
tool=packages/smf_flutter_cli/tool/matrix.dart
dart run "$tool" --create "$1" android_app
cd "$1/android_app_riverpod"
dart run "$tool" "$1" 'every module (bloc)'
smf create "$2" -mgo_router --no-input
cd packages/smf_modules/smf_go_router
''',
        file: '.github/scripts/build.sh',
      ),
      [
        startsWith(
          '.github/scripts/build.sh refers to an app of the --create of a '
          r'matrix tool by its name: $1/android_app_riverpod.',
        ),
        startsWith(
          '.github/scripts/build.sh selects apps of a matrix tool by name: '
          'every module (bloc).',
        ),
        startsWith('.github/scripts/build.sh runs smf create itself.'),
        startsWith('.github/scripts/build.sh names the modules of an app'),
        equals(
          '.github/scripts/build.sh refers to the package smf_go_router of a '
          'module. Only a step of a workflow that runs the tests of the '
          'module, or a tool of it that prints what the step needs to know of '
          'the module, may, as an exception of tools/workflow_apps_test.dart '
          'with its reason.',
        ),
      ],
    );
    expect(
      scriptProblemsOf(
        r'''
$tool = 'packages\smf_flutter_cli\tool\matrix.dart'
dart run $tool "$env:RUNNER_TEMP\SMF apps" 'every module (bloc)'
''',
        file: '.github/scripts/windows.ps1',
        powerShell: true,
      ),
      [
        startsWith(
          '.github/scripts/windows.ps1 selects apps of a matrix tool by '
          'name: every module (bloc).',
        ),
      ],
    );
  });

  test(
      'reads the options that choose the apps of a matrix tool as no names '
      'of apps', () {
    expect(
      problemsOf(
        workflow(r'''
      - name: Choose
        run: |
          dart run packages/smf_flutter_cli/tool/matrix.dart --every-module --app "$APP" --shard "$SHARD" "$apps"
          dart run packages/smf_flutter_cli/tool/matrix.dart --combinations all --shard 1/2 "$apps"
          dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$apps" android_app
          .github/scripts/each_app.sh "$apps" flutter build apk --debug
'''),
        file: 'apps.yml',
      ),
      isEmpty,
    );
    expect(
      problemsOf(
        workflow(r'''
      - name: Choose
        run: |
          dart run packages/smf_flutter_cli/tool/matrix.dart --create --without-external-steps --app "$APP" "$apps" start_app
          cd "$apps/start_app"
          dart run packages/smf_flutter_cli/tool/matrix.dart --every-module --shard 1/2 "$apps" 'every module (bloc)'
'''),
        file: 'apps.yml',
      ),
      [
        startsWith(
          'apps.yml, job a, step "Choose" refers to an app of the --create '
          r'of a matrix tool by its name: $apps/start_app.',
        ),
        startsWith(
          'apps.yml, job a, step "Choose" selects apps of a matrix tool by '
          'name: every module (bloc).',
        ),
      ],
    );
  });

  group('the plan', () {
    test(
        'finds a step that generates or checks a whole selection of apps in '
        'one job', () {
      expect(
        planProblemsOf(
          r'''
jobs:
  linux:
    steps:
      - name: Build
        run: |
          apps="$RUNNER_TEMP/SMF apps/android"
          dart run packages/smf_flutter_cli/tool/matrix.dart --create "$apps" android_app
          .github/scripts/each_app.sh "$apps" flutter build apk --debug
      - name: Start
        run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --without-external-steps --combinations all "$RUNNER_TEMP/SMF apps/start" start_app
      - name: Every module
        run: dart run packages/smf_flutter_cli/tool/matrix.dart --every-module --combinations 3-wise "$RUNNER_TEMP/SMF apps"
      - name: Matrix
        run: dart run packages/smf_pipeline/fixture_registry/tool/matrix.dart "$RUNNER_TEMP/SMF apps"
''',
          file: 'apps.yml',
        ),
        [
          equals(
            'apps.yml, job linux, step "Build" generates every app with every '
            'module of a selection (--create without --app). A job that '
            'builds, archives or starts apps with every module takes one app '
            'of the plan with --app, and a job that checks the apps of a '
            'matrix takes a shard of it with --shard, from the matrix of the '
            'job, which the plan gives with '
            r'${{ fromJSON(needs.<plan>.outputs.<list>) }}: so no job takes '
            'longer as the apps get more, only the number of jobs grows.',
          ),
          startsWith(
            'apps.yml, job linux, step "Start" generates every app with every '
            'module of a selection (--create without --app).',
          ),
          startsWith(
            'apps.yml, job linux, step "Every module" checks every app with '
            'every module of a selection (--every-module without --app or '
            '--shard).',
          ),
          startsWith(
            'apps.yml, job linux, step "Matrix" checks every app of a matrix '
            '(without --shard).',
          ),
        ],
      );
    });

    test(
        'finds a matrix that takes an output of a job that refers to a '
        'secret, whose lines the runner hides in the outputs of the job', () {
      const matrix = r'''
  android:
    needs: [plan, firebase-key]
    if: needs.firebase-key.outputs.key == 'true'
    timeout-minutes: 25
    strategy:
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.apps) }}
    steps:
      - run: echo
''';
      const secret = r'''
      - id: key
        env:
          HAS_KEY: ${{ secrets.FIREBASE_SERVICE_ACCOUNT != '' }}
        run: echo "key=$HAS_KEY" >> "$GITHUB_OUTPUT"
''';
      const plan = r'''
jobs:
  plan:
    outputs:
      apps: ${{ steps.plan.outputs.apps }}
    steps:
      - id: plan
        run: dart run packages/smf_flutter_cli/tool/matrix.dart --plan
''';
      const key = r'''
  firebase-key:
    outputs:
      key: ${{ steps.key.outputs.key }}
    steps:
''';
      expect(planProblemsOf('$plan$secret$key$matrix', file: 'apps.yml'), [
        equals(
          'apps.yml, job android takes its matrix from '
          'needs.plan.outputs.apps, but the job plan refers to the secret '
          'FIREBASE_SERVICE_ACCOUNT. '
          'The runner hides the lines of each secret that a job refers to in '
          'the outputs of the job, and leaves out an output that has one of '
          'them, such as the { of a key in JSON, so the matrix would have no '
          'value: refer to the secret in a job of its own.',
        ),
      ]);
      // The secret in a job of its own, whose output only a condition reads.
      expect(
        planProblemsOf('$plan$key$secret$matrix', file: 'apps.yml'),
        isEmpty,
      );
    });

    test(
        'passes the jobs that take one app or a shard from the matrix of the '
        'plan, and the runs that generate nothing', () {
      expect(
        planProblemsOf(
          r'''
jobs:
  plan:
    outputs:
      apps: ${{ steps.plan.outputs.apps }}
      shards: ${{ steps.plan.outputs.shards }}
      matrix: ${{ steps.plan.outputs.matrix }}
    steps:
      - id: plan
        run: dart run packages/smf_flutter_cli/tool/matrix.dart --plan --every-combination
  android:
    needs: plan
    timeout-minutes: 25
    strategy:
      max-parallel: 2
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.apps) }}
    steps:
      - name: Build
        timeout-minutes: 20
        env:
          APP: ${{ matrix.app }}
        run: |
          apps="$RUNNER_TEMP/SMF apps/android"
          dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$apps" android_app
          .github/scripts/each_app.sh "$apps" flutter build apk --debug
          for app in "$apps"/*/; do
            dart run packages/smf_flutter_cli/tool/matrix.dart --add-app-tests "${app%/}" packages/smf_flutter_cli/app_tests/start
          done
          dart run packages/smf_flutter_cli/tool/matrix.dart --app-tests
  windows:
    needs: [plan]
    defaults:
      run:
        shell: pwsh
    strategy:
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.apps) }}
    env:
      APP: ${{ matrix.app }}
    steps:
      - name: Every module
        run: |
          dart run packages/smf_flutter_cli/tool/matrix.dart --every-module --app $env:APP "$env:RUNNER_TEMP\SMF apps"
          dart run packages/smf_flutter_cli/tool/matrix.dart --every-module --app "${{ matrix.app }}" "$env:RUNNER_TEMP\SMF apps"
          dart run packages/smf_flutter_cli/tool/matrix.dart --create "$env:RUNNER_TEMP\probe" probe --explain
          foreach ($app in @($env:ENTRIES | ConvertFrom-Json)) {
            dart run packages/smf_flutter_cli/tool/matrix.dart --create --app $app "$env:RUNNER_TEMP\probe" probe --explain
          }
  shards:
    needs: plan
    strategy:
      matrix:
        include: ${{ fromJSON(needs.plan.outputs.shards) }}
    steps:
      - name: Matrix
        env:
          SHARD: ${{ matrix.shard }}
        run: |
          dart run packages/smf_pipeline/fixture_registry/tool/matrix.dart --combinations "$COMBINATIONS" --shard "$SHARD" "$RUNNER_TEMP/SMF apps"
          dart run packages/smf_flutter_cli/tool/matrix.dart --every-module --shard "${{ matrix.shard }}" "$RUNNER_TEMP/SMF apps"
  whole:
    needs: plan
    strategy:
      matrix: ${{ fromJSON(needs.plan.outputs.matrix) }}
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --shard "${{ matrix.shard }}" "$RUNNER_TEMP/SMF apps"
  caller:
    uses: ./.github/workflows/apps.yml
''',
          file: 'apps.yml',
        ),
        isEmpty,
      );
    });

    test(
        'passes a tool that checks one app of its own, in a job without a '
        'plan: it takes no selection of the apps with every module, so it '
        'needs no shard', () {
      expect(
        planProblemsOf(
          r'''
jobs:
  several:
    timeout-minutes: 15
    steps:
      - name: The app with several providers
        run: dart run packages/smf_pipeline/fixture_registry/tool/several_providers_matrix.dart "$RUNNER_TEMP/SMF apps/several providers"
''',
          file: 'apps.yml',
        ),
        isEmpty,
      );
    });

    test(
        'finds an app or a shard that does not come from the matrix of the '
        'plan, and a matrix of an output that the job does not need or that '
        'is not there', () {
      expect(
        planProblemsOf(
          r'''
jobs:
  plan:
    outputs:
      apps: ${{ steps.plan.outputs.apps }}
    steps:
      - id: plan
        run: dart run packages/smf_flutter_cli/tool/matrix.dart --plan
  literal:
    steps:
      - name: Named
        run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app 'every module (bloc)' "$apps" android_app
  listed:
    strategy:
      matrix:
        shard: [1/2, 2/2]
    steps:
      - name: Listed
        run: dart run packages/smf_flutter_cli/tool/matrix.dart --shard "${{ matrix.shard }}" "$apps"
  unplanned:
    strategy:
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.apps) }}
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "${{ matrix.app }}" "$apps" android_app
  missing:
    needs: plan
    strategy:
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.devices) }}
    steps:
      - name: Other key
        env:
          APP: ${{ matrix.other }}
        run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$apps" android_app
''',
          file: 'apps.yml',
        ),
        [
          equals(
            'apps.yml, job literal, step "Named" takes --app every module '
            '(bloc), which is no value of a matrix of its job that the plan '
            r'gives: take it from ${{ matrix.<key> }} of a matrix of '
            r'${{ fromJSON(needs.<plan>.outputs.<list>) }}, directly or '
            'through a variable of the environment of the step.',
          ),
          startsWith(
            'apps.yml, job listed, step "Listed" takes --shard '
            r'${{ matrix.shard }}, which is no value of a matrix of its job '
            'that the plan gives:',
          ),
          equals(
            'apps.yml, job unplanned takes its matrix from '
            'needs.plan.outputs.apps, but plan is not among the needs of the '
            'job.',
          ),
          equals(
            'apps.yml, job missing takes its matrix from '
            'needs.plan.outputs.devices, but the job plan has no output '
            'devices.',
          ),
          startsWith(
            r'apps.yml, job missing, step "Other key" takes --app $APP, which '
            'is no value of a matrix of its job that the plan gives:',
          ),
        ],
      );
    });

    test('finds a job or a step that computes its timeout-minutes', () {
      expect(
        planProblemsOf(
          r'''
jobs:
  a:
    timeout-minutes: ${{ inputs.minutes }}
    steps:
      - name: Start
        timeout-minutes: ${{ fromJSON(steps.start_apps.outputs.minutes || '10') }}
        run: echo start
      - name: Fixed
        timeout-minutes: 10
        run: echo fixed
  b:
    timeout-minutes: 25
    steps:
      - run: echo b
''',
          file: 'apps.yml',
        ),
        [
          equals(
            r'apps.yml, job a computes its timeout-minutes, ${{ '
            'inputs.minutes }}. A job takes a fixed number of apps of the '
            'plan, one or a shard, so its time does not grow with the number '
            'of apps: give it a fixed number of minutes.',
          ),
          startsWith(
            'apps.yml, job a, step "Start" computes its timeout-minutes, '
            r"${{ fromJSON(steps.start_apps.outputs.minutes || '10') }}.",
          ),
        ],
      );
    });

    test(
        'finds a script of .github/scripts that generates or checks a whole '
        'selection of apps', () {
      expect(
        scriptPlanProblemsOf(
          r'''
#!/usr/bin/env bash
tool=packages/smf_flutter_cli/tool/matrix.dart
dart run "$tool" --create "$1" android_app
dart run "$tool" --create --app "$2" "$1" android_app
dart run "$tool" --every-module --shard "$3" "$1"
''',
          file: '.github/scripts/build.sh',
        ),
        [
          startsWith(
            '.github/scripts/build.sh generates every app with every module '
            'of a selection (--create without --app).',
          ),
        ],
      );
    });
  });

  group('the caches of the native builds', () {
    /// The steps of a job that builds the apps in `$RUNNER_TEMP/apps` for
    /// [platform] with the cache of its package manager as the workflows of
    /// the repository do, indented as the steps of a job: they find what the
    /// apps build with, restore the cache of that unless they download
    /// nothing, measure the cache, build the apps, and save the cache when
    /// the build added more than NATIVE_CACHE_SAVE_ABOVE_MB to it.
    String cachedBuild(String platform) {
      final (id, path) = platform == 'android'
          ? ('gradle', '~/.gradle/caches/modules-2')
          : ('swiftpm', '~/Library/Caches/org.swift.swiftpm');
      final file = 'build/native_build/$platform.txt';
      return '''
      - run: dart tools/native_build.dart $platform "\$RUNNER_TEMP/apps" $file
      - id: $id
        if: hashFiles('$file') != ''
        uses: actions/cache/restore@v6
        with:
          path: $path
          key: $id-\${{ hashFiles('$file') }}
      - id: ${id}_restored
        if: steps.$id.outcome == 'success' && steps.$id.outputs.cache-hit != 'true'
        run: echo "megabytes=\$(du -sm $path | cut -f 1)" >> "\$GITHUB_OUTPUT"
      - run: .github/scripts/each_app.sh "\$RUNNER_TEMP/apps" flutter build
      - id: ${id}_added
        if: steps.${id}_restored.outcome == 'success'
        env:
          RESTORED: \${{ steps.${id}_restored.outputs.megabytes }}
        run: |
          added=\$((\$(du -sm $path | cut -f 1) - RESTORED))
          if [ "\$added" -gt "\$NATIVE_CACHE_SAVE_ABOVE_MB" ]; then echo save=true >> "\$GITHUB_OUTPUT"; fi
      - if: steps.${id}_added.outputs.save == 'true'
        uses: actions/cache/save@v6
        with:
          path: $path
          key: \${{ steps.$id.outputs.cache-primary-key }}
''';
    }

    test(
        'finds a job on Linux or macOS that generates an app to build and '
        'restores no cache of the package manager of its platform', () {
      final workflow = r'''
env:
  NATIVE_CACHE_SAVE_ABOVE_MB: 100
jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
''' +
          cachedBuild('android') +
          r'''
  ios:
    runs-on: macos-26
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" ios_app
  ios-cached:
    runs-on: macos-26
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" ios_app
''' +
          cachedBuild('ios') +
          r'''
  macos:
    runs-on: macos-26
    steps:
      - run: dart test
  windows:
    runs-on: windows-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" windows_app
''';
      expect(nativeCacheProblemsOf(workflow, file: 'apps.yml'), [
        equals(
          'apps.yml, job ios generates an app with --create to build it for '
          'its platform, but restores no cache of Swift Package Manager '
          '(org.swift.swiftpm): each job would download the same packages '
          'again.',
        ),
      ]);
    });

    test(
        'finds a job that saves the cache only for the first job of its '
        'matrix, under a key that does not depend on its app, whatever its '
        'build added, and a job that only restores it', () {
      // The caches as the workflow had them: the first job of the matrix of
      // the apps saved the cache of its platform, by the Android files of
      // the bricks or by the week alone, and every other job, of that
      // matrix or of another, restored it.
      const workflow = r'''
jobs:
  android:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.apps) }}
    steps:
      - name: Find the week of the cache of Gradle
        id: gradle_week
        run: echo "week=$(date -u +%G-%V)" >> "$GITHUB_OUTPUT"
      - name: Cache Gradle
        if: inputs.save_gradle_cache && strategy.job-index == 0
        uses: actions/cache@v6
        with: &gradle_cache
          path: |
            ~/.gradle/caches/modules-2
            ~/.gradle/wrapper/dists
          key: ${{ runner.os }}-gradle-${{ hashFiles('packages/smf_modules/*/bricks/*/__brick__/android/**') }}-${{ steps.gradle_week.outputs.week }}
          restore-keys: |
            ${{ runner.os }}-gradle-
      - name: Restore the cache of Gradle
        if: ${{ !(inputs.save_gradle_cache && strategy.job-index == 0) }}
        uses: actions/cache/restore@v6
        with: *gradle_cache
      - name: Build the app with every module for Android
        run: |
          apps="$RUNNER_TEMP/SMF apps/android"
          dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$apps" android_app
          .github/scripts/each_app.sh "$apps" flutter build apk --debug
  android-start:
    runs-on: ubuntu-latest
    steps:
      - name: Restore the cache of Gradle
        uses: actions/cache/restore@v6
        with: *gradle_cache
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --without-external-steps --app "$APP" "$RUNNER_TEMP/SMF apps/start" start_app
  ios:
    runs-on: macos-26
    steps:
      - name: Cache Swift packages
        if: inputs.save_swiftpm_cache && strategy.job-index == 0
        uses: actions/cache@v6
        with: &swiftpm_cache
          path: ~/Library/Caches/org.swift.swiftpm
          key: ${{ runner.os }}-swiftpm-${{ steps.swiftpm_week.outputs.week }}
      - name: Restore the cache of Swift packages
        if: ${{ !(inputs.save_swiftpm_cache && strategy.job-index == 0) }}
        uses: actions/cache/restore@v6
        with: *swiftpm_cache
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/SMF apps/ios" ios_app
''';
      expect(nativeCacheProblemsOf(workflow, file: 'apps.yml'), [
        equals(
          'apps.yml, job android, step "Cache Gradle" saves the cache of '
          'Gradle only in some jobs of its matrix (if: '
          'inputs.save_gradle_cache && strategy.job-index == 0), so what the '
          'apps of the other jobs need beyond the cache that they restore is '
          'downloaded again in every run: let every job save the cache of its '
          'app, under the key of the app, when the workflow lets it.',
        ),
        equals(
          'apps.yml, job android, step "Cache Gradle" saves the cache of '
          r'Gradle under the key ${{ runner.os }}-gradle-${{ '
          "hashFiles('packages/smf_modules/*/bricks/*/__brick__/android/**') "
          r'}}-${{ steps.gradle_week.outputs.week }}, which does not depend '
          'on the app that the job builds. Take the key from the hash of the '
          'file that `dart tools/native_build.dart android <directory of '
          'apps> <file>` writes once the apps of the job are generated, so '
          'that the jobs whose apps build with the same share one cache, and '
          'a job whose app builds with another plugin or another native '
          'project saves a cache of its own.',
        ),
        equals(
          'apps.yml, job android, step "Cache Gradle" saves the cache of '
          'Gradle whenever the job did not find the key of its app, rather '
          'than only when its build added more than '
          r'$NATIVE_CACHE_SAVE_ABOVE_MB MB to the cache that the job '
          'restored. A cache is saved whole, '
          'over 1 GB for Gradle, so a job whose app needs a few MB more than '
          'the cache of another app would store a near copy of that cache in '
          'the 10 GB of caches of the repository. Measure the cache after the '
          'step that restores it, and save it only when a step after the '
          'build finds that the build added more than that.',
        ),
        equals(
          'apps.yml, job android-start restores the cache of Gradle '
          '(.gradle/) but never saves it, so what its app needs beyond the '
          'cache that it restores, such as the native side of a plugin that '
          'the apps of the jobs that save the cache do not have, is '
          'downloaded again in every run: save the cache of its app, under '
          'the key of the app, when the workflow lets it.',
        ),
        startsWith(
          'apps.yml, job ios, step "Cache Swift packages" saves the cache of '
          'Swift Package Manager only in some jobs of its matrix (if: '
          'inputs.save_swiftpm_cache && strategy.job-index == 0),',
        ),
        startsWith(
          'apps.yml, job ios, step "Cache Swift packages" saves the cache of '
          r'Swift Package Manager under the key ${{ runner.os }}-swiftpm-${{ '
          'steps.swiftpm_week.outputs.week }}, which does not depend on the '
          'app that the job builds. Take the key from the hash of the file '
          'that `dart tools/native_build.dart ios <directory of apps> <file>` '
          'writes',
        ),
        startsWith(
          'apps.yml, job ios, step "Cache Swift packages" saves the cache of '
          'Swift Package Manager whenever the job did not find the key of its '
          'app,',
        ),
      ]);
    });

    test(
        'finds a step that saves the cache for the jobs of some values of '
        'the matrix, or under the key of a file that does not describe the '
        'app of the job for its platform when the cache is saved', () {
      const workflow = r'''
env:
  NATIVE_CACHE_SAVE_ABOVE_MB: 100
jobs:
  registry:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
      - run: dart tools/native_build.dart android "$RUNNER_TEMP/apps" build/native_build/android.txt
      - &restore
        id: gradle
        uses: actions/cache/restore@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: gradle-${{ hashFiles('build/native_build/android.txt') }}
      - &restored
        id: gradle_restored
        run: echo "megabytes=$(du -sm ~/.gradle/caches/modules-2 | cut -f 1)" >> "$GITHUB_OUTPUT"
      - &build
        run: .github/scripts/each_app.sh "$RUNNER_TEMP/apps" flutter build apk --debug
      - &added
        id: gradle_added
        env:
          RESTORED: ${{ steps.gradle_restored.outputs.megabytes }}
        run: |
          added=$(($(du -sm ~/.gradle/caches/modules-2 | cut -f 1) - RESTORED))
          if [ "$added" -gt "$NATIVE_CACHE_SAVE_ABOVE_MB" ]; then echo save=true >> "$GITHUB_OUTPUT"; fi
      - name: Save the cache of Gradle
        if: matrix.registry == 'real' && steps.gradle_added.outputs.save == 'true'
        uses: actions/cache/save@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: ${{ steps.gradle.outputs.cache-primary-key }}
  early:
    runs-on: ubuntu-latest
    steps:
      - run: dart tools/native_build.dart android "$RUNNER_TEMP/apps" build/native_build/android.txt
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
      - *restore
      - *restored
      - *build
      - *added
      - &save
        name: Save the cache of Gradle
        if: steps.gradle_added.outputs.save == 'true'
        uses: actions/cache/save@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: ${{ steps.gradle.outputs.cache-primary-key }}
  late:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
      - *restore
      - run: dart tools/native_build.dart android "$RUNNER_TEMP/apps" build/native_build/android.txt
      - *restored
      - *build
      - *added
      - *save
  other-platform:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
      - run: dart tools/native_build.dart ios "$RUNNER_TEMP/apps" build/native_build/android.txt
      - *restore
      - *restored
      - *build
      - *added
      - *save
  other-file:
    runs-on: macos-26
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" ios_app
      - run: dart tools/native_build.dart ios "$RUNNER_TEMP/apps" build/native_build/ios.txt
      - id: swiftpm
        uses: actions/cache/restore@v6
        with:
          path: ~/Library/Caches/org.swift.swiftpm
          key: swiftpm-${{ hashFiles('ios/Podfile.lock') }}
      - id: swiftpm_restored
        run: echo "megabytes=$(du -sm ~/Library/Caches/org.swift.swiftpm | cut -f 1)" >> "$GITHUB_OUTPUT"
      - run: .github/scripts/each_app.sh "$RUNNER_TEMP/apps" flutter build ios --simulator
      - id: swiftpm_added
        env:
          RESTORED: ${{ steps.swiftpm_restored.outputs.megabytes }}
        run: |
          added=$(($(du -sm ~/Library/Caches/org.swift.swiftpm | cut -f 1) - RESTORED))
          if [ "$added" -gt "$NATIVE_CACHE_SAVE_ABOVE_MB" ]; then echo save=true >> "$GITHUB_OUTPUT"; fi
      - name: Save the cache of Swift packages
        if: steps.swiftpm_added.outputs.save == 'true'
        uses: actions/cache/save@v6
        with:
          path: ~/Library/Caches/org.swift.swiftpm
          key: ${{ steps.swiftpm.outputs.cache-primary-key }}
''';
      expect(nativeCacheProblemsOf(workflow, file: 'apps.yml'), [
        startsWith(
          'apps.yml, job registry, step "Save the cache of Gradle" saves the '
          'cache of Gradle only in some jobs of its matrix (if: '
          "matrix.registry == 'real' && steps.gradle_added.outputs.save == "
          "'true'),",
        ),
        startsWith(
          'apps.yml, job early, step "Save the cache of Gradle" saves the '
          r'cache of Gradle under the key gradle-${{ '
          "hashFiles('build/native_build/android.txt') }}, which does not "
          'depend on the app that the job builds.',
        ),
        startsWith(
          'apps.yml, job late, step "Save the cache of Gradle" saves the cache '
          r'of Gradle under the key gradle-${{ '
          "hashFiles('build/native_build/android.txt') }}, which does not "
          'depend on the app that the job builds.',
        ),
        startsWith(
          'apps.yml, job other-platform, step "Save the cache of Gradle" '
          'saves the cache of Gradle under the key',
        ),
        startsWith(
          'apps.yml, job other-file, step "Save the cache of Swift packages" '
          'saves the cache of Swift Package Manager under the key '
          r"swiftpm-${{ hashFiles('ios/Podfile.lock') }}, which does not "
          'depend on the app that the job builds.',
        ),
      ]);
    });

    test(
        'finds a step that saves the cache whatever the build added to the '
        'cache that the job restored, and a workflow without the threshold',
        () {
      const workflow = r'''
env:
  NATIVE_CACHE_SAVE_ABOVE_MB: 100
jobs:
  every-miss:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
      - run: dart tools/native_build.dart android "$RUNNER_TEMP/apps" build/native_build/android.txt
      - &restore
        id: gradle
        uses: actions/cache/restore@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: gradle-${{ hashFiles('build/native_build/android.txt') }}
      - &build
        run: .github/scripts/each_app.sh "$RUNNER_TEMP/apps" flutter build apk --debug
      - name: Save the cache of Gradle
        if: inputs.save_gradle_cache && steps.gradle.outputs.cache-hit != 'true'
        uses: actions/cache/save@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: ${{ steps.gradle.outputs.cache-primary-key }}
  at-the-end:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
      - run: dart tools/native_build.dart android "$RUNNER_TEMP/apps" build/native_build/android.txt
      - name: Cache Gradle
        uses: actions/cache@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: gradle-${{ hashFiles('build/native_build/android.txt') }}
      - *build
  whole-cache:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
      - run: dart tools/native_build.dart android "$RUNNER_TEMP/apps" build/native_build/android.txt
      - *restore
      - *build
      - id: gradle_size
        run: |
          size=$(du -sm ~/.gradle/caches/modules-2 | cut -f 1)
          if [ "$size" -gt "$NATIVE_CACHE_SAVE_ABOVE_MB" ]; then echo save=true >> "$GITHUB_OUTPUT"; fi
      - name: Save the cache of Gradle
        if: steps.gradle_size.outputs.save == 'true'
        uses: actions/cache/save@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: ${{ steps.gradle.outputs.cache-primary-key }}
  before-the-restore:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
      - run: dart tools/native_build.dart android "$RUNNER_TEMP/apps" build/native_build/android.txt
      - id: gradle_restored
        run: echo "megabytes=$(du -sm ~/.gradle/caches/modules-2 | cut -f 1)" >> "$GITHUB_OUTPUT"
      - *restore
      - *build
      - id: gradle_added
        env:
          RESTORED: ${{ steps.gradle_restored.outputs.megabytes }}
        run: |
          added=$(($(du -sm ~/.gradle/caches/modules-2 | cut -f 1) - RESTORED))
          if [ "$added" -gt "$NATIVE_CACHE_SAVE_ABOVE_MB" ]; then echo save=true >> "$GITHUB_OUTPUT"; fi
      - name: Save the cache of Gradle
        if: steps.gradle_added.outputs.save == 'true'
        uses: actions/cache/save@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: ${{ steps.gradle.outputs.cache-primary-key }}
''';
      expect(nativeCacheProblemsOf(workflow, file: 'apps.yml'), [
        startsWith(
          'apps.yml, job every-miss, step "Save the cache of Gradle" saves the '
          'cache of Gradle whenever the job did not find the key of its app,',
        ),
        startsWith(
          'apps.yml, job at-the-end, step "Cache Gradle" saves the cache of '
          'Gradle whenever the job did not find the key of its app,',
        ),
        startsWith(
          'apps.yml, job whole-cache, step "Save the cache of Gradle" saves '
          'the cache of Gradle whenever the job did not find the key of its '
          'app,',
        ),
        startsWith(
          'apps.yml, job before-the-restore, step "Save the cache of Gradle" '
          'saves the cache of Gradle whenever the job did not find the key of '
          'its app,',
        ),
      ]);

      expect(
        nativeCacheProblemsOf(
          'jobs:\n'
          '  android:\n'
          '    runs-on: ubuntu-latest\n'
          '    steps:\n${cachedBuild('android')}',
          file: 'apps.yml',
        ),
        [
          equals(
            'apps.yml compares what the builds add to the caches of their '
            'native builds with NATIVE_CACHE_SAVE_ABOVE_MB, but does not set '
            'it in its env, the one place that gives it with its reason.',
          ),
        ],
      );
    });

    test(
        'passes the jobs that key the cache by the apps they build and save '
        'it when their build added more than the threshold to it, whatever '
        'job of their matrix they are', () {
      const workflow = r'''
env:
  NATIVE_CACHE_SAVE_ABOVE_MB: 100
jobs:
  android:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.apps) }}
    steps:
      - name: Find the week of the cache of Gradle
        id: gradle_week
        run: echo "week=$(date -u +%G-%V)" >> "$GITHUB_OUTPUT"
      - name: Generate the app with every module
        run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/SMF apps/android" android_app
      - name: Find what the app builds with for Android
        run: dart tools/native_build.dart android "$RUNNER_TEMP/SMF apps/android" build/native_build/android.txt
      - &restore_gradle
        name: Restore the cache of Gradle
        id: gradle
        if: hashFiles('build/native_build/android.txt') != ''
        uses: actions/cache/restore@v6
        with:
          path: &gradle_paths |
            ~/.gradle/caches/modules-2
            ~/.gradle/wrapper/dists
          key: ${{ runner.os }}-gradle-${{ hashFiles('build/native_build/android.txt') }}-${{ steps.gradle_week.outputs.week }}
          restore-keys: |
            ${{ runner.os }}-gradle-${{ hashFiles('build/native_build/android.txt') }}-
            ${{ runner.os }}-gradle-
      - &gradle_restored
        name: Measure the cache of Gradle that the job restored
        id: gradle_restored
        if: inputs.save_gradle_cache && steps.gradle.outcome == 'success' && steps.gradle.outputs.cache-hit != 'true'
        run: |
          mkdir -p ~/.gradle/caches/modules-2 ~/.gradle/wrapper/dists
          echo "megabytes=$(du -smc ~/.gradle/caches/modules-2 ~/.gradle/wrapper/dists | tail -n 1 | cut -f 1)" >> "$GITHUB_OUTPUT"
      - name: Build the app with every module for Android
        run: .github/scripts/each_app.sh "$RUNNER_TEMP/SMF apps/android" flutter build apk --debug
      - &gradle_added
        name: Measure what the build added to the cache of Gradle
        id: gradle_added
        if: steps.gradle_restored.outcome == 'success'
        env:
          RESTORED: ${{ steps.gradle_restored.outputs.megabytes }}
        run: |
          size="$(du -smc ~/.gradle/caches/modules-2 ~/.gradle/wrapper/dists | tail -n 1 | cut -f 1)"
          if [ $((size - RESTORED)) -gt "$NATIVE_CACHE_SAVE_ABOVE_MB" ]; then
            echo "save=true" >> "$GITHUB_OUTPUT"
          fi
      - &save_gradle
        name: Save the cache of Gradle
        if: steps.gradle_added.outputs.save == 'true'
        uses: actions/cache/save@v6
        with:
          path: *gradle_paths
          key: ${{ steps.gradle.outputs.cache-primary-key }}
  published:
    runs-on: ubuntu-latest
    steps:
      - name: Generate the apps with the CLI from pub.dev
        run: smf "${arguments[@]}"
      - name: Find what the apps build with for Android
        run: dart tools/native_build.dart android "$RUNNER_TEMP/SMF apps from pub.dev" build/native_build/android.txt
      - *restore_gradle
      - *gradle_restored
      - run: .github/scripts/each_app.sh "$RUNNER_TEMP/SMF apps from pub.dev" flutter build apk --debug
      - *gradle_added
      - *save_gradle
  ios:
    runs-on: macos-26
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" ios_app
      - run: |
          dart tools/native_build.dart ios "$RUNNER_TEMP/apps" \
            build/native_build/ios.txt
      - name: Restore the cache of Swift packages
        id: swiftpm
        if: hashFiles("build/native_build/ios.txt") != ''
        uses: actions/cache/restore@v6
        with:
          path: ~/Library/Caches/org.swift.swiftpm
          key: ${{ runner.os }}-swiftpm-${{ hashFiles("build/native_build/ios.txt") }}
      - name: Measure the cache of Swift packages that the job restored
        id: swiftpm_restored
        if: inputs.save_swiftpm_cache && steps.swiftpm.outcome == 'success' && steps.swiftpm.outputs.cache-hit != 'true'
        run: echo "megabytes=$(du -sm ~/Library/Caches/org.swift.swiftpm | cut -f 1)" >> "$GITHUB_OUTPUT"
      - run: .github/scripts/each_app.sh "$RUNNER_TEMP/apps" flutter build ios --simulator --no-codesign
      - name: Measure what the build added to the cache of Swift packages
        id: swiftpm_added
        if: steps.swiftpm_restored.outcome == 'success'
        run: |
          size="$(du -sm ~/Library/Caches/org.swift.swiftpm | cut -f 1)"
          restored=${{ steps.swiftpm_restored.outputs.megabytes }}
          if [ $((size - restored)) -gt "${NATIVE_CACHE_SAVE_ABOVE_MB}" ]; then
            echo "save=true" >> "$GITHUB_OUTPUT"
          fi
      - name: Save the cache of Swift packages
        if: steps.swiftpm_added.outputs.save == 'true'
        uses: actions/cache/save@v6
        with:
          path: ~/Library/Caches/org.swift.swiftpm
          key: ${{ steps.swiftpm.outputs.cache-primary-key }}
  shards:
    runs-on: ubuntu-latest
    steps:
      - name: Cache pub packages
        if: inputs.pub_cache && startsWith(matrix.shard, '1/')
        uses: actions/cache@v6
        with:
          path: ~/.pub-cache
          key: pub-${{ hashFiles('**/pubspec.yaml') }}
  windows:
    runs-on: windows-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" windows_app
''';
      expect(nativeCacheProblemsOf(workflow, file: 'apps.yml'), isEmpty);
    });

    test(
        'finds a reusable workflow that saves the caches by default, and a '
        'workflow that lets it save them in other runs than those on main', () {
      String reusable({required bool saves}) => '''
on:
  workflow_call:
    inputs:
      save_gradle_cache:
        type: boolean
        default: $saves
      save_swiftpm_cache:
        type: boolean
        default: false
jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - run: echo
''';
      const build = r'''
jobs:
  apps:
    uses: ./.github/workflows/apps.yml
    with:
      save_gradle_cache: true
      save_swiftpm_cache: ${{ github.event_name == 'push' }}
''';
      const nightly = r'''
jobs:
  versions:
    runs-on: ubuntu-latest
    steps:
      - run: echo
  apps:
    uses: ./.github/workflows/apps.yml
    with:
      save_gradle_cache: ${{ matrix.flutter == needs.versions.outputs.latest }}
      save_swiftpm_cache: false
''';
      expect(
        nativeCacheSaveProblemsOf({
          'apps.yml': reusable(saves: true),
          'build.yml': build,
          'nightly.yml': nightly,
        }),
        [
          equals(
            'apps.yml lets its jobs save the caches of the native builds by '
            'default (save_gradle_cache: true), so a workflow that calls it '
            'without the input saves them in any run, such as that of a pull '
            'request: make it false by default, and let the workflows that '
            'call it pass it for the runs on main.',
          ),
          equals(
            'build.yml, job apps calls apps.yml with save_gradle_cache: true, '
            'which lets it save the caches of the native builds in other runs '
            'than those on main. A run of a pull request, or a run by hand on '
            'another branch, saves them for its own ref, where only its own '
            'later runs find them, so they only duplicate those of main in '
            r'the 10 GB of caches of the repository: keep the input to ${{ '
            "github.ref == 'refs/heads/main' }}, with any other condition of "
            'the workflow.',
          ),
          startsWith(
            'build.yml, job apps calls apps.yml with save_swiftpm_cache: '
            r"${{ github.event_name == 'push' }}, which lets it save",
          ),
          startsWith(
            'nightly.yml, job apps calls apps.yml with save_gradle_cache: '
            r'${{ matrix.flutter == needs.versions.outputs.latest }}, which '
            'lets it save',
          ),
        ],
      );

      expect(
        nativeCacheSaveProblemsOf({
          'apps.yml': reusable(saves: false),
          'build.yml': r'''
jobs:
  apps:
    uses: ./.github/workflows/apps.yml
    with:
      save_gradle_cache: ${{ github.ref == 'refs/heads/main' }}
      save_swiftpm_cache: ${{ github.ref == 'refs/heads/main' }}
  other:
    uses: ./.github/workflows/other.yml
    with:
      save_gradle_cache: true
''',
          'nightly.yml': r'''
jobs:
  apps:
    uses: ./.github/workflows/apps.yml
    with:
      save_gradle_cache: ${{ matrix.flutter == needs.versions.outputs.latest && github.ref == 'refs/heads/main' }}
''',
          'other.yml': 'jobs:\n  a:\n    steps:\n      - run: echo\n',
        }),
        isEmpty,
      );
    });
  });

  test(
      'the workflows and the scripts of the repository choose their apps by '
      'role and take them from the plan, and each exception applies to one '
      'of their steps', () {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    expect(top.exitCode, 0, reason: '${top.stderr}');
    final root = '${top.stdout}'.trim();
    final workflows = [
      for (final entity in Directory('$root/.github/workflows').listSync())
        if (entity is File && RegExp(r'\.ya?ml$').hasMatch(entity.path)) entity,
    ];
    final scripts = [
      for (final entity in Directory('$root/.github/scripts').listSync())
        if (entity is File && RegExp(r'\.(sh|ps1)$').hasMatch(entity.path))
          entity,
    ];
    expect(workflows, isNotEmpty);
    expect(scripts, isNotEmpty);
    final used = <Object>{};

    for (final file in workflows) {
      final name = file.uri.pathSegments.last;
      expect(
        [
          ...problemsOf(file.readAsStringSync(), file: name, used: used),
          ...planProblemsOf(file.readAsStringSync(), file: name),
          ...nativeCacheProblemsOf(file.readAsStringSync(), file: name),
        ],
        isEmpty,
        reason: name,
      );
    }
    expect(
      nativeCacheSaveProblemsOf({
        for (final file in workflows)
          file.uri.pathSegments.last: file.readAsStringSync(),
      }),
      isEmpty,
    );
    for (final file in scripts) {
      final name = '.github/scripts/${file.uri.pathSegments.last}';
      final powerShell = name.endsWith('.ps1');
      expect(
        [
          ...scriptProblemsOf(
            file.readAsStringSync(),
            file: name,
            powerShell: powerShell,
          ),
          ...scriptPlanProblemsOf(
            file.readAsStringSync(),
            file: name,
            powerShell: powerShell,
          ),
        ],
        isEmpty,
        reason: name,
      );
    }
    expect(
      {...modulePaths.keys, ...moduleTools.keys}.difference(used),
      isEmpty,
      reason: 'An exception that applies to no step is left over: remove it.',
    );
  });
}
