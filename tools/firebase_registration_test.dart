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
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The workflow that may register the apps of CI.
const registering = 'build.yml';

/// The test of firebase_core that configures an app with flutterfire.
const _test = 'test/flutterfire_configure_test.dart';

/// The problems of [workflows], the texts of the workflows of GitHub
/// Actions by their file names: a step that runs the test that configures
/// the apps with Firebase without SMF_FIREBASE_REGISTER from the input
/// register_firebase_apps of its workflow, a workflow with such steps
/// without the input or with the input true by default, a workflow other
/// than [registering] that calls it with the input, and [registering]
/// calling it without the input true.
List<String> problemsOf(Map<String, String> workflows) {
  final problems = <String>[];
  final roots = {
    for (final MapEntry(:key, :value) in workflows.entries)
      key: loadYaml(value) as YamlMap,
  };
  // The workflows whose steps run the test.
  final configuring = <String>{};
  for (final MapEntry(key: file, value: root) in roots.entries) {
    for (final MapEntry(key: job, :value) in _jobsOf(root)) {
      for (final step in _stepsOf(value)) {
        if (!'${step['run']}'.contains(_test)) continue;
        configuring.add(file);
        final register = switch (step['env']) {
          {'SMF_FIREBASE_REGISTER': final Object value} => '$value',
          _ => '',
        };
        if (!register.contains('inputs.register_firebase_apps')) {
          problems.add(
            '$file, job $job, step "${step['name']}" runs $_test without '
            'SMF_FIREBASE_REGISTER from the input register_firebase_apps of '
            'the workflow, which only $registering sets.',
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
          '$file runs $_test, but has no input register_firebase_apps, which '
          'only $registering sets.',
        );
    }
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
          'apps.yml runs test/flutterfire_configure_test.dart, but has no '
          'input register_firebase_apps, which only build.yml sets.',
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
    expect(problemsOf(workflows), isEmpty);
  });
}
