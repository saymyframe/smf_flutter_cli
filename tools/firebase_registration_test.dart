// Checks that only the workflow Build lets the test of firebase_core that
// configures the apps of CI with flutterfire register their Firebase apps
// in the Firebase project of CI.
//
// flutterfire registers the Firebase app of an app in the project when the
// project has none with the id of the app. Two runs that configure a new
// app at once, such as the jobs of the nightly run for each version of
// Flutter, could register one each, and the test fails in every later run
// on a project with several apps with one id. So a reusable workflow whose
// steps run the test gives it SMF_FIREBASE_REGISTER from its input
// register_firebase_apps, false unless a caller sets it, and only build.yml
// sets it: its run of the pull request that brings a new provider
// registers the apps of the provider, one job for each platform. In any
// other run, the test fails early when the project has no app with the id.
//
// The test of firebase_auth that enables the sign-in methods of an app in
// the project writes to the project too, in the run that gets
// SMF_FIREBASE_ENABLE_SIGN_IN=1, and only asks the project for them in
// every other. The Firebase CLI enables the methods through a web app of
// the project, and adds one to a project that has none. So the check holds
// that variable to the same input, and SMF_FIREBASE_REGISTER of such a
// step too, by which the test lets the Firebase CLI add the web app. It
// also fails when more than one job gives the test the variable, and when
// the job that gives it has a matrix and does not keep it to its first
// job, with `strategy.job-index == 0`: two jobs would write to the project
// at once.
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The workflow that may register the apps of CI.
const registering = 'build.yml';

/// The test of firebase_core that configures an app with flutterfire.
const _test = 'test/flutterfire_configure_test.dart';

/// The test of firebase_auth that asks the project of an app for its
/// sign-in methods, and enables them first in the run that gets [_enable].
const _signInTest = 'test/enable_sign_in_test.dart';

/// The variable with which a step lets [_signInTest] enable the sign-in
/// methods in the project.
const _enable = 'SMF_FIREBASE_ENABLE_SIGN_IN';

/// The variable with which a step lets a test register an app in the
/// project.
const _register = 'SMF_FIREBASE_REGISTER';

/// The input of a workflow from which a step takes [_register] and
/// [_enable].
const _input = 'inputs.register_firebase_apps';

/// What keeps [_enable] to the first job of a matrix.
const _firstJob = 'strategy.job-index == 0';

/// The problems of [workflows], the texts of the workflows of GitHub
/// Actions by their file names:
/// - a step that runs the test that configures the apps with Firebase
///   without SMF_FIREBASE_REGISTER from the input register_firebase_apps of
///   its workflow;
/// - a step that runs the test of the sign-in methods with
///   SMF_FIREBASE_REGISTER or SMF_FIREBASE_ENABLE_SIGN_IN that is not from
///   that input, a second job that gives that test
///   SMF_FIREBASE_ENABLE_SIGN_IN, and a job with a matrix that gives it in
///   more than its first job;
/// - a workflow with steps that may write to the project without the
///   input, or with the input true by default;
/// - a workflow other than [registering] that calls it with the input, and
///   [registering] calling it without the input true.
List<String> problemsOf(Map<String, String> workflows) {
  final problems = <String>[];
  final roots = {
    for (final MapEntry(:key, :value) in workflows.entries)
      key: loadYaml(value) as YamlMap,
  };
  // The workflows whose steps may write to the project.
  final configuring = <String>{};
  // The steps that let the test of the sign-in methods enable them.
  final enabling = <String>[];
  for (final MapEntry(key: file, value: root) in roots.entries) {
    for (final MapEntry(key: job, :value) in _jobsOf(root)) {
      for (final step in _stepsOf(value)) {
        final run = '${step['run']}';
        final where = '$file, job $job, step "${step['name']}"';
        final register = _variableOf(step, _register);
        if (run.contains(_test)) {
          configuring.add(file);
          if (!register.contains(_input)) {
            problems.add(
              '$where runs $_test without $_register from the input '
              'register_firebase_apps of the workflow, which only '
              '$registering sets.',
            );
          }
        }
        if (!run.contains(_signInTest)) continue;
        if (_lets(register) && !register.contains(_input)) {
          problems.add(
            '$where runs $_signInTest with $_register that is not from the '
            'input register_firebase_apps of the workflow, which only '
            '$registering sets: the Firebase CLI would add a web app to the '
            'Firebase project of CI in any run.',
          );
        }
        final enable = _variableOf(step, _enable);
        if (!_lets(enable)) continue;
        configuring.add(file);
        enabling.add(where);
        if (!enable.contains(_input)) {
          problems.add(
            '$where runs $_signInTest with $_enable that is not from the '
            'input register_firebase_apps of the workflow, which only '
            '$registering sets: every run would enable the sign-in methods '
            'in the Firebase project of CI.',
          );
        }
        if (_hasMatrix(value) && !enable.contains(_firstJob)) {
          problems.add(
            '$where gives $_signInTest $_enable in every job of the matrix '
            'of its job, which would enable the sign-in methods in the '
            'Firebase project of CI at once. Keep it to the first one, with '
            '`$_firstJob`.',
          );
        }
      }
    }
    if (!configuring.contains(file)) continue;
    switch (root['on']) {
      case {
          'workflow_call': {
            'inputs': {'register_firebase_apps': final YamlMap input},
          },
        }:
        if (input['default'] == true) {
          problems.add(
            '$file sets its input register_firebase_apps by default, which '
            'only $registering may set.',
          );
        }
      default:
        problems.add(
          '$file has steps that may write to the Firebase project of CI, but '
          'has no input register_firebase_apps, which only $registering '
          'sets.',
        );
    }
  }
  for (final where in enabling.skip(1)) {
    problems.add(
      '$where gives $_signInTest $_enable, as ${enabling.first} does: two '
      'jobs would enable the sign-in methods in the Firebase project of CI '
      'at once. Only one job enables them, and the others ask the project '
      'for them.',
    );
  }
  for (final MapEntry(key: file, value: root) in roots.entries) {
    for (final MapEntry(key: job, :value) in _jobsOf(root)) {
      if (value is! YamlMap) continue;
      final called = '${value['uses'] ?? ''}'.split('/').last;
      if (!configuring.contains(called)) continue;
      final register = switch (value['with']) {
        {'register_firebase_apps': final Object register} => register,
        _ => null,
      };
      if (file == registering && register != true) {
        problems.add(
          '$file, job $job calls $called without register_firebase_apps: '
          'true, so no run registers the apps of a new provider in the '
          'Firebase project of CI.',
        );
      } else if (file != registering && register != null && register != false) {
        problems.add(
          '$file, job $job calls $called with register_firebase_apps, which '
          'only $registering may set: runs at the same time, such as those '
          'of each version of Flutter, would register an app each.',
        );
      }
    }
  }
  return problems;
}

