// Checks that the workflows of GitHub Actions, and the scripts of
// .github/scripts that they run, choose the apps they check by role, rather
// than by hand, and know no module but in its own tests.
//
// A module is independent of the others, and a role may get another
// provider at any time, such as a second app entry, which owns the Android
// and Xcode projects. So the workflows take the apps they generate, build
// and start from the matrix tools, which give one app with every module for
// each combination of the providers of the roles that take one, and a new
// provider gets its app without a change of the workflows. The check fails
// when a step of a workflow, or a script of .github/scripts:
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
    'Configure the apps with every module with Firebase for Android',
    'smf_firebase_core',
  ): 'The test of firebase_core that configures each app with Firebase '
      'with the command of its README, before CI starts it.',
  (
    'Configure the apps with every module with Firebase for iOS',
    'smf_firebase_core',
  ): 'The test of firebase_core that configures each app with Firebase '
      'with the command of its README, before CI starts it.',
  ('Archive the apps with every module', 'smf_firebase_core'):
      'The test of firebase_core that archives each app with the build '
          'phase for Crashlytics fixed by the command of its README.',
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
    'every role, and one app for each combination of the providers of the '
    'roles that take one.';

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
    switch (_argumentsOfTool(words, isTool)) {
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
    switch (_argumentsOfTool(words, isTool)) {
      ['--create', '--without-external-steps', _, final name, ...] => name,
      ['--create', _, final name, ...] => name,
      _ => null,
    };

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
      - name: Archive the apps with every module
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
          'apps.yml, job a, step "Archive the apps with every module" refers '
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
      'the workflows and the scripts of the repository choose their apps by '
      'role, and each exception applies to one of their steps', () {
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
        problemsOf(file.readAsStringSync(), file: name, used: used),
        isEmpty,
        reason: name,
      );
    }
    for (final file in scripts) {
      final name = '.github/scripts/${file.uri.pathSegments.last}';
      expect(
        scriptProblemsOf(
          file.readAsStringSync(),
          file: name,
          powerShell: name.endsWith('.ps1'),
        ),
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
