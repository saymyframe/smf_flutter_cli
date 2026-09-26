import 'package:test/test.dart';

import 'banlist.dart';

/// The problems of [files] but the exceptions that match nothing, which a
/// few files cannot use.
List<String> _names(Map<String, String> files) => [
      for (final problem in problemsOf(files))
        if (!problem.startsWith('The exception')) problem,
    ];

void main() {
  test('finds banned names as words', () {
    expect(
      _names({
        'packages/a/lib/a.dart': 'final profile = ModuleProfile();\n'
            'final role = StateManagement();\n'
            'const kFirebaseAnalytics = 1;\n'
            'const kHomeModule = 2;\n'
            'const kModules = 3;\n'
            "const route = '/main-tabs';\n"
            "const other = '/main-tabs-2';\n"
            'final locator = GetIt.instance;\n'
            "import 'package:get_it/get_it.dart';\n",
        'packages/a/pubspec.yaml': 'dependencies:\n  get_it: ^9.0.0\n',
        'packages/a/bricks/b/__brick__/lib/b.dart': '{{app_name_sc}}\n',
      }),
      [
        'packages/a/lib/a.dart:1: ModuleProfile',
        'packages/a/lib/a.dart:3: kFirebase…',
        'packages/a/lib/a.dart:4: k…Module',
        'packages/a/lib/a.dart:6: main-tabs',
        'packages/a/lib/a.dart:8: GetIt',
        'packages/a/lib/a.dart:9: package:get_it',
        'packages/a/pubspec.yaml:2: get_it:',
        'packages/a/bricks/b/__brick__/lib/b.dart:1: {{app_name_sc}}',
      ],
    );
  });

  test('reads Dart code, pubspecs, templates and workflows only', () {
    expect(
      _names({
        'README.md': 'ModuleProfile',
        'packages/a/lib/bundles/b_bundle.dart': 'ModuleProfile',
        'packages/a/analysis_options.yaml': 'ModuleProfile',
        '.github/workflows/other.yml': 'melos run analyze:hooks',
        'packages/a/tool/run.dart': 'ModuleProfile',
      }),
      [
        '.github/workflows/other.yml:1: analyze:hooks',
        'packages/a/tool/run.dart:1: ModuleProfile',
      ],
    );
  });

  test('allows a name only in the files of its exceptions', () {
    const template =
        'packages/smf_contracts/bricks/di_role/__brick__/lib/di.dart';
    expect(
      _names({
        'packages/smf_modules/smf_get_it/lib/di.dart': 'GetIt getIt;',
        'packages/smf_contracts/lib/src/modules/profile.dart':
            'class ModuleProfile {}',
        'packages/smf_contracts/lib/src/lego/roles/di.dart':
            'class ModuleProfile {}',
        template: '{{app_name_sc}}',
        'packages/smf_contracts/pubspec.yaml':
            '  smf_contribution_engine: ^0.2.0\n  mustachex: ^1.0.0',
      }),
      [
        'packages/smf_contracts/lib/src/lego/roles/di.dart:1: ModuleProfile',
        '$template:1: {{app_name_sc}}',
        'packages/smf_contracts/pubspec.yaml:2: mustachex',
      ],
    );
  });

  test('reports every path of an exception that matches nothing', () {
    final problems = problemsOf({
      'packages/smf_modules/smf_event_bus/lib/a.dart': 'ModuleProfile',
    });

    expect(
      problems,
      contains(
        'The exception for packages/smf_modules/smf_firebase_analytics/ '
        'matches nothing; remove it from tools/banlist.dart.',
      ),
    );
    expect(
      problems,
      isNot(contains(contains('smf_event_bus/ matches nothing'))),
    );
  });
}