Iterable<MapEntry<Object?, Object?>> _jobsOf(YamlMap root) =>
    (root['jobs'] as YamlMap).entries;

Iterable<YamlMap> _stepsOf(Object? job) => switch (job) {
      {'steps': final YamlList steps} => steps.cast<YamlMap>(),
      _ => const [],
    };

/// The value that [step] gives the variable [name] in its `env`, as text,
/// or an empty text when it gives none.
String _variableOf(YamlMap step, String name) => switch (step['env']) {
      final YamlMap env when env.containsKey(name) => '${env[name]}'.trim(),
      _ => '',
    };

/// Whether [value], what a step gives a variable that lets a test write to
/// the project when it is 1, may be 1: it is not empty, and no text that is
/// never 1, such as 0.
bool _lets(String value) => !const {'', '0', 'false'}.contains(value);

/// Whether [job] runs once for each item of a matrix.
bool _hasMatrix(Object? job) => switch (job) {
      {'strategy': {'matrix': final Object _}} => true,
      _ => false,
    };

void main() {
  const reusable = r'''
on:
  workflow_call:
    inputs:
      register_firebase_apps:
        type: boolean
        default: false
jobs:
  linux:
    steps:
      - name: Configure for Android
        env:
          SMF_FIREBASE_REGISTER: ${{ inputs.register_firebase_apps && '1' || '0' }}
        run: each_app.sh --env SMF_FIREBASE_APP "$apps" dart test test/flutterfire_configure_test.dart
''';

  /// The jobs of a reusable workflow that run the test of the sign-in
  /// methods: one on Linux, with a matrix, whose first job enables them,
  /// and one on macOS, which only asks the project.
  const signIn = r'''
on:
  workflow_call:
    inputs:
      register_firebase_apps:
        type: boolean
        default: false
jobs:
  linux:
    strategy:
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.entries) }}
    steps:
      - name: Enable the sign-in methods
        env:
          SMF_FIREBASE_REGISTER: ${{ inputs.register_firebase_apps && '1' || '0' }}
          SMF_FIREBASE_ENABLE_SIGN_IN: ${{ inputs.register_firebase_apps && strategy.job-index == 0 && '1' || '0' }}
        run: each_app.sh --env SMF_CONFIGURED_APP "$apps" dart test test/enable_sign_in_test.dart
  macos:
    strategy:
      matrix:
        app: ${{ fromJSON(needs.plan.outputs.entries) }}
    steps:
      - name: Check the sign-in methods
        env:
          SMF_FIREBASE_PROJECT: saymyframe-app-cli
        run: each_app.sh --env SMF_CONFIGURED_APP "$apps" dart test test/enable_sign_in_test.dart
''';
  const build = '''
jobs:
  apps:
    uses: ./.github/workflows/apps.yml
    with:
      register_firebase_apps: true
''';
  const nightly = '''
jobs:
  apps:
    uses: ./.github/workflows/apps.yml
    with:
      published_cli: true
''';

  test(
      'passes when only build.yml lets the steps that configure the apps '
      'register them', () {
    expect(
      problemsOf({
        'apps.yml': reusable,
        'build.yml': build,
        'nightly.yml': nightly,
      }),
      isEmpty,
    );
  });

  test('finds a step that configures the apps without the input', () {
    expect(
      problemsOf({
        'apps.yml': reusable.replaceFirst(
          RegExp('SMF_FIREBASE_REGISTER: .*'),
          'A: "1"',
        ),
        'build.yml': build,
      }),
      [
        equals(
          'apps.yml, job linux, step "Configure for Android" runs '
          'test/flutterfire_configure_test.dart without '
          'SMF_FIREBASE_REGISTER from the input register_firebase_apps of '
          'the workflow, which only build.yml sets.',
        ),
      ],
    );
  });

  test('finds a workflow of such steps without the input, or true by default',
      () {
    expect(
      problemsOf({
        'apps.yml': reusable.replaceFirst('register_firebase_apps:', 'x:'),
        'build.yml': build,
      }),
      [
        equals(
          'apps.yml has steps that may write to the Firebase project of CI, '
          'but has no input register_firebase_apps, which only build.yml '
          'sets.',
        ),
      ],
    );
    expect(
      problemsOf({
        'apps.yml': reusable.replaceFirst('default: false', 'default: true'),
        'build.yml': build,
      }),
      [
        equals(
          'apps.yml sets its input register_firebase_apps by default, which '
          'only build.yml may set.',
        ),
      ],
    );
  });

  test(
      'finds a workflow other than build.yml that sets the input, and '
      'build.yml without it', () {
    expect(
      problemsOf({
        'apps.yml': reusable,
        'build.yml': nightly,
        'nightly.yml': build,
        'other.yml': build.replaceFirst(
          'true',
          r"${{ github.event_name == 'push' }}",
        ),
      }),
      [
        equals(
          'build.yml, job apps calls apps.yml without register_firebase_apps: '
          'true, so no run registers the apps of a new provider in the '
          'Firebase project of CI.',
        ),
        startsWith(
          'nightly.yml, job apps calls apps.yml with register_firebase_apps, '
          'which only build.yml may set:',
        ),
        startsWith(
          'other.yml, job apps calls apps.yml with register_firebase_apps,',
        ),
      ],
    );
  });

  group('the test of the sign-in methods', () {
    const step = 'apps.yml, job linux, step "Enable the sign-in methods"';
    const enable = r'SMF_FIREBASE_ENABLE_SIGN_IN: ${{ '
        "inputs.register_firebase_apps && strategy.job-index == 0 && '1' || "
        "'0' }}";

    test(
        'passes when one job enables the methods, in the first job of its '
        'matrix and only when build.yml lets it, and the others only ask', () {
      expect(
        problemsOf({'apps.yml': signIn, 'build.yml': build, 'n.yml': nightly}),
        isEmpty,
      );
      // A job that is told never to enable them is one that only asks.
      for (final never in ["'0'", '0', 'false', '""']) {
        expect(
          problemsOf({
            'apps.yml': signIn.replaceFirst(
              'SMF_FIREBASE_PROJECT: saymyframe-app-cli',
              'SMF_FIREBASE_ENABLE_SIGN_IN: $never',
            ),
            'build.yml': build,
          }),
          isEmpty,
          reason: never,
        );
      }
    });

    test('finds a step that enables the methods in every run', () {
      expect(signIn, contains(enable));
      for (final always in ["'1'", '1', r'${{ matrix.enables }}']) {
        expect(
          problemsOf({
            'apps.yml': signIn.replaceFirst(
              enable,
              'SMF_FIREBASE_ENABLE_SIGN_IN: $always',
            ),
            'build.yml': build,
          }),
          [
            equals(
              '$step runs test/enable_sign_in_test.dart with '
              'SMF_FIREBASE_ENABLE_SIGN_IN that is not from the input '
              'register_firebase_apps of the workflow, which only build.yml '
              'sets: every run would enable the sign-in methods in the '
              'Firebase project of CI.',
            ),
            startsWith(
              '$step gives test/enable_sign_in_test.dart '
              'SMF_FIREBASE_ENABLE_SIGN_IN in every job of the matrix of its '
              'job,',
            ),
          ],
          reason: always,
        );
      }
    });

    test(
        'finds a step that lets the Firebase CLI add a web app in every '
        'run', () {
      expect(
        problemsOf({
          'apps.yml': signIn.replaceFirst(
            RegExp('SMF_FIREBASE_REGISTER: .*'),
            'SMF_FIREBASE_REGISTER: "1"',
          ),
          'build.yml': build,
        }),
        [
          equals(
            '$step runs test/enable_sign_in_test.dart with '
            'SMF_FIREBASE_REGISTER that is not from the input '
            'register_firebase_apps of the workflow, which only build.yml '
            'sets: the Firebase CLI would add a web app to the Firebase '
            'project of CI in any run.',
          ),
        ],
      );
    });

    test(
        'finds a job with a matrix that enables the methods in more than '
        'its first job, and passes one without a matrix', () {
      final everyJob = signIn.replaceFirst(
        ' && strategy.job-index == 0',
        '',
      );

      expect(problemsOf({'apps.yml': everyJob, 'build.yml': build}), [
        equals(
          '$step gives test/enable_sign_in_test.dart '
          'SMF_FIREBASE_ENABLE_SIGN_IN in every job of the matrix of its '
          'job, which would enable the sign-in methods in the Firebase '
          'project of CI at once. Keep it to the first one, with '
          '`strategy.job-index == 0`.',
        ),
      ]);
      expect(
        problemsOf({
          'apps.yml': everyJob.replaceFirst(
            RegExp(r'    strategy:\n      matrix:\n.*\n'),
            '',
          ),
          'build.yml': build,
        }),
        isEmpty,
      );
    });

    test('finds a second job that enables the methods', () {
      expect(
        problemsOf({
          'apps.yml': signIn.replaceFirst(
            'SMF_FIREBASE_PROJECT: saymyframe-app-cli',
            enable,
          ),
          'build.yml': build,
        }),
        [
          equals(
            'apps.yml, job macos, step "Check the sign-in methods" gives '
            'test/enable_sign_in_test.dart SMF_FIREBASE_ENABLE_SIGN_IN, as '
            '$step does: two jobs would enable the sign-in methods in the '
            'Firebase project of CI at once. Only one job enables them, and '
            'the others ask the project for them.',
          ),
        ],
      );
    });

    test(
        'finds a workflow whose step enables the methods without the '
        'input, and a workflow other than build.yml that sets the input', () {
      expect(
        problemsOf({
          'apps.yml': signIn.replaceFirst('register_firebase_apps:', 'x:'),
          'build.yml': build,
        }),
        [
          equals(
            'apps.yml has steps that may write to the Firebase project of '
            'CI, but has no input register_firebase_apps, which only '
            'build.yml sets.',
          ),
        ],
      );
      expect(
        problemsOf({'apps.yml': signIn, 'build.yml': nightly, 'n.yml': build}),
        [
          startsWith(
            'build.yml, job apps calls apps.yml without '
            'register_firebase_apps: true,',
          ),
          startsWith(
            'n.yml, job apps calls apps.yml with register_firebase_apps, '
            'which only build.yml may set:',
          ),
        ],
      );
    });
  });

  test('only build.yml lets the workflows of the repository register the apps',
      () {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    expect(top.exitCode, 0, reason: '${top.stderr}');
    final workflows = {
      for (final entity
          in Directory('${'${top.stdout}'.trim()}/.github/workflows')
              .listSync())
        if (entity is File && entity.path.endsWith('.yml'))
          entity.uri.pathSegments.last: entity.readAsStringSync(),
    };

    expect(workflows.keys, containsAll(['apps.yml', registering]));
    expect(
      [
        for (final text in workflows.values)
          if (text.contains(_test)) text,
      ],
      isNotEmpty,
    );
    // One step lets the test of the sign-in methods enable them, and
    // another runs the test only to ask the project.
    final signInSteps = [
      for (final text in workflows.values)
        for (final MapEntry(:value) in _jobsOf(loadYaml(text) as YamlMap))
          for (final step in _stepsOf(value))
            if ('${step['run']}'.contains(_signInTest))
              _lets(_variableOf(step, _enable)),
    ];
    expect(signInSteps.where((enables) => enables), hasLength(1));
    expect(signInSteps.where((enables) => !enables), isNotEmpty);
    expect(problemsOf(workflows), isEmpty);
  });
}
