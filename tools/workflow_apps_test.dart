// Checks that the workflows of GitHub Actions choose the apps they check by
// role, rather than by hand, and know no module but in its own tests.
//
// A module is independent of the others, and a role may get another
// provider at any time, such as a second app entry, which owns the Android
// and Xcode projects. So the workflows take the apps they generate, build
// and start from the matrix tools, which give one app with every module for
// each combination of the providers of the roles that take one, and a new
// provider gets its app without a change of the workflows. The check fails
// when a step of a workflow:
// - selects an app of a matrix tool by its name, such as
//   'every module (bloc)', which names the provider of each role that has
//   several and changes when another role gets a second provider; the
//   tools select them with --every-module, or generate them with --create;
// - names the modules of an app by hand with -m, which a second provider of
//   a role that every app has turns into an error, and which leaves out the
//   providers it does not name;
// - refers to the package of a module, but in a step that runs the tests of
//   that module.
// A step that must do one of these is an exception below, with the reason.
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The steps that may name the modules of an app with -m, by the name of
/// the step, with the reason.
const namedModules = {
  'Generate the apps with every module with the CLI from pub.dev':
      'The CLI from pub.dev has the modules of its release, which may differ '
          'from those of the workspace, and no tool that lists them. The '
          'matrix of the workspace checked every combination of their '
          'providers before the release; the step checks what only an '
          'install from pub.dev has, with a selection of modules as a user '
          'makes it.',
};

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
/// name, that name the modules of an app with -m, and that refer to the
/// package of a module, other than the exceptions [namedModules] and
/// [modulePaths] allow. The exceptions that apply to a step go into [used].
List<String> problemsOf(
  String workflow, {
  required String file,
  Set<Object>? used,
}) {
  final problems = <String>[];
  final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
  for (final MapEntry(key: job, :value) in jobs.entries) {
    final steps = (value as YamlMap)['steps'] as YamlList? ?? YamlList();
    for (final step in steps.cast<YamlMap>()) {
      final name = '${step['name'] ?? step['uses'] ?? step['run']}';
      final where = '$file, job $job, step "$name"';
      final run = '${step['run'] ?? ''}';
      for (final words in commandsOf(run)) {
        final names = _namesOfApps(words);
        if (names.isNotEmpty) {
          problems.add(
            '$where selects apps of a matrix tool by name: '
            '${names.join(', ')}. Select the apps with every module with '
            '--every-module, or generate them with --create.',
          );
        }
        if (words.any(_isModulesOption)) {
          if (namedModules.containsKey(name)) {
            used?.add(name);
          } else {
            problems.add(
              '$where names the modules of an app with -m. Generate the '
              'apps with the --create of '
              'packages/smf_flutter_cli/tool/matrix.dart, which names a '
              'provider of every role, and one app for each combination of '
              'the providers of the roles that take one.',
            );
          }
        }
      }
      for (final package in _modulePackages(step)) {
        final exception = (name, package);
        if (!modulePaths.containsKey(exception)) {
          problems.add(
            '$where refers to the package $package of a module. Only a step '
            'that runs the tests of the module may, as an exception of '
            'tools/workflow_apps_test.dart with its reason.',
          );
        } else if (!run.contains('dart test')) {
          problems.add(
            '$where refers to the package $package of a module, but runs '
            'no test of it with dart test.',
          );
        } else {
          used?.add(exception);
        }
      }
    }
  }
  return problems;
}

