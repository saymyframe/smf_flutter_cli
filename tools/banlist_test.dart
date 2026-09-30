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
            "import 'package:get_it/get_it.dart';\n"
            'final file = kind.compositionFile;\n'
            'final path = kind.compositionFileOf(home);\n'
            "const rule = CompositionFile('lib/a.dart');\n",
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
        'packages/a/lib/a.dart:10: compositionFile',
        'packages/a/lib/a.dart:11: compositionFileOf',
        'packages/a/pubspec.yaml:2: get_it:',
        'packages/a/bricks/b/__brick__/lib/b.dart:1: {{app_name_sc}}',
      ],
    );
  });

  test('finds "by itself" in a line that does not say "only"', () {
    expect(
      _names({
        'packages/a/README.md':
            'When a feature needs a router, `smf create` adds it by itself.\n'
                '`smf create` adds it by itself if it is the only module that '
                'provides the router, and asks otherwise.\n'
                'It commonly adds it by itself.\n',
      }),
      [
        'packages/a/README.md:1: "by itself" without "only"',
        'packages/a/README.md:3: "by itself" without "only"',
      ],
    );
  });

  test(
      'finds the key of the members of the workspace that code looks up or '
      'matches, but in tools/workspace_members.dart, which reads them', () {
    expect(
      _names({
        'tools/a.dart': "if (line == 'workspace:') inWorkspace = true;\n"
            "final members = pubspec['workspace'];\n"
            'final key = RegExp(r"^workspace:\\s*\$");\n'
            // The text of a pubspec in a test, and other names.
            "const pubspec = 'name: root\\n' 'workspace:\\n';\n"
            "const other = 'workspace: # The packages.\\n';\n"
            "const names = ['workspaces', 'my_workspace'];\n",
        'tools/workspace_members.dart':
            "final workspace = pubspec.nodes['workspace'];\n",
        'pubspec.yaml': 'workspace:\n  - packages/a\n',
        'README.md': 'The `workspace:` of the root pubspec lists them.\n',
      }),
      [
        'tools/a.dart:1: workspace: read by hand',
        'tools/a.dart:2: workspace: read by hand',
        'tools/a.dart:3: workspace: read by hand',
      ],
    );
  });

  test('reads Dart code, pubspecs, templates, workflows and Markdown only', () {
    expect(
      _names({
        'README.md': 'ModuleProfile',
        'packages/a/README.md': 'Use `-s bloc` with kBlocStateManagement.',
        // Changelogs record what the packages had.
        'CHANGELOG.md': 'ModuleProfile',
        'packages/a/CHANGELOG.md': 'ModuleProfile',
        'packages/a/lib/bundles/b_bundle.dart': 'ModuleProfile',
        'packages/a/analysis_options.yaml': 'ModuleProfile',
        '.github/workflows/other.yml': 'melos run analyze:hooks',
        'packages/a/tool/run.dart': 'ModuleProfile',
      }),
      [
        'README.md:1: ModuleProfile',
        'packages/a/README.md:1: kBlocStateManagement',
        '.github/workflows/other.yml:1: analyze:hooks',
        'packages/a/tool/run.dart:1: ModuleProfile',
      ],
    );
  });

  test('allows a name only in the files of its exceptions', () {
    const engine = 'packages/smf_modules/smf_contribution_engine/lib';
    const template =
        'packages/smf_contracts/bricks/di_role/__brick__/lib/di.dart';
    expect(
      _names({
        'packages/smf_modules/smf_get_it/lib/di.dart': 'GetIt getIt;',
        '$engine/patch.dart': "import 'package:mustachex/mustachex.dart';",
        '$engine/profile.dart': 'class ModuleProfile {}',
        'packages/smf_contracts/lib/src/roles/di.dart':
            'class ModuleProfile {}',
        template: '{{app_name_sc}}',
        'packages/smf_contracts/pubspec.yaml':
            '  smf_contribution_engine: ^0.2.0\n  mustachex: ^1.0.0',
      }),
      [
        '$engine/profile.dart:1: ModuleProfile',
        'packages/smf_contracts/lib/src/roles/di.dart:1: ModuleProfile',
        '$template:1: {{app_name_sc}}',
        'packages/smf_contracts/pubspec.yaml:1: smf_contribution_engine',
        'packages/smf_contracts/pubspec.yaml:2: mustachex',
      ],
    );
  });

  test(
      'finds the files of the providers of roles in the tests of modules, '
      'but as the keys of maps and in the tests of the provider', () {
    const home = 'packages/smf_modules/smf_home_flutter/test/home_test.dart';
    const router = 'packages/smf_modules/smf_go_router/test/support/app.dart';
    const tabs = 'packages/smf_modules/smf_bottom_tabs/test/tabs_test.dart';
    expect(
      _names({
        home: 'const factory = RouterRole.appRouterFactoryFile;\n'
            'final di = app.files[DiRole.dependenciesFile]!;\n'
            "final path = 'lib/core/layout/app_shell.dart';\n"
            "import 'package:contract_app/core/di/dependencies.dart';\n"
            "  RouterRole.appRouterFactoryFile: '''\n"
            '  LayoutRole.appShellFile : [\n'
            "  'lib/core/router/app_router_factory.dart': '',\n"
            'final other = RouterRole.appRouterFactoryFileOf(app);\n'
            'final named = MyDiRole.dependenciesFile;\n',
        router: 'const factory = RouterRole.appRouterFactoryFile;\n'
            'final shell = app.files[LayoutRole.appShellFile]!;\n',
        'packages/smf_modules/smf_get_it/test/get_it_test.dart':
            'const file = DiRole.dependenciesFile;\n',
        tabs: 'const file = LayoutRole.appShellFile;\n'
            'const router = RouterRole.appRouterFactoryFile;\n',
        // Code of modules, and the tests of other packages.
        'packages/smf_modules/smf_home_flutter/lib/home.dart':
            'const factory = RouterRole.appRouterFactoryFile;\n',
        'packages/smf_pipeline/fixture_registry/test/registry_test.dart':
            'final router = app.files[RouterRole.appRouterFactoryFile]!;\n',
        'packages/smf_contracts/test/di_test.dart':
            'expect(issue.path, DiRole.dependenciesFile);\n',
      }),
      [
        '$home:1: RouterRole.appRouterFactoryFile',
        '$home:2: DiRole.dependenciesFile',
        '$home:3: LayoutRole.appShellFile',
        '$home:4: DiRole.dependenciesFile',
        '$router:2: LayoutRole.appShellFile',
        '$tabs:2: RouterRole.appRouterFactoryFile',
      ],
    );
  });

  test('reports every path of an exception that matches nothing', () {
    // Both exceptions are lasting ones.
    final problems = problemsOf({
      'packages/smf_modules/smf_contribution_engine/lib/a.dart': 'mustachex',
    });

    expect(
      problems,
      contains(
        'The exception for pubspec.yaml matches nothing; remove it from '
        'tools/banlist.dart.',
      ),
    );
    expect(
      problems,
      isNot(contains(contains('smf_contribution_engine/ matches nothing'))),
    );
  });
}
