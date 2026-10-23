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

import 'workspace.dart';

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
  (
    'Enable the sign-in methods of the app with every module in Firebase',
    'smf_firebase_auth',
  ): 'The test of firebase_auth that asks the Firebase project of the app '
      'whether Email/Password is enabled there, and in one job of the '
      'workflow Build enables the sign-in methods first with the script of '
      'the app, as its README says.',
  (
    'Check the sign-in methods of the app with every module in Firebase',
    'smf_firebase_auth',
  ): 'The test of firebase_auth that asks the Firebase project of the app '
      'whether Email/Password is enabled there, before CI starts the app.',
  (
    'Start the app with every module on the Android emulator, and send it a '
        'push message',
    'smf_firebase_messaging',
  ): 'The test of firebase_messaging that answers the request of the probe '
      'of the module in the start check, through start_app.sh: it sends a '
      'push message to the address of the device with the key of the '
      'service account, and the app tells the script whether it came.',
  (
    'Start the app without external services on the Android emulator, and '
        'grant it premium access in RevenueCat',
    'smf_revenuecat',
  ): 'The test of revenuecat that answers the request of the probe of the '
      'module in the start check, through start_app.sh: it grants premium '
      'access to the user of the app in the RevenueCat project of CI with its '
      'secret key, and the app tells the script whether the access reached '
      'it.',
  (
    'Start the app without external services on the iOS simulator, and '
        'grant it premium access in RevenueCat',
    'smf_revenuecat',
  ): 'The test of revenuecat that answers the request of the probe of the '
      'module in the start check, through start_app.sh, as on Android.',
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

/// The answers that the steps of [workflow], the text of the workflow
/// [file] of GitHub Actions, give .github/scripts/start_app.sh, each with
/// where it is: the name of each argument `<name>=<command>` after the
/// script in a command that runs it, directly or through a variable of the
/// step, of its job or of the workflow, a variable that the step assigns,
/// or the items of an array of bash that it assigns.
List<(String, String)> startAnswersOf(String workflow, {required String file}) {
  final root = loadYaml(workflow) as YamlMap;
  return [
    for (final MapEntry(key: job, :value) in (root['jobs'] as YamlMap).entries)
      for (final step in (value as YamlMap)['steps'] as YamlList? ?? YamlList())
        for (final name in _Script(
          '$file, job $job, step "${_nameOf(step as YamlMap)}"',
          '${step['run'] ?? ''}',
          powerShell: _isPowerShell(
            step['shell'] ??
                _default(value, 'shell') ??
                _default(root, 'shell'),
          ),
          environment: {
            ..._map(root['env']),
            ..._map(value['env']),
            ..._map(step['env']),
          },
        ).startAnswers)
          ('$file, job $job, step "${_nameOf(step)}"', name),
  ];
}

/// The answers that [script], the text of the script [file] of
/// .github/scripts, gives .github/scripts/start_app.sh, as in
/// [startAnswersOf].
List<(String, String)> scriptStartAnswersOf(
  String script, {
  required String file,
  bool powerShell = false,
}) =>
    [
      for (final name
          in _Script(file, script, powerShell: powerShell).startAnswers)
        (file, name),
    ];

/// The problems of [answers], each with where it is, that no probe of a
/// matrix tool asks for, of those that probes ask for, [asked]. The script
/// skips an answer that the app does not list, with a notice, since an app
/// of a covering of the providers of a role may lack the provider whose
/// probe asks for it. So a name that no probe has would turn a check of CI
/// off in every app, quietly.
List<String> answerProblemsOf(
  List<(String, String)> answers,
  Set<String> asked,
) {
  final names = (asked.toList()..sort()).join(', ');
  final known = asked.isEmpty ? '' : ', one of $names';
  String problem(String where, String name) =>
      '$where gives start_app.sh the answer $name, which no probe of a '
      'matrix tool asks for (MatrixStartProbe.answer), so the script would '
      'skip it in every app: name the answer as the probe that asks for it '
      'does$known.';
  return [
    for (final (where, name) in answers)
      if (!asked.contains(name)) problem(where, name),
  ];
}

