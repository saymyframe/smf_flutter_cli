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
//   that module.
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
  ('Archive the app with every module', 'smf_firebase_core'):
      'The test of firebase_core that archives the app of the job with the '
          'build phase for Crashlytics fixed by the command of its README.',
  ('Install the Firebase CLI with the script of SMF', 'smf_firebase_core'):
      'The test of firebase_core that runs its install script of the '
          'Firebase CLI on Windows for real.',
};

/// The problems of the [workflow], the text of the workflow [file] of
/// GitHub Actions: the steps that select an app of a matrix tool by its
/// name, that refer by its name to an app that the --create of a matrix
/// tool generates in their job, that run smf create themselves or name the
/// modules of an app with -m, and that refer to the package of a module,
/// other than the exceptions of [modulePaths]. The exceptions that apply to
/// a step go into [used].
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
      problems.addAll(script.problems(created));
      for (final package in _modulePackages(step)) {
        final exception = (_nameOf(step), package);
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
/// which only [who] the tests of the module may.
String _modulePackage(String where, String package, String who) =>
    '$where refers to the package $package of a module. $who the tests of '
    'the module may, as an exception of tools/workflow_apps_test.dart with '
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
/// right in packages/smf_modules, but not a pattern for any of them.
Set<String> _modulePackages(YamlMap step) => {
      for (final text in [
        step['run'],
        step['working-directory'],
        if (step['env'] case final YamlMap env) ...env.values,
        if (step['with'] case final YamlMap inputs) ...inputs.values,
      ])
        ..._packagesIn('${text ?? ''}'),
    };

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
        working-directory: packages/smf_modules/smf_firebase_core
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
          'to the package smf_firebase_core of a module, but runs no test of '
          'it with dart test.',
        ),
        equals(
          'apps.yml, job a, step "Start the app with every module" refers to '
          'the package smf_home_flutter of a module. Only a step that runs '
          'the tests of the module may, as an exception of '
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
          'module may, as an exception of tools/workflow_apps_test.dart with '
          'its reason.',
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
        ],
        isEmpty,
        reason: name,
      );
    }
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
      {...modulePaths.keys}.difference(used),
      isEmpty,
      reason: 'An exception that applies to no step is left over: remove it.',
    );
  });
}