/// The words of each command of [script], a script of bash or PowerShell,
/// as far as the check needs them: the words in quotes without the quotes,
/// the lines that end with `\` or a backtick joined with the next, and a
/// command ended by a new line, `;`, `|`, `&`, a parenthesis, a brace or a
/// redirection. Comments stay out.
List<List<String>> commandsOf(String script) {
  final text = script.replaceAll(RegExp(r'[\\`]\r?\n'), ' ');
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
          (char == r'\' || char == '`') &&
          i + 1 < text.length) {
        word.write(text[++i]);
      } else {
        word.write(char);
      }
    } else if (char == '"' || char == "'") {
      quote = char;
      inWord = true;
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

/// The names of apps that the command [words] gives a matrix tool, if it
/// runs one: the arguments after its directory, or after the directory of
/// --every-module.
List<String> _namesOfApps(List<String> words) {
  final tool = words.indexWhere(
    (word) => RegExp(r'tool[/\\]matrix\.dart$').hasMatch(word),
  );
  if (tool < 0) return const [];
  return switch (words.sublist(tool + 1)) {
    ['--every-module', _, ...final names] => names,
    [final directory, ...final names] when !directory.startsWith('-') => names,
    _ => const [],
  };
}

/// Whether [word] is the option of `smf create` that names the modules.
bool _isModulesOption(String word) =>
    word == '-m' || word == '--modules' || word.startsWith('--modules=');

/// The packages of modules that [step] refers to by path in its command,
/// its working directory, its environment and its inputs: a directory
/// right in packages/smf_modules, but not a pattern for any of them.
Set<String> _modulePackages(YamlMap step) {
  final texts = [
    step['run'],
    step['working-directory'],
    if (step['env'] case final YamlMap env) ...env.values,
    if (step['with'] case final YamlMap inputs) ...inputs.values,
  ];
  return {
    for (final text in texts)
      for (final match in RegExp(r'packages[/\\]smf_modules[/\\](\w+)')
          .allMatches('${text ?? ''}'))
        match[1]!,
  };
}

void main() {
  String workflow(String steps) => 'jobs:\n  a:\n    steps:\n$steps';

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
          dart run packages/smf_flutter_cli/tool/matrix.dart --create --without-external-steps "$apps" start_app > out
          for app in "$apps"/*/; do
            dart run packages/smf_flutter_cli/tool/matrix.dart --add-app-tests \
              "${app%/}" packages/smf_flutter_cli/app_tests/start
          done
          matrix="$(dart run packages/smf_flutter_cli/tool/matrix.dart --app-tests)"
'''),
          file: 'apps.yml',
        ),
        isEmpty,
      );
    });
  });

  test('finds a step that names the modules of an app by hand', () {
    final used = <Object>{};

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
      - name: Generate the apps with every module with the CLI from pub.dev
        run: |
          for state in bloc riverpod; do
            smf create "${state}_app" -m "go_router,$state" --no-input
          done
'''),
        file: 'apps.yml',
        used: used,
      ),
      [
        startsWith(
          'apps.yml, job a, step "Build an app with every module for '
          'Android" names the modules of an app with -m. Generate the apps '
          'with the --create of packages/smf_flutter_cli/tool/matrix.dart,',
        ),
        startsWith('apps.yml, job a, step "macOS" names the modules'),
        startsWith('apps.yml, job a, step "Probe" names the modules'),
      ],
    );
    expect(used, {
      'Generate the apps with every module with the CLI from pub.dev',
    });
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

  test(
      'the workflows of the repository choose their apps by role, and each '
      'exception applies to one of their steps', () {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    expect(top.exitCode, 0, reason: '${top.stderr}');
    final root = '${top.stdout}'.trim();
    final files = [
      for (final entity in Directory('$root/.github/workflows').listSync())
        if (entity is File && RegExp(r'\.ya?ml$').hasMatch(entity.path)) entity,
    ];
    expect(files, isNotEmpty);
    final used = <Object>{};

    for (final file in files) {
      final name = file.uri.pathSegments.last;
      expect(
        problemsOf(file.readAsStringSync(), file: name, used: used),
        isEmpty,
        reason: name,
      );
    }
    expect(
      {...namedModules.keys, ...modulePaths.keys}.difference(used),
      isEmpty,
      reason: 'An exception that applies to no step is left over: remove it.',
    );
  });
}