/// The text of [text] from [start] up to the parenthesis that closes the
/// one before [start], or to its end, with what is in quotes as it is.
String _inParentheses(String text, int start) {
  String? quote;
  var end = start;
  while (end < text.length && (quote != null || text[end] != ')')) {
    final char = text[end];
    if (quote != null) {
      if (char == quote) quote = null;
    } else if (char == '"' || char == "'") {
      quote = char;
    }
    end++;
  }
  return text.substring(start, end);
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

  /// The names of the answers that the script gives start_app.sh: the
  /// name of each argument `<name>=<command>` after the script in a command
  /// that runs it, also through a variable or an array (see
  /// [startAnswersOf]).
  late final List<String> startAnswers = [
    for (final words in commands)
      for (final (index, word) in words.indexed)
        if (word.endsWith('start_app.sh'))
          for (final argument in words.skip(index + 1))
            for (final value in _valuesOf(argument))
              if (RegExp('^([a-z0-9_]+)=.').firstMatch(value) case final match?)
                match[1]!,
  ];

  /// What [word] may stand for: the items of the array of bash that it
  /// expands, as `"${answers[@]}"`, which the script assigns or adds to,
  /// each through a variable too; the values of the variable that it refers
  /// to, of the environment or assigned in the script; or else itself.
  List<String> _valuesOf(String word) =>
      switch (RegExp(r'^\$\{(\w+)\[[@*]\]\}$').firstMatch(word)) {
        final match? => [
            for (final item in _itemsOf(match[1]!)) ..._valuesOfVariable(item),
          ],
        null => _valuesOfVariable(word),
      };

  /// The values of the variable that [word] refers to, of the environment
  /// or assigned in the script, or else [word] itself.
  List<String> _valuesOfVariable(String word) {
    final variable = _variableOf(word);
    if (variable == null) return [word];
    return [
      if (_environment[variable] case final value?) value,
      for (final words in commands)
        for (final word in words)
          if (_assignment.firstMatch(word) case final match?
              when match[1] == variable)
            match[2]!,
    ];
  }

  /// The items that the script assigns to the array of bash [name] or adds
  /// to it, as in `answers=("a=b")` or `answers+=("$answer")`, wherever the
  /// assignment is in a line.
  List<String> _itemsOf(String name) => [
        for (final match in RegExp(
          '(?:^|[\\s;&|])${RegExp.escape(name)}\\+?=\\(',
        ).allMatches(text))
          for (final words in commandsOf(_inParentheses(text, match.end)))
            ...words,
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
/// [_wholeSelection], one that adds the tests of a matrix tool to an app
/// without --app, and, in a job whose matrix has the keys [planKeys] from
/// the plan, all of them for `*`, an --app or a --shard of a run that
/// generates or checks apps, or adds tests to one, that does not come from
/// the matrix of the plan, directly or through a variable of the
/// environment of the step. A run that only explains what smf create would
/// generate may take an app of the plan as it likes. A script of
/// .github/scripts, which has no matrix, has no [planKeys] and takes them
/// as it is given them.
List<String> _planProblemsOfScript(_Script script, Set<String>? planKeys) {
  final problems = <String>[];
  for (final words in script.commands) {
    if (_wholeSelection(words, script._isTool) case final what?) {
      problems.add(_whole(script.where, what));
    }
    final (:arguments, :choice) = _choiceOf(
      _argumentsOfTool(words, script._isTool),
    );
    if (arguments.firstOrNull == '--add-app-tests' &&
        !choice.containsKey('--app')) {
      problems.add(
        '${script.where} adds the tests of a matrix tool to an app without '
        '--app. With --app, the name of the app with every module of the plan '
        'that --create --app generated, the tool fills the values of the '
        'tests and the files that they generate for that app, and adds to the '
        'start check the probes of the tests of the roles of the app, such as '
        'the walk of its routes: take --app from the matrix of the job, as '
        '--create --app does.',
      );
    }
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

/// The input of a reusable workflow that lets the job that writes each
/// cache of the native builds save it.
const nativeCacheSaveInput = 'save_native_caches';

/// The condition of a value of [nativeCacheSaveInput] that keeps the writes
/// to the runs on main.
const _onMain = "github.ref == 'refs/heads/main'";

/// The problems of the caches of the native builds in the jobs of
/// [workflow], the text of the workflow [file] of GitHub Actions: of what
/// the package manager of the platform of a job downloads for the native
/// build, Gradle on Linux, for Android, and Swift Package Manager on macOS,
/// for iOS, whose cache of the repositories of packages xcodebuild keeps in
/// ~/Library/Caches/org.swift.swiftpm. The key of an entry is its family,
/// what the app of the job builds with, and the week. The jobs of one
/// matrix, of the apps with every module, are the writers: each saves an
/// entry of its family when the cache has none under its key yet, and
/// every other job only restores (see [nativeCacheWriterProblemsOf] for
/// what the workflows share).
/// - A job on Linux or macOS that generates an app with --create, to build,
///   archive or start it, and restores no such cache. Without it each such
///   job downloads the same plugins again, such as the Firebase SDK, and
///   Maven Central answers 403 to a runner that downloads too much.
/// - A step of such a cache whose `if` reads the outputs or the outcome of
///   a step that its job does not have before it, as a step that a YAML
///   anchor takes from another job may: GitHub reads such a step as
///   nothing, and actionlint refuses it.
/// - A step that saves the cache other than as a writer does:
///   - under a key that no step before it only looked up
///     (`lookup-only: true`), as a step that saves the cache with the key
///     of that step, `steps.<id>.outputs.cache-primary-key`, takes it, so
///     that the job knows whether the cache has the key before its build;
///   - whenever the job gets to it, rather than only when that step ran,
///     `steps.<id>.outcome == 'success'`, and found no entry,
///     `steps.<id>.outputs.cache-hit != 'true'`, or also after a build that
///     failed, with `always()`, `failure()` or `cancelled()`;
///   - when that step runs in every run, rather than only in those that
///     [nativeCacheSaveInput] lets save, or only in some jobs of its
///     matrix, by a condition on the strategy or the matrix of the job,
///     such as `strategy.job-index == 0`;
///   - under a key that does not hash the file that [nativeBuildTool]
///     writes for the platform of the job after the step that generates the
///     apps with --create, if the job has one, and for Gradle under a key
///     without the version of Flutter, `inputs.flutter_version`, whose
///     engine Gradle downloads too, hundreds of MB;
///   - after another step of the job that restores an entry of the cache
///     also when the key was not found, rather than only if
///     `steps.<id>.outputs.cache-hit == 'true'`: the writer builds from an
///     empty cache then, so that a new entry holds only what one build
///     downloads, and none of what the builds of the entries before it
///     needed and no build needs any more.
List<String> nativeCacheProblemsOf(String workflow, {required String file}) {
  final problems = <String>[];
  final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
  for (final MapEntry(key: job, :value) in jobs.entries) {
    final definition = value as YamlMap;
    final native = _nativeCacheOf('${definition['runs-on']}');
    if (native == null) continue;
    final steps = _stepsOf(definition);
    final uses = [for (final step in steps) _cacheUseOf(step, native.path)];
    if (_generatesApps(definition) &&
        !uses.any((use) => use?.restores ?? false)) {
      problems.add(_uncached(file, job, native.manager, native.path));
    }
    for (final (index, use) in uses.indexed) {
      if (use == null) continue;
      final ids = {for (final step in steps.take(index)) step['id']};
      final read = {
        for (final match in RegExp(r'steps\.([\w-]+)\.')
            .allMatches('${steps[index]['if'] ?? ''}'))
          match[1]!,
      };
      for (final id in read.difference(ids)) {
        problems.add(
          _readsMissingStep(
            '$file, job $job, step "${_nameOf(steps[index])}"',
            id,
          ),
        );
      }
      if (use.saves) {
        problems.addAll(
          _writerProblemsOf(
            '$file, job $job, step "${_nameOf(steps[index])}"',
            definition,
            steps,
            uses,
            index,
            native,
          ),
        );
      }
    }
  }
  return problems;
}

/// The problems of the step [index] of [steps], the steps of the job
/// [definition], which saves the cache of [native], as the writer of the
/// cache (see [nativeCacheProblemsOf]); [uses] are what each step does
/// with the cache, and [where] names the step.
List<String> _writerProblemsOf(
  String where,
  YamlMap definition,
  List<YamlMap> steps,
  List<_CacheUse?> uses,
  int index,
  _NativeCache native,
) {
  final (:manager, :platform, path: _, os: _) = native;
  final lookup = _lookupOf(steps, uses, index);
  if (lookup < 0) return [_notLookedUp(where, manager)];
  final id = '${steps[lookup]['id']}';
  final lookupIf = '${steps[lookup]['if'] ?? ''}';
  final key = _keyOf(steps[lookup]);
  final saveIf = '${steps[index]['if'] ?? ''}';
  bool requires(int step, String part) => _mentions(steps[step]['if'], part);
  return [
    if (!requires(index, "steps.$id.outcome == 'success'") ||
        !requires(index, "steps.$id.outputs.cache-hit != 'true'"))
      _savesWhenFound(where, manager, id),
    if (RegExp(r'\b(?:always|failure|cancelled)\(\)').hasMatch(saveIf))
      _savesAfterFailure(where, manager, saveIf),
    if (!lookupIf.contains('inputs.$nativeCacheSaveInput'))
      _savesInEveryRun(where, manager, id),
    if (RegExp(r'\b(?:strategy|matrix)\.').hasMatch(lookupIf))
      _savesInSomeJobs(where, manager, id, lookupIf),
    if (!_byApp(key, steps, lookup, platform))
      _notByApp(where, manager, key, platform),
    if (platform == 'android' && !key.contains('inputs.flutter_version'))
      _notByFlutter(where, manager, key),
    for (final (other, use) in uses.indexed)
      if (other != lookup &&
          (use?.restores ?? false) &&
          !requires(other, "steps.$id.outputs.cache-hit == 'true'"))
        _restoresWhenNotFound(where, manager, _nameOf(steps[other]), id),
  ];
}

/// The index of the step before the step [index] of [steps] that only
/// looks up the key under which the step [index] saves a cache,
/// `${{ steps.<id>.outputs.cache-primary-key }}`, or -1 if there is none;
/// [uses] are what each step does with the cache.
int _lookupOf(List<YamlMap> steps, List<_CacheUse?> uses, int index) {
  final id = RegExp(
    r'^\$\{\{\s*steps\.([\w-]+)\.outputs\.cache-primary-key\s*\}\}$',
  ).firstMatch(_keyOf(steps[index]).trim())?[1];
  final lookup = steps.indexWhere((step) => id != null && step['id'] == id);
  return lookup >= 0 && lookup < index && (uses[lookup]?.looksUp ?? false)
      ? lookup
      : -1;
}

/// Whether [condition], the `if` of a step, has [part], whatever the
/// spaces of either.
bool _mentions(Object? condition, String part) {
  String squeezed(String text) => text.replaceAll(RegExp(r'\s'), '');
  return squeezed('${condition ?? ''}').contains(squeezed(part));
}

/// The problem that [where] saves the cache of [manager] under a key that
/// no step before it only looked up.
String _notLookedUp(String where, String manager) =>
    '$where saves the cache of $manager under a key that no step before it '
    'only looked up. Look the key of the app of the job up before its build '
    'with actions/cache/restore and lookup-only: true, build from an empty '
    'cache when that step finds no entry, and save the cache only then, '
    r'with the key ${{ steps.<id>.outputs.cache-primary-key }} of that step: '
    'the jobs of the apps with every module write the entries of their '
    'families, and every other job only restores them.';

/// The problem that [where] saves the cache of [manager] also when the
/// step [id] did not run or found the key.
String _savesWhenFound(String where, String manager, String id) =>
    '$where saves the cache of $manager also when the step $id, which looks '
    'its key up, did not run or found it: save it only if: '
    "steps.$id.outcome == 'success' && steps.$id.outputs.cache-hit != "
    "'true'. An entry is never replaced under its key, and a job that does "
    'not write the cache saves nothing.';

/// The problem that [where] saves the cache of [manager] in every run, as
/// the step [id] that looks its key up does.
String _savesInEveryRun(String where, String manager, String id) =>
    '$where saves the cache of $manager in every run: keep the step $id, '
    'which looks its key up, to the runs that the input '
    '$nativeCacheSaveInput lets save the native caches, which the workflows '
    'pass only for the runs on main, whose entries the runs of every branch '
    'find.';

/// The problem that [where] saves the cache of [manager] only in the jobs
/// of its matrix that [condition], the condition of the step [id] that
/// looks its key up, lets through.
String _savesInSomeJobs(
  String where,
  String manager,
  String id,
  String condition,
) =>
    '$where saves the cache of $manager only in some jobs of its matrix '
    '(the step $id: if: $condition). The apps of the other jobs, such as '
    'those of a second provider of a role with native code, would download '
    'what their native stack adds in every run: let every job of the matrix '
    'write the entries of its family.';

/// The problem that [where] saves the cache of [manager] also after a build
/// that failed, by [condition].
String _savesAfterFailure(String where, String manager, String condition) =>
    '$where saves the cache of $manager also after a build that failed (if: '
    '$condition): a build that failed may have downloaded part of what the '
    'app needs, and the key would then stay taken by an entry that lacks the '
    'rest. Save it only after the steps before it succeeded.';

/// The problem that [where] reads the step [id], which its job does not
/// have before it.
String _readsMissingStep(String where, String id) =>
    '$where reads the step $id, which its job does not have before it: '
    'GitHub reads such a step as nothing, and actionlint refuses it. Give a '
    'job without the step a step of its own, rather than the step of a job '
    'with it.';

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
    'writer saves a new entry when its app builds with another plugin or '
    'another native project.';

/// The problem that [where] saves the cache of [manager] under [key], which
/// does not name the version of Flutter.
String _notByFlutter(String where, String manager, String key) =>
    '$where saves the cache of $manager under the key $key, which does not '
    r'name the version of Flutter, ${{ inputs.flutter_version }}. Gradle '
    'downloads the engine of Flutter too, hundreds of MB for each version, '
    'so a new version of Flutter needs a new entry.';

/// The problem that [where] saves the cache of [manager] after the step
/// [step] restored an entry when the step [id] found no entry under the
/// key of the app.
String _restoresWhenNotFound(
  String where,
  String manager,
  String step,
  String id,
) =>
    '$where saves the cache of $manager after the step "$step", which '
    'restores an entry of it also when the step $id found no entry under '
    'the key of the app: restore it only if: steps.$id.outputs.cache-hit '
    "== 'true', or when the step $id did not run. The new entry would also "
    'hold what the builds of the entries before it downloaded, which no '
    'build may need any more, and grow with each one.';

/// The problems of the caches of the native builds that the workflows
/// share, in [workflows], the texts of the workflows of GitHub Actions by
/// the names of their files:
/// - A cache of a platform that jobs restore and no step saves, or that
///   steps of several jobs save. The jobs of the matrix of the apps with
///   every module write the entries of their families, and every other job
///   restores: the apps of the others build with less, and their entries
///   would take the place of the entries of the writers as the newest of
///   the platform.
/// - A step that restores the cache without the restore keys of the family
///   of its own key, the text before its last expression, the week, and
///   then of the platform, the text of the key of the writers before its
///   first expression. A job restores the newest entry of its family when
///   the entry of the week is not there yet, and the newest of the platform
///   when no writer has its native stack.
/// - A reusable workflow whose input [nativeCacheSaveInput] is true by
///   default, or whose jobs have other permissions than `contents: read`
///   alone, a job that calls one with that input neither false nor kept to
///   the runs on main, `github.ref == 'refs/heads/main'`, and a second
///   workflow that lets it save, whose writers would add the entries of
///   another version of Flutter, such as the nightly run. A run of a pull
///   request, or a run by hand on another branch, saves its caches for its
///   own ref, where only its own later runs find them.
/// - A workflow that lets the writers save without a job that deletes the
///   entries that a newer one of their family replaced, with
///   `gh api --method DELETE` of `repos/<repository>/actions/caches/<id>`,
///   for each prefix of the keys of the writers.
/// - A job, or a workflow, with the permission `actions: write`, which
///   such a deletion needs, but for the jobs that delete the entries, and
///   such a job with any other permission. The jobs that build the apps
///   run the code of their dependencies, which must not get a token that
///   can delete caches or start and cancel runs.
List<String> nativeCacheWriterProblemsOf(Map<String, String> workflows) {
  final roots = {
    for (final MapEntry(:key, :value) in workflows.entries)
      key: loadYaml(value) as YamlMap,
  };
  // The jobs that save each cache, the prefix of the keys of their entries,
  // and the steps that restore each cache, with the family of their key.
  final writers = <String, Set<String>>{};
  final prefixes = <String, String>{};
  final restores = <({
    String where,
    String manager,
    String family,
    List<String> keys,
  })>[];
  final problems = <String>[];
  for (final MapEntry(key: file, value: root) in roots.entries) {
    for (final MapEntry(key: job, :value) in _jobsOf(root).entries) {
      final definition = value as YamlMap;
      final native = _nativeCacheOf('${definition['runs-on']}');
      if (native == null) continue;
      final steps = _stepsOf(definition);
      final uses = [for (final step in steps) _cacheUseOf(step, native.path)];
      for (final (index, use) in uses.indexed) {
        final where = '$file, job $job, step "${_nameOf(steps[index])}"';
        if (use?.restores ?? false) {
          final keys = (steps[index]['with'] as YamlMap?)?['restore-keys'];
          final key = _resolved(_keyOf(steps[index]), native.os);
          final last = key.lastIndexOf(r'${{');
          restores.add(
            (
              where: where,
              manager: native.manager,
              family: last < 0 ? key : key.substring(0, last),
              keys: [
                for (final line in '${keys ?? ''}'.split('\n'))
                  if (line.trim().isNotEmpty) _resolved(line.trim(), native.os),
              ],
            ),
          );
        }
        if (!(use?.saves ?? false)) continue;
        (writers[native.manager] ??= {}).add('$file, job $job');
        // A step that saves under a key that no step looked up has a
        // problem of its own (see nativeCacheProblemsOf).
        final lookup = _lookupOf(steps, uses, index);
        if (lookup < 0) continue;
        final key = _resolved(_keyOf(steps[lookup]), native.os);
        final prefix = key.split(r'${{').first;
        if (prefix.isEmpty) {
          problems.add(_noPrefix(where, native.manager, key));
        } else {
          prefixes[native.manager] = prefix;
        }
      }
    }
  }
  for (final manager in {
    for (final restore in restores) restore.manager,
    ...writers.keys,
  }) {
    switch ([...?writers[manager]]) {
      case []:
        problems.add(_unwritten(manager));
      case [_, _, ...] && final jobs:
        problems.add(_writtenTwice(manager, jobs));
    }
  }
  for (final (:where, :manager, :family, :keys) in restores) {
    if (prefixes[manager] case final prefix?) {
      final wanted = {family, prefix}.toList();
      final found = [
        for (final key in keys)
          if (wanted.contains(key)) key,
      ];
      if (found.join('\n') != wanted.join('\n')) {
        problems.add(_notNewest(where, manager, wanted));
      }
    }
  }
  return [
    ...problems,
    ..._saveInputProblemsOf(roots, {...prefixes.values}),
    ..._actionsWriteProblemsOf(roots),
  ];
}

/// The text of [key], a key of a cache of a job on the runner whose
/// `runner.os` is [os], with `${{ runner.os }}` as GitHub Actions replaces
/// it.
String _resolved(String key, String os) =>
    key.replaceAll(RegExp(r'\$\{\{\s*runner\.os\s*\}\}'), os);

/// The problems of the input [nativeCacheSaveInput] in [roots], the
/// workflows by the names of their files, whose writers save under keys
/// with [prefixes] (see [nativeCacheWriterProblemsOf]).
List<String> _saveInputProblemsOf(
  Map<String, YamlMap> roots,
  Set<String> prefixes,
) {
  final problems = <String>[];
  // The reusable workflows with the input.
  final saving = <String>{};
  for (final MapEntry(key: file, value: root) in roots.entries) {
    final inputs = switch (root['on']) {
      {'workflow_call': {'inputs': final YamlMap inputs}} => inputs,
      _ => null,
    };
    final input = inputs?[nativeCacheSaveInput];
    if (input is! YamlMap) continue;
    saving.add(file);
    if (input['default'] == true) problems.add(_savesByDefault(file));
    final permissions = root['permissions'];
    if (permissions is! YamlMap ||
        permissions.length != 1 ||
        permissions['contents'] != 'read') {
      problems.add(_notReadOnly(file, permissions));
    }
  }
  // The jobs that let one save, by the files of their workflows.
  final callers = <String, List<(Object?, String)>>{};
  for (final MapEntry(key: file, value: root) in roots.entries) {
    for (final MapEntry(key: job, :value) in _jobsOf(root).entries) {
      final called = '${(value as YamlMap)['uses'] ?? ''}'.split('/').last;
      final Object? given = (value['with'] as YamlMap?)?[nativeCacheSaveInput];
      if (!saving.contains(called) || given == null || given == false) {
        continue;
      }
      if (!'$given'.contains(_onMain)) {
        problems.add(_savesOutsideMain(file, job, called, given));
      }
      (callers[file] ??= []).add((job, called));
    }
  }
  if (callers.length > 1) {
    for (final MapEntry(key: file, value: jobs) in callers.entries) {
      for (final (job, called) in jobs) {
        problems.add(
          _savedByTwo(file, job, called, {...callers.keys}..remove(file)),
        );
      }
    }
  }
  for (final MapEntry(key: file, value: jobs) in callers.entries) {
    final deleting = _deletingJobsOf(roots[file]!);
    final deleted = [
      for (final job in deleting.values)
        for (final step in _stepsOf(job)) '${step['run'] ?? ''}',
    ].join('\n');
    final missing = [
      for (final prefix in prefixes.toList()..sort())
        if (!deleted.contains(prefix)) prefix,
    ];
    if (deleting.isEmpty || missing.isNotEmpty) {
      final (job, called) = jobs.first;
      problems.add(_notDeleted(file, job, called, missing));
    }
  }
  return problems;
}

/// The jobs of [root], a workflow, that delete entries of the caches of the
/// repository, with `gh api --method DELETE` of
/// `repos/<repository>/actions/caches/<id>`, by their ids.
Map<Object?, YamlMap> _deletingJobsOf(YamlMap root) => {
      for (final MapEntry(key: job, :value) in _jobsOf(root).entries)
        if (_stepsOf(value as YamlMap).any((step) {
          final run = '${step['run'] ?? ''}';
          return run.contains('/actions/caches') &&
              RegExp(r'(--method|-X)\s+DELETE\b').hasMatch(run);
        }))
          job: value,
    };

/// The problems of the permission `actions: write` in [roots], the
/// workflows by the names of their files (see
/// [nativeCacheWriterProblemsOf]).
List<String> _actionsWriteProblemsOf(Map<String, YamlMap> roots) {
  bool writesActions(Object? permissions) =>
      permissions == 'write-all' ||
      (permissions is YamlMap && permissions['actions'] == 'write');
  final problems = <String>[];
  for (final MapEntry(key: file, value: root) in roots.entries) {
    if (writesActions(root['permissions'])) {
      problems.add(_writesActions(file));
    }
    final deleting = _deletingJobsOf(root);
    for (final MapEntry(key: job, :value) in _jobsOf(root).entries) {
      final permissions = (value as YamlMap)['permissions'];
      if (!deleting.containsKey(job)) {
        if (writesActions(permissions)) {
          problems.add(_writesActions('$file, job $job'));
        }
      } else if (permissions is! YamlMap ||
          permissions.length != 1 ||
          permissions['actions'] != 'write') {
        problems.add(_deletesWithOtherPermissions(file, job, permissions));
      }
    }
  }
  return problems;
}

/// The jobs of [root], a workflow.
YamlMap _jobsOf(YamlMap root) => root['jobs'] as YamlMap? ?? YamlMap();

/// The steps of [job], a job of a workflow.
List<YamlMap> _stepsOf(YamlMap job) => [
      for (final step in job['steps'] as YamlList? ?? YamlList())
        step as YamlMap,
    ];

/// The problem that [where] saves the cache of [manager] under [key], whose
/// text starts with an expression.
String _noPrefix(String where, String manager, String key) =>
    '$where saves the cache of $manager under the key $key, which starts '
    'with an expression: start it with a text that names the cache, such as '
    r'${{ runner.os }}-gradle-, under which the other jobs restore the '
    'newest entry and the job that deletes the replaced entries finds them.';

/// The problem that no step saves the cache of [manager], which jobs
/// restore.
String _unwritten(String manager) =>
    'Jobs restore the cache of $manager, but no step saves it: let the job '
    'of the first app with every module of the plan write it, in the runs '
    'on main, so that the jobs do not download the same packages in every '
    'run.';

/// The problem that steps of the [jobs] save the cache of [manager].
String _writtenTwice(String manager, List<String> jobs) =>
    'Steps of several jobs save the cache of $manager: ${jobs.join('; ')}. '
    'The jobs of the matrix of the apps with every module write the entries '
    'of their families, and every other job only restores: the apps of the '
    'other jobs build with what an app with every module builds with, or '
    'with less, and their entries would take the place of the entries of '
    'the writers as the newest of the platform.';

/// The problem that [where] restores the cache of [manager] without the
/// restore keys [wanted], in their order.
String _notNewest(String where, String manager, List<String> wanted) =>
    '$where restores the cache of $manager without the restore keys '
    '${wanted.join(' and then ')}: the newest entry of the family of its '
    'key, when the entry of the week is not there yet, and the newest entry '
    'of the platform, when no job writes the entries of its native stack.';

/// The problem that the reusable workflow [file] lets its jobs save the
/// caches of the native builds by default.
String _savesByDefault(String file) =>
    '$file lets its jobs save the caches of the native builds by default '
    '($nativeCacheSaveInput: true), so a workflow that calls it without the '
    'input saves them in any run, such as that of a pull request: make it '
    'false by default, and let the workflow that calls it pass it for the '
    'runs on main.';

/// The problem that the jobs of the reusable workflow [file] have the
/// [permissions] of the workflow rather than `contents: read` alone.
String _notReadOnly(String file, Object? permissions) =>
    '$file gives its jobs the permissions '
    '${permissions ?? 'of the workflow that calls it'} rather than '
    'contents: read alone: its jobs build the apps with the code of their '
    'dependencies, and they only check out the repository. Set permissions: '
    'contents: read at its top.';

/// The problem that the job [job] of the workflow [file] calls the workflow
/// [called] with [nativeCacheSaveInput] [given], which lets it save the
/// caches of the native builds outside the runs on main.
String _savesOutsideMain(
  String file,
  Object? job,
  String called,
  Object given,
) =>
    '$file, job $job calls $called with $nativeCacheSaveInput: $given, which '
    'lets it save the caches of the native builds in other runs than those '
    'on main. A run of a pull request, or a run by hand on another branch, '
    'saves them for its own ref, where only its own later runs find them: '
    'keep the input to \${{ $_onMain }}, with any other condition of the '
    'workflow.';

/// The problem that the job [job] of the workflow [file] lets [called]
/// save the caches of the native builds, as jobs of the workflows [others]
/// do.
String _savedByTwo(
  String file,
  Object? job,
  String called,
  Set<String> others,
) =>
    '$file, job $job lets $called save the caches of the native builds, and '
    'so does ${others.join(', ')}. The writers of another workflow, such as '
    'the runs of other versions of Flutter, would add families of entries '
    'of their own, an entry of Gradle of 1.5 GB for each version of '
    'Flutter: let one workflow write them.';

/// The problem that the workflow [file], whose job [job] lets [called] save
/// the caches of the native builds, has no job that deletes the entries
/// that a newer one replaced, of [missing] prefixes, or none at all.
String _notDeleted(
  String file,
  Object? job,
  String called,
  List<String> missing,
) {
  final keys = missing.isEmpty
      ? ''
      : ', of the keys that start with ${missing.join(' and ')}';
  return '$file, job $job lets $called save the caches of the native '
      'builds, but no job of $file deletes the entries that a newer one of '
      'their family replaced$keys. Each new entry would stay next to those '
      'before it, over 1 GB for Gradle, in the 10 GB of caches of the '
      'repository: delete each entry of a family but the newest with gh api '
      '--method DELETE repos/<repository>/actions/caches/<id>.';
}

/// The problem that [where], a workflow or a job of one, has the permission
/// `actions: write` without deleting the entries of the caches.
String _writesActions(String where) =>
    '$where has the permission actions: write, but deletes no entry of the '
    'caches, the only job that needs it. The jobs that build the apps run '
    'the code of their dependencies, which must not get a token that can '
    'delete caches or start and cancel runs.';

/// The problem that the job [job] of the workflow [file] deletes entries of
/// the caches with [permissions] other than `actions: write` alone.
String _deletesWithOtherPermissions(
  String file,
  Object? job,
  Object? permissions,
) =>
    '$file, job $job deletes entries of the caches with the permissions '
    '${permissions ?? 'of the workflow'}: give it actions: write, and '
    'nothing else.';

/// The problem that the job [job] of the workflow [file] generates an app
/// to build and restores no cache of [manager], whose path has [path].
String _uncached(String file, Object? job, String manager, String path) =>
    '$file, job $job generates an app with --create to build it for its '
    'platform, but restores no cache of $manager ($path): each job would '
    'download the same packages again.';

/// The init script of Gradle that every job that builds for Android puts
/// into ~/.gradle/init.d, which takes what Gradle would download from Maven
/// Central from the mirror of Maven Central that Google keeps, and from
/// Maven Central only what the mirror does not have yet.
const mavenCentralMirror = '.github/gradle/maven_central_mirror.gradle';

/// The problems of the downloads from Maven Central in [workflow], the text
/// of the workflow [file] of GitHub Actions: a job on Linux that builds for
/// Android, from the step that restores the cache of Gradle, builds an app
/// with [buildApk] or `flutter build apk`, or starts one with
/// .github/scripts/start_app.sh, whichever comes first, without a step
/// before it that puts
/// [mavenCentralMirror] into ~/.gradle/init.d. Maven Central answers 403 to
/// a runner that downloads too much, and a job downloads what the cache
/// that it restored lacks, such as what its app needs beyond the cache of
/// another app that it found instead of the cache of its own.
List<String> mavenCentralProblemsOf(String workflow, {required String file}) {
  final problems = <String>[];
  final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
  for (final MapEntry(key: job, :value) in jobs.entries) {
    final definition = value as YamlMap;
    if (_nativeCacheOf('${definition['runs-on']}')?.platform != 'android') {
      continue;
    }
    final steps = [
      for (final step in definition['steps'] as YamlList? ?? YamlList())
        step as YamlMap,
    ];
    final gradle = steps.indexWhere(
      (step) =>
          (_cacheUseOf(step, '.gradle/')?.restores ?? false) ||
          _buildsForAndroid(step),
    );
    if (gradle >= 0 && !steps.take(gradle).any(_mirrorsMavenCentral)) {
      problems.add(_unmirrored(file, job, _nameOf(steps[gradle])));
    }
  }
  return problems;
}

/// Whether [step] runs Gradle for Android: builds an app with [buildApk],
/// `flutter build apk` or `flutter build appbundle`, or starts one on
/// Android with .github/scripts/start_app.sh, which builds it.
bool _buildsForAndroid(YamlMap step) =>
    commandsOf('${step['run'] ?? ''}').any((words) {
      for (final (index, word) in words.indexed) {
        final rest = words.skip(index + 1).take(2).toList();
        if (_flutterBuilds(words, index, const {'apk', 'appbundle'}) ||
            word.endsWith(buildApk.split('/').last)) {
          return true;
        }
        if (word.endsWith('start_app.sh') &&
            rest.isNotEmpty &&
            rest[0] == 'android') {
          return true;
        }
      }
      return false;
    });

/// Whether the word at [index] of [words] is `flutter`, followed by `build`
/// and one of [targets].
bool _flutterBuilds(List<String> words, int index, Set<String> targets) {
  final rest = words.skip(index + 1).take(2).toList();
  return words[index] == 'flutter' &&
      rest.length == 2 &&
      rest[0] == 'build' &&
      targets.contains(rest[1]);
}

/// The script with which every step of a workflow builds an app for
/// Android. It runs `flutter build apk`, and builds the app again when the
/// build failed because a package of the Android SDK did not download.
const buildApk = '.github/scripts/build_apk.sh';

/// The problems of the builds for Android in [workflow], the text of the
/// workflow [file] of GitHub Actions: a step that runs `flutter build apk`
/// itself rather than with [buildApk]. The Gradle plugin of Android
/// downloads the NDK of Flutter in each build of CI, which the SDK of the
/// runner lacks, and a download that breaks off fails the build, which
/// only [buildApk] tries again.
List<String> apkBuildProblemsOf(String workflow, {required String file}) {
  final problems = <String>[];
  final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
  for (final MapEntry(key: job, :value) in jobs.entries) {
    for (final step in (value as YamlMap)['steps'] as YamlList? ?? YamlList()) {
      final runsItself = commandsOf('${(step as YamlMap)['run'] ?? ''}').any(
        (words) => words.indexed.any(
          (word) => _flutterBuilds(words, word.$1, const {'apk'}),
        ),
      );
      if (runsItself) {
        problems.add(
          '$file, job $job, step "${_nameOf(step)}" runs flutter build apk '
          'itself. Build with $buildApk, which builds the app again when a '
          'package of the Android SDK did not download: the Gradle plugin '
          'of Android downloads the NDK of Flutter in each build of CI, and '
          'a download that breaks off fails the build.',
        );
      }
    }
  }
  return problems;
}

/// Whether [step] puts [mavenCentralMirror] into ~/.gradle/init.d, where
/// every build of Gradle of the user runs it.
bool _mirrorsMavenCentral(YamlMap step) {
  final run = '${step['run'] ?? ''}';
  return run.contains(mavenCentralMirror) && run.contains('.gradle/init.d');
}

/// The problem that the job [job] of the workflow [file] builds for Android
/// from the step [step] on without [mavenCentralMirror].
String _unmirrored(String file, Object? job, String step) =>
    '$file, job $job runs Gradle for Android from the step "$step" on, but '
    'no step before it puts $mavenCentralMirror into ~/.gradle/init.d. '
    'Gradle would download from Maven Central what the cache that the job '
    'restored lacks, such as what its app needs beyond the cache of another '
    'app, and Maven Central answers 403 to a runner that downloads too much.';

/// The package manager of the native builds of a platform, a part of the
/// path of its cache, the platform of the builds as [nativeBuildTool] takes
/// it, and the `runner.os` of the runners that build for it.
typedef _NativeCache = ({
  String manager,
  String path,
  String platform,
  String os,
});

/// What a step does with a cache: restores an entry of it, saves one, or
/// only looks a key up (`lookup-only: true`).
typedef _CacheUse = ({bool restores, bool saves, bool looksUp});

/// The cache of the native builds on the runner [runsOn], or `null` for a
/// runner that builds none.
_NativeCache? _nativeCacheOf(String runsOn) => switch (runsOn) {
      final label when label.startsWith('ubuntu') => (
          manager: 'Gradle',
          path: '.gradle/',
          platform: 'android',
          os: 'Linux',
        ),
      final label when label.startsWith('macos') => (
          manager: 'Swift Package Manager',
          path: 'org.swift.swiftpm',
          platform: 'ios',
          os: 'macOS',
        ),
      _ => null,
    };

/// Whether a step of [job] generates apps with --create.
bool _generatesApps(YamlMap job) => [
      for (final step in job['steps'] as YamlList? ?? YamlList())
        '${(step as YamlMap)['run'] ?? ''}',
    ].any((run) => run.contains('--create'));

/// What [step] does with a cache whose path has [path], or `null` for a
/// step that does nothing with it: actions/cache restores the cache and
/// saves it at the end of the job, actions/cache/restore only restores it,
/// or only looks its key up with `lookup-only: true`, and
/// actions/cache/save only saves it.
_CacheUse? _cacheUseOf(YamlMap step, String path) {
  final inputs = step['with'] as YamlMap?;
  if (!'${inputs?['path'] ?? ''}'.contains(path)) return null;
  final looksUp = '${inputs?['lookup-only']}' == 'true';
  return switch ('${step['uses'] ?? ''}') {
    final uses when uses.startsWith('actions/cache/restore@') => (
        restores: !looksUp,
        saves: false,
        looksUp: looksUp,
      ),
    final uses when uses.startsWith('actions/cache/save@') => (
        restores: false,
        saves: true,
        looksUp: false,
      ),
    final uses when uses.startsWith('actions/cache@') => (
        restores: true,
        saves: true,
        looksUp: false,
      ),
    _ => null,
  };
}

/// The key of the cache of [step].
String _keyOf(YamlMap step) => '${(step['with'] as YamlMap?)?['key'] ?? ''}';

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
              --without-external-steps --app "$APP" \
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
            dart run packages/smf_flutter_cli/tool/matrix.dart --add-app-tests --app "$APP" "${app%/}" packages/smf_flutter_cli/app_tests/start
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

    test(
        'finds a step that adds the tests of a matrix tool to an app without '
        '--app, or with an --app that does not come from the matrix of the '
        'plan', () {
      expect(
        planProblemsOf(
          r'''
jobs:
  plan:
    outputs:
      start: ${{ steps.plan.outputs.start }}
    steps:
      - id: plan
        run: dart run packages/smf_flutter_cli/tool/matrix.dart --plan
  start:
    needs: plan
    strategy:
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.start) }}
    steps:
      - name: Without app
        env:
          APP: ${{ matrix.app }}
        run: |
          dart run packages/smf_flutter_cli/tool/matrix.dart --create --without-external-steps --app "$APP" "$apps" start_app
          for app in "$apps"/*/; do
            dart run packages/smf_flutter_cli/tool/matrix.dart --add-app-tests \
              --without-external-steps "${app%/}" packages/smf_flutter_cli/app_tests/start
          done
      - name: Named
        run: |
          for app in "$apps"/*/; do
            dart run packages/smf_flutter_cli/tool/matrix.dart --add-app-tests --app 'every module (bloc)' "${app%/}" packages/smf_flutter_cli/app_tests/start
          done
      - name: From the matrix
        env:
          APP: ${{ matrix.app }}
        run: |
          for app in "$apps"/*/; do
            dart run packages/smf_flutter_cli/tool/matrix.dart --add-app-tests --without-external-steps --app "$APP" \
              "${app%/}" packages/smf_flutter_cli/app_tests/start
            dart run packages/smf_flutter_cli/tool/matrix.dart --add-app-tests --app "${{ matrix.app }}" "${app%/}" packages/smf_flutter_cli/app_tests/start
          done
''',
          file: 'apps.yml',
        ),
        [
          equals(
            'apps.yml, job start, step "Without app" adds the tests of a '
            'matrix tool to an app without --app. With --app, the name of the '
            'app with every module of the plan that --create --app generated, '
            'the tool fills the values of the tests and the files that they '
            'generate for that app, and adds to the start check the probes of '
            'the tests of the roles of the app, such as the walk of its '
            'routes: take --app from the matrix of the job, as --create --app '
            'does.',
          ),
          startsWith(
            'apps.yml, job start, step "Named" takes --app every module '
            '(bloc), which is no value of a matrix of its job that the plan '
            'gives:',
          ),
        ],
      );
      // A script of .github/scripts has no matrix, but takes the app it is
      // given.
      expect(
        scriptPlanProblemsOf(
          r'''
#!/usr/bin/env bash
dart run packages/smf_flutter_cli/tool/matrix.dart --add-app-tests "$1" packages/smf_flutter_cli/app_tests/start
dart run packages/smf_flutter_cli/tool/matrix.dart --add-app-tests --app "$2" "$1" packages/smf_flutter_cli/app_tests/start
''',
          file: '.github/scripts/add.sh',
        ),
        [startsWith('.github/scripts/add.sh adds the tests of a matrix tool')],
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
    /// A reusable workflow as apps.yml of the repository has its jobs that
    /// build for Android and iOS: each job of the matrix of the apps with
    /// every module of each platform writes the entries of its family in
    /// the runs that save the native caches, and the other jobs restore the
    /// newest entry of their family, or else of the platform. The job
    /// ios-start has a key without the week, whose family is the platform.
    const apps = r'''
on:
  workflow_call:
    inputs:
      flutter_version:
        type: string
        required: true
      save_native_caches:
        type: boolean
        default: false
permissions:
  contents: read
jobs:
  android:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.apps) }}
    steps:
      - name: Find the week of the cache of Gradle
        id: gradle_week
        run: echo "week=$(date -u +%GW%V)" >> "$GITHUB_OUTPUT"
      - name: Generate the app with every module
        run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
      - name: Find what the app builds with for Android
        run: dart tools/native_build.dart android "$RUNNER_TEMP/apps" build/native_build/android.txt
      - name: Look up the cache of Gradle that the job writes
        id: gradle_lookup
        if: inputs.save_native_caches && hashFiles('build/native_build/android.txt') != ''
        uses: actions/cache/restore@v6
        with:
          path: &gradle_paths |
            ~/.gradle/caches/modules-2
            ~/.gradle/wrapper/dists
          key: &gradle_key ${{ runner.os }}-gradle-${{ inputs.flutter_version }}-${{ hashFiles('build/native_build/android.txt') }}-${{ steps.gradle_week.outputs.week }}
          lookup-only: true
      - name: Restore the cache of Gradle
        if: hashFiles('build/native_build/android.txt') != '' && (steps.gradle_lookup.outcome != 'success' || steps.gradle_lookup.outputs.cache-hit == 'true')
        uses: actions/cache/restore@v6
        with:
          path: *gradle_paths
          key: *gradle_key
          restore-keys: &gradle_restore_keys |
            ${{ runner.os }}-gradle-${{ inputs.flutter_version }}-${{ hashFiles('build/native_build/android.txt') }}-
            ${{ runner.os }}-gradle-
      - name: Build the app with every module for Android
        run: .github/scripts/each_app.sh "$RUNNER_TEMP/apps" "$GITHUB_WORKSPACE/.github/scripts/build_apk.sh" --debug
      - name: Save the cache of Gradle
        if: steps.gradle_lookup.outcome == 'success' && steps.gradle_lookup.outputs.cache-hit != 'true'
        uses: actions/cache/save@v6
        with:
          path: *gradle_paths
          key: ${{ steps.gradle_lookup.outputs.cache-primary-key }}
  android-start:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.start) }}
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --without-external-steps --app "$APP" "$RUNNER_TEMP/start" start_app
      - run: dart tools/native_build.dart android "$RUNNER_TEMP/start" build/native_build/android.txt
      - &restore_gradle
        name: Restore the cache of Gradle
        if: hashFiles('build/native_build/android.txt') != ''
        uses: actions/cache/restore@v6
        with:
          path: *gradle_paths
          key: *gradle_key
          restore-keys: *gradle_restore_keys
      - run: .github/scripts/each_app.sh "$RUNNER_TEMP/start" "$GITHUB_WORKSPACE/.github/scripts/start_app.sh" android emulator-5554 240
  published:
    runs-on: ubuntu-latest
    steps:
      - run: smf "${arguments[@]}"
      - run: dart tools/native_build.dart android "$RUNNER_TEMP/SMF apps from pub.dev" build/native_build/android.txt
      - *restore_gradle
  ios:
    runs-on: macos-26
    strategy:
      max-parallel: 2
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.apps) }}
    steps:
      - id: swiftpm_week
        run: echo "week=$(date -u +%GW%V)" >> "$GITHUB_OUTPUT"
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" ios_app
      - run: |
          dart tools/native_build.dart ios "$RUNNER_TEMP/apps" \
            build/native_build/ios.txt
      - name: Look up the cache of Swift packages that the job writes
        id: swiftpm_lookup
        if: ${{ inputs.save_native_caches }}
        uses: actions/cache/restore@v6
        with:
          path: ~/Library/Caches/org.swift.swiftpm
          key: ${{ runner.os }}-swiftpm-${{ hashFiles("build/native_build/ios.txt") }}-${{ steps.swiftpm_week.outputs.week }}
          lookup-only: true
      - name: Restore the cache of Swift packages
        if: steps.swiftpm_lookup.outcome != 'success' || steps.swiftpm_lookup.outputs.cache-hit == 'true'
        uses: actions/cache/restore@v6
        with:
          path: ~/Library/Caches/org.swift.swiftpm
          key: ${{ runner.os }}-swiftpm-${{ hashFiles("build/native_build/ios.txt") }}-${{ steps.swiftpm_week.outputs.week }}
          restore-keys: |
            macOS-swiftpm-${{ hashFiles("build/native_build/ios.txt") }}-
            macOS-swiftpm-
      - run: .github/scripts/each_app.sh "$RUNNER_TEMP/apps" flutter build ios --simulator --no-codesign
      - name: Save the cache of Swift packages
        if: >-
          steps.swiftpm_lookup.outcome == 'success' &&
          steps.swiftpm_lookup.outputs.cache-hit != 'true'
        uses: actions/cache/save@v6
        with:
          path: ~/Library/Caches/org.swift.swiftpm
          key: ${{ steps.swiftpm_lookup.outputs.cache-primary-key }}
  ios-start:
    runs-on: macos-26
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --without-external-steps --app "$APP" "$RUNNER_TEMP/start" start_app
      - run: dart tools/native_build.dart ios "$RUNNER_TEMP/start" build/native_build/ios.txt
      - name: Restore the cache of Swift packages
        uses: actions/cache/restore@v6
        with:
          path: ~/Library/Caches/org.swift.swiftpm
          key: ${{ runner.os }}-swiftpm-${{ hashFiles('build/native_build/ios.txt') }}
          restore-keys: |
            ${{ runner.os }}-swiftpm-${{ hashFiles('build/native_build/ios.txt') }}-
            ${{ runner.os }}-swiftpm-
  shards:
    runs-on: ubuntu-latest
    steps:
      - name: Cache the files of a tool
        if: startsWith(matrix.shard, '1/')
        uses: actions/cache@v6
        with:
          path: ~/.cache/tool
          key: tool-${{ hashFiles('tool.lock') }}
  windows:
    runs-on: windows-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" windows_app
''';

    /// A workflow as build.yml of the repository: it lets the jobs of
    /// [apps] save the native caches in the runs on main, and deletes the
    /// entries that a newer one replaced in a job of its own.
    const build = r'''
jobs:
  apps:
    uses: ./.github/workflows/apps.yml
    with:
      flutter_version: "3.44.2"
      save_native_caches: ${{ github.ref == 'refs/heads/main' }}
  native-caches:
    needs: apps
    if: ${{ !cancelled() }}
    runs-on: ubuntu-latest
    permissions:
      actions: write
    steps:
      - name: Delete the entries of the native caches that a newer one replaced
        if: github.ref == 'refs/heads/main'
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          for prefix in Linux-gradle- macOS-swiftpm-; do
            for id in $(gh api -X GET "repos/$GITHUB_REPOSITORY/actions/caches" -f key="$prefix" --jq '.actions_caches[1:][].id'); do
              gh api -X DELETE "repos/$GITHUB_REPOSITORY/actions/caches/$id"
            done
          done
  ci:
    needs: [apps, native-caches]
    runs-on: ubuntu-latest
    permissions: {}
    steps:
      - run: echo
''';

    /// A workflow as nightly.yml of the repository, which lets the jobs of
    /// [apps] save nothing.
    const nightly = r'''
jobs:
  apps:
    uses: ./.github/workflows/apps.yml
    with:
      flutter_version: ${{ matrix.flutter }}
''';

    test(
        'passes the jobs that restore the newest entry of their family or of '
        'their platform, the jobs of the apps with every module that write '
        'the entry of their key when it is not there yet, from an empty '
        'cache, and the job that deletes the entries that a newer one of '
        'their family replaced', () {
      for (final (file, workflow) in [
        ('apps.yml', apps),
        ('build.yml', build),
        ('nightly.yml', nightly),
      ]) {
        expect(
          nativeCacheProblemsOf(workflow, file: file),
          isEmpty,
          reason: file,
        );
      }
      expect(
        nativeCacheWriterProblemsOf({
          'apps.yml': apps,
          'build.yml': build,
          'nightly.yml': nightly,
        }),
        isEmpty,
      );
    });

    test(
        'finds a job on Linux or macOS that generates an app to build and '
        'restores no cache of the package manager of its platform, also when '
        'it only looks a key up', () {
      const workflow = r'''
jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
      - uses: actions/cache/restore@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: gradle-${{ hashFiles('build/native_build/android.txt') }}
          lookup-only: true
  ios:
    runs-on: macos-26
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" ios_app
  macos:
    runs-on: macos-26
    steps:
      - run: dart test
''';
      expect(nativeCacheProblemsOf(workflow, file: 'apps.yml'), [
        equals(
          'apps.yml, job android generates an app with --create to build it '
          'for its platform, but restores no cache of Gradle (.gradle/): each '
          'job would download the same packages again.',
        ),
        startsWith(
          'apps.yml, job ios generates an app with --create to build it for '
          'its platform, but restores no cache of Swift Package Manager '
          '(org.swift.swiftpm):',
        ),
      ]);
    });

    test(
        'finds a step that saves the cache under a key that no step before it '
        'only looked up, as the jobs saved it before the writers looked their '
        'keys up', () {
      // Every job of the matrix saved the cache under the key of its app
      // when its build added more than a threshold to what it restored, and
      // a job may save it at the end, under its own key.
      const workflow = r'''
env:
  NATIVE_CACHE_SAVE_ABOVE_MB: 100
jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
      - run: dart tools/native_build.dart android "$RUNNER_TEMP/apps" build/native_build/android.txt
      - id: gradle
        uses: actions/cache/restore@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: ${{ runner.os }}-gradle-${{ hashFiles('build/native_build/android.txt') }}
          restore-keys: ${{ runner.os }}-gradle-
      - run: .github/scripts/each_app.sh "$RUNNER_TEMP/apps" flutter build apk --debug
      - id: gradle_added
        run: echo save=true >> "$GITHUB_OUTPUT"
      - name: Save the cache of Gradle
        if: steps.gradle_added.outputs.save == 'true'
        uses: actions/cache/save@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: ${{ steps.gradle.outputs.cache-primary-key }}
  at-the-end:
    runs-on: macos-26
    steps:
      - name: Cache Swift packages
        uses: actions/cache@v6
        with:
          path: ~/Library/Caches/org.swift.swiftpm
          key: swiftpm-${{ hashFiles('build/native_build/ios.txt') }}
  own-key:
    runs-on: macos-26
    steps:
      - name: Save the cache of Swift packages
        uses: actions/cache/save@v6
        with:
          path: ~/Library/Caches/org.swift.swiftpm
          key: swiftpm-${{ hashFiles('build/native_build/ios.txt') }}
''';
      expect(nativeCacheProblemsOf(workflow, file: 'apps.yml'), [
        equals(
          'apps.yml, job android, step "Save the cache of Gradle" saves the '
          'cache of Gradle under a key that no step before it only looked up. '
          'Look the key of the app of the job up before its build with '
          'actions/cache/restore and lookup-only: true, build from an empty '
          'cache when that step finds no entry, and save the cache only then, '
          r'with the key ${{ steps.<id>.outputs.cache-primary-key }} of that '
          'step: the jobs of the apps with every module write the entries of '
          'their families, and every other job only restores them.',
        ),
        startsWith(
          'apps.yml, job at-the-end, step "Cache Swift packages" saves the '
          'cache of Swift Package Manager under a key that no step before it '
          'only looked up.',
        ),
        startsWith(
          'apps.yml, job own-key, step "Save the cache of Swift packages" '
          'saves the cache of Swift Package Manager under a key that no step '
          'before it only looked up.',
        ),
      ]);
    });

    test(
        'finds a writer that saves when it found its key, in every run or '
        'after a build that failed, under a key without its app or the '
        'version of Flutter, and after it restored an older entry, and a step '
        'that reads a step that its job does not have', () {
      const flutter = r'${{ inputs.flutter_version }}';
      const android = r"${{ hashFiles('build/native_build/android.txt') }}";
      const ios = r"${{ hashFiles('build/native_build/ios.txt') }}";
      const bricks = r"${{ hashFiles('packages/*/bricks/**/android/**') }}";
      // A job that restores with the step of a writer, as a YAML anchor of a
      // writer gives it.
      const reader = r'''
  reader:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/start" start_app
      - name: Restore the cache of Gradle
        if: steps.gradle_lookup.outcome != 'success' || steps.gradle_lookup.outputs.cache-hit == 'true'
        uses: actions/cache/restore@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: gradle-${{ hashFiles('build/native_build/android.txt') }}
''';
      String writer(
        String job, {
        String runsOn = 'ubuntu-latest',
        String lookupIf = 'inputs.save_native_caches',
        String key = '\${{ runner.os }}-gradle-$flutter-$android',
        String restoreIf = "steps.lookup.outputs.cache-hit == 'true'",
        String saveIf = "steps.lookup.outcome == 'success' && "
            "steps.lookup.outputs.cache-hit != 'true'",
      }) {
        final path = runsOn.startsWith('macos')
            ? '~/Library/Caches/org.swift.swiftpm'
            : '~/.gradle/caches/modules-2';
        final platform = runsOn.startsWith('macos') ? 'ios' : 'android';
        return '''
  $job:
    runs-on: $runsOn
    strategy:
      matrix:
        app: \${{ fromJSON(needs.plan.outputs.apps) }}
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "\$APP" "\$RUNNER_TEMP/apps" app
      - run: dart tools/native_build.dart $platform "\$RUNNER_TEMP/apps" build/native_build/$platform.txt
      - id: lookup
        if: $lookupIf
        uses: actions/cache/restore@v6
        with:
          path: $path
          key: $key
          lookup-only: true
      - name: Restore the cache
        if: $restoreIf
        uses: actions/cache/restore@v6
        with:
          path: $path
          key: $key
          restore-keys: \${{ runner.os }}-
      - name: Save the cache
        if: $saveIf
        uses: actions/cache/save@v6
        with:
          path: $path
          key: \${{ steps.lookup.outputs.cache-primary-key }}
''';
      }

      final workflow = 'jobs:\n${[
        writer(
          'when-found',
          saveIf: "steps.lookup.outputs.cache-hit != 'true'",
        ),
        writer('when-not-run', saveIf: "steps.lookup.outcome == 'success'"),
        writer('every-run', lookupIf: 'inputs.flutter_version != ""'),
        writer(
          'some-jobs',
          lookupIf: 'inputs.save_native_caches && strategy.job-index == 0',
        ),
        writer(
          'after-failure',
          saveIf: "always() && steps.lookup.outcome == 'success' && "
              "steps.lookup.outputs.cache-hit != 'true'",
        ),
        writer('not-by-app', key: '\${{ runner.os }}-gradle-$flutter-$bricks'),
        writer('not-by-flutter', key: '\${{ runner.os }}-gradle-$android'),
        writer(
          'ios-not-by-flutter',
          runsOn: 'macos-26',
          key: '\${{ runner.os }}-swiftpm-$ios',
        ),
        writer('restores-older', restoreIf: "hashFiles('a') != ''"),
        reader,
      ].join()}';
      expect(nativeCacheProblemsOf(workflow, file: 'apps.yml'), [
        equals(
          'apps.yml, job when-found, step "Save the cache" saves the cache of '
          'Gradle also when the step lookup, which looks its key up, did not '
          "run or found it: save it only if: steps.lookup.outcome == 'success' "
          "&& steps.lookup.outputs.cache-hit != 'true'. An entry is never "
          'replaced under its key, and a job that does not write the cache '
          'saves nothing.',
        ),
        startsWith(
          'apps.yml, job when-not-run, step "Save the cache" saves the cache '
          'of Gradle also when the step lookup, which looks its key up, did '
          'not run or found it:',
        ),
        equals(
          'apps.yml, job every-run, step "Save the cache" saves the cache of '
          'Gradle in every run: keep the step lookup, which looks its key up, '
          'to the runs that the input save_native_caches lets save the native '
          'caches, which the workflows pass only for the runs on main, whose '
          'entries the runs of every branch find.',
        ),
        equals(
          'apps.yml, job some-jobs, step "Save the cache" saves the cache of '
          'Gradle only in some jobs of its matrix (the step lookup: if: '
          'inputs.save_native_caches && strategy.job-index == 0). The apps of '
          'the other jobs, such as those of a second provider of a role with '
          'native code, would download what their native stack adds in every '
          'run: let every job of the matrix write the entries of its family.',
        ),
        equals(
          'apps.yml, job after-failure, step "Save the cache" saves the cache '
          'of Gradle also after a build that failed (if: always() && '
          "steps.lookup.outcome == 'success' && "
          "steps.lookup.outputs.cache-hit != 'true'): a build that failed may "
          'have downloaded part of what the app needs, and the key would then '
          'stay taken by an entry that lacks the rest. Save it only after the '
          'steps before it succeeded.',
        ),
        equals(
          'apps.yml, job not-by-app, step "Save the cache" saves the cache of '
          r'Gradle under the key ${{ runner.os }}-gradle-${{ '
          r'inputs.flutter_version }}-${{ '
          "hashFiles('packages/*/bricks/**/android/**') }}, which does not "
          'depend on the app that the job builds. Take the key from the hash '
          'of the file that `dart tools/native_build.dart android <directory '
          'of apps> <file>` writes once the apps of the job are generated, so '
          'that the writer saves a new entry when its app builds with another '
          'plugin or another native project.',
        ),
        equals(
          'apps.yml, job not-by-flutter, step "Save the cache" saves the '
          r'cache of Gradle under the key ${{ runner.os }}-gradle-${{ '
          "hashFiles('build/native_build/android.txt') }}, which does not name "
          r'the version of Flutter, ${{ inputs.flutter_version }}. Gradle '
          'downloads the engine of Flutter too, hundreds of MB for each '
          'version, so a new version of Flutter needs a new entry.',
        ),
        equals(
          'apps.yml, job restores-older, step "Save the cache" saves the cache '
          'of Gradle after the step "Restore the cache", which restores an '
          'entry of it also when the step lookup found no entry under the key '
          'of the app: restore it only if: steps.lookup.outputs.cache-hit == '
          "'true', or when the step lookup did not run. The new entry would "
          'also hold what the builds of the entries before it downloaded, '
          'which no build may need any more, and grow with each one.',
        ),
        equals(
          'apps.yml, job reader, step "Restore the cache of Gradle" reads the '
          'step gradle_lookup, which its job does not have before it: GitHub '
          'reads such a step as nothing, and actionlint refuses it. Give a job '
          'without the step a step of its own, rather than the step of a job '
          'with it.',
        ),
      ]);
    });

    test(
        'finds a cache that jobs restore and no step saves, a cache that '
        'steps of several jobs save, a key without a text before its first '
        'expression, and a step that restores without the newest entry of '
        'its family and then of the platform', () {
      // As the workflow had it, a job that starts an app saves an entry of
      // its app too.
      final workflow = apps.replaceFirst(
        r'''
      - run: .github/scripts/each_app.sh "$RUNNER_TEMP/start" "$GITHUB_WORKSPACE/.github/scripts/start_app.sh" android emulator-5554 240
''',
        r'''
      - run: .github/scripts/each_app.sh "$RUNNER_TEMP/start" "$GITHUB_WORKSPACE/.github/scripts/start_app.sh" android emulator-5554 240
      - name: Save the cache of the started app
        uses: actions/cache/save@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: ${{ steps.gradle.outputs.cache-primary-key }}
''',
      ).replaceFirst(
        r'''
      - name: Save the cache of Swift packages
        if: >-
          steps.swiftpm_lookup.outcome == 'success' &&
          steps.swiftpm_lookup.outputs.cache-hit != 'true'
        uses: actions/cache/save@v6
        with:
          path: ~/Library/Caches/org.swift.swiftpm
          key: ${{ steps.swiftpm_lookup.outputs.cache-primary-key }}
''',
        '',
      );
      expect(
        nativeCacheWriterProblemsOf({'apps.yml': workflow, 'build.yml': build}),
        [
          equals(
            'Steps of several jobs save the cache of Gradle: apps.yml, job '
            'android; apps.yml, job android-start. The jobs of the matrix of '
            'the apps with every module write the entries of their families, '
            'and every other job only restores: the apps of the other jobs '
            'build with what an app with every module builds with, or with '
            'less, and their entries would take the place of the entries of '
            'the writers as the newest of the platform.',
          ),
          equals(
            'Jobs restore the cache of Swift Package Manager, but no step '
            'saves it: let the job of the first app with every module of the '
            'plan write it, in the runs on main, so that the jobs do not '
            'download the same packages in every run.',
          ),
        ],
      );

      final unprefixed = apps.replaceFirst(
        r'key: &gradle_key ${{ runner.os }}-gradle-',
        r"key: &gradle_key ${{ format('{0}-gradle-', runner.os) }}",
      );
      expect(
        nativeCacheWriterProblemsOf({
          'apps.yml': unprefixed,
          'build.yml': build,
        }),
        [
          startsWith(
            'apps.yml, job android, step "Save the cache of Gradle" saves the '
            r"cache of Gradle under the key ${{ format('{0}-gradle-', "
            r'runner.os) }}${{ inputs.flutter_version }}-',
          ),
        ],
      );

      // The restore keys of the platform alone, as the jobs had them when
      // one job wrote each cache, and of the platform before the family.
      const restoreKeys = r'''
          restore-keys: |
            macOS-swiftpm-${{ hashFiles("build/native_build/ios.txt") }}-
            macOS-swiftpm-
''';
      const platformFirst = r'''
          restore-keys: |
            macOS-swiftpm-
            macOS-swiftpm-${{ hashFiles("build/native_build/ios.txt") }}-
''';
      for (final keys in [
        '          restore-keys: macOS-swiftpm-\n',
        platformFirst,
      ]) {
        expect(
          nativeCacheWriterProblemsOf({
            'apps.yml': apps.replaceFirst(restoreKeys, keys),
            'build.yml': build,
          }),
          [
            equals(
              'apps.yml, job ios, step "Restore the cache of Swift packages" '
              'restores the cache of Swift Package Manager without the restore '
              r'keys macOS-swiftpm-${{ hashFiles("build/native_build/ios.txt") '
              '}}- and then macOS-swiftpm-: the newest entry of the family of '
              'its key, when the entry of the week is not there yet, and the '
              'newest entry of the platform, when no job writes the entries of '
              'its native stack.',
            ),
          ],
          reason: keys,
        );
      }
    });

    test(
        'finds a reusable workflow that saves the caches by default, a '
        'workflow that lets it save them in other runs than those on main, '
        'two workflows that let it save them, and a workflow that lets it '
        'save them without deleting the entries that a newer one replaced', () {
      final savingByDefault = apps.replaceFirst(
        'save_native_caches:\n        type: boolean\n        default: false',
        'save_native_caches:\n        type: boolean\n        default: true',
      );
      const pushes = r'''
jobs:
  apps:
    uses: ./.github/workflows/apps.yml
    with:
      save_native_caches: ${{ github.event_name == 'push' }}
''';
      const latest = r'''
jobs:
  apps:
    uses: ./.github/workflows/apps.yml
    with:
      save_native_caches: ${{ matrix.flutter == needs.versions.outputs.latest && github.ref == 'refs/heads/main' }}
''';
      expect(
        nativeCacheWriterProblemsOf({
          'apps.yml': savingByDefault,
          'build.yml': pushes,
          'nightly.yml': latest,
        }),
        [
          equals(
            'apps.yml lets its jobs save the caches of the native builds by '
            'default (save_native_caches: true), so a workflow that calls it '
            'without the input saves them in any run, such as that of a pull '
            'request: make it false by default, and let the workflow that '
            'calls it pass it for the runs on main.',
          ),
          equals(
            'build.yml, job apps calls apps.yml with save_native_caches: '
            r"${{ github.event_name == 'push' }}, which lets it save the "
            'caches of the native builds in other runs than those on main. A '
            'run of a pull request, or a run by hand on another branch, saves '
            'them for its own ref, where only its own later runs find them: '
            r"keep the input to ${{ github.ref == 'refs/heads/main' }}, with "
            'any other condition of the workflow.',
          ),
          equals(
            'build.yml, job apps lets apps.yml save the caches of the native '
            'builds, and so does nightly.yml. The writers of another workflow, '
            'such as the runs of other versions of Flutter, would add families '
            'of entries of their own, an entry of Gradle of 1.5 GB for each '
            'version of Flutter: let one workflow write them.',
          ),
          startsWith(
            'nightly.yml, job apps lets apps.yml save the caches of the native '
            'builds, and so does build.yml.',
          ),
          equals(
            'build.yml, job apps lets apps.yml save the caches of the native '
            'builds, but no job of build.yml deletes the entries that a newer '
            'one of their family replaced, of the keys that start with '
            'Linux-gradle- and macOS-swiftpm-. Each new entry would stay next '
            'to those before it, over 1 GB for Gradle, in the 10 GB of caches '
            'of the repository: delete each entry of a family but the newest '
            'with gh api --method DELETE '
            'repos/<repository>/actions/caches/<id>.',
          ),
          startsWith(
            'nightly.yml, job apps lets apps.yml save the caches of the native '
            'builds, but no job of nightly.yml deletes the entries that a '
            'newer one of their family replaced, of the keys that start with '
            'Linux-gradle- and macOS-swiftpm-.',
          ),
        ],
      );

      final gradleOnly = build.replaceFirst(
        'for prefix in Linux-gradle- macOS-swiftpm-; do',
        'for prefix in Linux-gradle-; do',
      );
      expect(
        nativeCacheWriterProblemsOf({
          'apps.yml': apps,
          'build.yml': gradleOnly,
        }),
        [
          startsWith(
            'build.yml, job apps lets apps.yml save the caches of the native '
            'builds, but no job of build.yml deletes the entries that a newer '
            'one of their family replaced, of the keys that start with '
            'macOS-swiftpm-. Each new entry',
          ),
        ],
      );
    });

    test(
        'finds the permission actions: write outside the job that deletes the '
        'entries of the caches, such a job with more permissions, and the jobs '
        'that build the apps with more than contents: read', () {
      final writing = apps
          .replaceFirst(
            'permissions:\n  contents: read',
            'permissions: write-all',
          )
          .replaceFirst(
            '  android-start:\n    runs-on: ubuntu-latest\n',
            '  android-start:\n    runs-on: ubuntu-latest\n'
                '    permissions:\n      actions: write\n',
          );
      final more = build.replaceFirst(
        '    permissions:\n      actions: write\n',
        '    permissions:\n      actions: write\n      contents: read\n',
      );
      expect(
        nativeCacheWriterProblemsOf({'apps.yml': writing, 'build.yml': more}),
        [
          equals(
            'apps.yml gives its jobs the permissions write-all rather than '
            'contents: read alone: its jobs build the apps with the code of '
            'their dependencies, and they only check out the repository. Set '
            'permissions: contents: read at its top.',
          ),
          equals(
            'apps.yml has the permission actions: write, but deletes no entry '
            'of the caches, the only job that needs it. The jobs that build '
            'the apps run the code of their dependencies, which must not get a '
            'token that can delete caches or start and cancel runs.',
          ),
          startsWith(
            'apps.yml, job android-start has the permission actions: write, '
            'but deletes no entry of the caches,',
          ),
          equals(
            'build.yml, job native-caches deletes entries of the caches with '
            'the permissions {actions: write, contents: read}: give it '
            'actions: write, and nothing else.',
          ),
        ],
      );

      // Without permissions of its own, its jobs get those of the job that
      // calls it.
      expect(
        nativeCacheWriterProblemsOf({
          'apps.yml': apps.replaceFirst('permissions:\n  contents: read\n', ''),
          'build.yml': build,
        }),
        [
          startsWith(
            'apps.yml gives its jobs the permissions of the workflow that '
            'calls it rather than contents: read alone:',
          ),
        ],
      );
    });
  });

  group('the mirror of Maven Central', () {
    test(
        'finds a job on Linux that restores the cache of Gradle, builds an '
        'app for Android or starts one there without the init script of the '
        'mirror, or puts it into ~/.gradle/init.d only after that', () {
      const workflow = r'''
jobs:
  cached:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --create --app "$APP" "$RUNNER_TEMP/apps" android_app
      - name: Restore the cache of Gradle
        uses: actions/cache/restore@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: gradle-${{ hashFiles('build/native_build/android.txt') }}
      - run: .github/scripts/each_app.sh "$RUNNER_TEMP/apps" flutter build apk --debug
  start:
    runs-on: ubuntu-latest
    steps:
      - name: Start the app on the Android emulator
        run: |
          .github/scripts/each_app.sh "$RUNNER_TEMP/apps" \
            "$GITHUB_WORKSPACE/.github/scripts/start_app.sh" android emulator-5554 240
  late:
    runs-on: ubuntu-latest
    steps:
      - name: Build the app bundle
        run: flutter build appbundle
      - run: |
          mkdir -p ~/.gradle/init.d
          cp .github/gradle/maven_central_mirror.gradle ~/.gradle/init.d/
''';
      expect(mavenCentralProblemsOf(workflow, file: 'apps.yml'), [
        equals(
          'apps.yml, job cached runs Gradle for Android from the step '
          '"Restore the cache of Gradle" on, but no step before it puts '
          '.github/gradle/maven_central_mirror.gradle into '
          '~/.gradle/init.d. Gradle would download from Maven Central what '
          'the cache that the job restored lacks, such as what its app needs '
          'beyond the cache of another app, and Maven Central answers 403 to '
          'a runner that downloads too much.',
        ),
        startsWith(
          'apps.yml, job start runs Gradle for Android from the step "Start '
          'the app on the Android emulator" on, but no step before it puts ',
        ),
        startsWith(
          'apps.yml, job late runs Gradle for Android from the step "Build '
          'the app bundle" on, but no step before it puts ',
        ),
      ]);
    });

    test(
        'passes a job that puts the init script into ~/.gradle/init.d before '
        'Gradle runs, and the jobs that build nothing for Android', () {
      const workflow = r'''
jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - &mirror
        name: Take the downloads of Gradle from the mirror of Maven Central
        run: |
          mkdir -p ~/.gradle/init.d
          cp .github/gradle/maven_central_mirror.gradle ~/.gradle/init.d/
      - uses: actions/cache/restore@v6
        with:
          path: ~/.gradle/caches/modules-2
          key: gradle-${{ hashFiles('build/native_build/android.txt') }}
      - run: .github/scripts/each_app.sh "$RUNNER_TEMP/apps" flutter build apk --debug
  start:
    runs-on: ubuntu-latest
    steps:
      - *mirror
      - run: .github/scripts/start_app.sh android emulator-5554 240
  matrix:
    runs-on: ubuntu-latest
    steps:
      - run: dart run packages/smf_flutter_cli/tool/matrix.dart --shard "$SHARD" "$RUNNER_TEMP/apps"
  ios:
    runs-on: macos-26
    steps:
      - run: .github/scripts/start_app.sh ios "$SIMULATOR" 240
  windows:
    runs-on: windows-latest
    steps:
      - run: flutter build apk --debug
''';
      expect(mavenCentralProblemsOf(workflow, file: 'apps.yml'), isEmpty);
    });
  });

  group('the builds for Android', () {
    test(
        'finds a step that runs flutter build apk itself, also for each app '
        'of a directory', () {
      const workflow = r'''
jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - name: Build the app for Android
        run: cd "$RUNNER_TEMP/apps/android_app" && flutter build apk --debug
      - run: .github/scripts/each_app.sh "$RUNNER_TEMP/apps" flutter build apk --debug
''';
      expect(apkBuildProblemsOf(workflow, file: 'apps.yml'), [
        equals(
          'apps.yml, job android, step "Build the app for Android" runs '
          'flutter build apk itself. Build with .github/scripts/build_apk.sh, '
          'which builds the app again when a package of the Android SDK did '
          'not download: the Gradle plugin of Android downloads the NDK of '
          'Flutter in each build of CI, and a download that breaks off fails '
          'the build.',
        ),
        startsWith(
          'apps.yml, job android, step ".github/scripts/each_app.sh '
          r'"$RUNNER_TEMP/apps" flutter build apk --debug" runs flutter '
          'build apk itself.',
        ),
      ]);
    });

    test(
        'passes the builds with the script, the other builds of flutter and '
        'the starts on Android, and takes a build with the script for one '
        'that needs the mirror of Maven Central', () {
      const workflow = r'''
jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - name: Build the app for Android
        run: .github/scripts/each_app.sh "$RUNNER_TEMP/apps" "$GITHUB_WORKSPACE/.github/scripts/build_apk.sh" --debug
      - run: .github/scripts/each_app.sh "$RUNNER_TEMP/apps" "$GITHUB_WORKSPACE/.github/scripts/start_app.sh" android emulator-5554 240
      - run: flutter build ios --simulator --debug
      - run: flutter analyze
''';
      expect(apkBuildProblemsOf(workflow, file: 'apps.yml'), isEmpty);
      expect(mavenCentralProblemsOf(workflow, file: 'apps.yml'), [
        startsWith(
          'apps.yml, job android runs Gradle for Android from the step '
          '"Build the app for Android" on, but no step before it puts ',
        ),
      ]);
    });
  });

  test(
      'finds the answers that a step or a script gives start_app.sh, also '
      'through a variable or an array, and those that no probe asks for', () {
    final text = workflow(r'''
      - name: Start
        env:
          ANSWER: from_env=dart test test/a_test.dart
        run: |
          answer="from_script=dart test test/b_test.dart"
          answers=()
          echo not_an_answer=1
          answers+=("from_array=cd 'a b' && dart test test/c_test.dart --file-reporter json:c.json")
          if [ -n "$A" ]; then answers+=("$nested"); fi
          nested="from_nested=dart test test/d_test.dart"
          .github/scripts/each_app.sh "$RUNNER_TEMP/apps" \
            "$GITHUB_WORKSPACE/.github/scripts/start_app.sh" android emulator-5554 240 \
            "firebase_messaging=dart test" "$ANSWER" "$answer" "${answers[@]}"
          other=x=y
      - name: Release
        run: .github/scripts/start_app.sh android emulator-5554 240 release
''');

    final answers = startAnswersOf(text, file: 'apps.yml');

    expect(answers, [
      for (final name in [
        'firebase_messaging',
        'from_env',
        'from_script',
        'from_array',
        'from_nested',
      ])
        ('apps.yml, job a, step "Start"', name),
    ]);
    expect(
      scriptStartAnswersOf(
        r'''
#!/usr/bin/env bash
"$(dirname "$0")/start_app.sh" ios "$1" 240 "push=dart test" "$@"
''',
        file: '.github/scripts/start.sh',
      ),
      [('.github/scripts/start.sh', 'push')],
    );
    String problem(String name) =>
        'apps.yml, job a, step "Start" gives start_app.sh the answer $name, '
        'which no probe of a matrix tool asks for (MatrixStartProbe.answer), '
        'so the script would skip it in every app: name the answer as the '
        'probe that asks for it does, one of firebase_messaging, from_array.';
    expect(
      answerProblemsOf(answers, {'firebase_messaging', 'from_array'}),
      [problem('from_env'), problem('from_script'), problem('from_nested')],
    );
  });

  test(
    'every answer that a workflow or a script of the repository gives '
    'start_app.sh is the answer of a probe of a matrix tool',
    () async {
      final root = repositoryRoot();
      final asked = {
        for (final tool in matrixTools.keys)
          for (final test in await appTestsListedBy(root, tool))
            if (test.answer case final answer?) answer,
      };
      final answers = [
        for (final entity in Directory('$root/.github/workflows').listSync())
          if (entity is File && RegExp(r'\.ya?ml$').hasMatch(entity.path))
            ...startAnswersOf(
              entity.readAsStringSync(),
              file: entity.uri.pathSegments.last,
            ),
        for (final entity in Directory('$root/.github/scripts').listSync())
          if (entity is File && RegExp(r'\.(sh|ps1)$').hasMatch(entity.path))
            ...scriptStartAnswersOf(
              entity.readAsStringSync(),
              file: '.github/scripts/${entity.uri.pathSegments.last}',
              powerShell: entity.path.endsWith('.ps1'),
            ),
      ];

      expect(answers, isNotEmpty);
      expect(answerProblemsOf(answers, asked), isEmpty);
    },
    // Each tool loads the modules of its matrix first, which takes a while
    // on the runners of CI.
    timeout: const Timeout(Duration(minutes: 5)),
  );

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
          ...mavenCentralProblemsOf(file.readAsStringSync(), file: name),
          ...apkBuildProblemsOf(file.readAsStringSync(), file: name),
        ],
        isEmpty,
        reason: name,
      );
    }
    expect(File('$root/$mavenCentralMirror').existsSync(), isTrue);
    expect(File('$root/$buildApk').existsSync(), isTrue);
    expect(
      nativeCacheWriterProblemsOf({
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
