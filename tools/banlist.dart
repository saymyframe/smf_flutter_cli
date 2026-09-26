// Checks that the repository no longer uses what the module model replaced:
// the names of the old contracts API, the constants and hooks of the old
// modules, the old way to render bricks, the old template markers, and
// dependencies that only some packages may have.
//
// Run it anywhere in the repository: `dart tools/banlist.dart`. It reads the
// files that git tracks, and the new ones it does not ignore.
//
// A file may use a banned name only if an exception names the file:
// - a lasting exception, for a package that owns the name, such as getIt in
//   smf_get_it, or a test that checks that nothing else uses it;
// - a migration exception, for a package that still uses the old model.
//   It goes once the package has moved, and the check fails when a path of
//   an exception no longer matches anything, so the list only shrinks.
import 'dart:io';

/// A name that the tracked files may not use.
final class _Ban {
  const _Ban(this.name, this.pattern);

  /// A word: a name that stands alone, not a part of a longer name.
  _Ban.word(this.name)
      : pattern = RegExp('(?<![A-Za-z0-9_])${RegExp.escape(name)}'
            '(?![A-Za-z0-9_])');

  /// How the name is shown.
  final String name;

  /// What finds the name in a line.
  final Pattern pattern;
}

/// Files that may use some banned names.
final class _Exception {
  const _Exception(this.files, this.names, this.reason, {this.except});

  /// The files: a path, or the start of one when it ends with `/`.
  final List<String> files;

  /// The start of paths among [files] that the exception does not cover.
  final List<String>? except;

  /// The names the files may use, or `null` for every banned name.
  final Set<String>? names;

  /// Why the files may use them.
  final String reason;

  /// The entry of [files] that lets the file [path] use [name], or `null`.
  String? entryFor(String path, String name) {
    if (!(names?.contains(name) ?? true) ||
        (except?.any(path.startsWith) ?? false)) {
      return null;
    }
    for (final file in files) {
      if (file.endsWith('/') ? path.startsWith(file) : path == file) {
        return file;
      }
    }
    return null;
  }
}

final List<_Ban> _bans = [
  // The contracts of the old module model.
  for (final name in const [
    'ModuleProfile',
    'StateManager',
    'MustacheSlots',
    'sharedFileContributions',
    'ShellRegistry',
    'ShellDeclaration',
    'RouteShellLink',
    'NestedRoute',
    'RouteMeta',
    'RouteScreenArgs',
    'ParameterSource',
    'RouteGuard',
    'GoRouteRedirect',
    'AutoRouteGuard',
    'RoutingMode',
    'ImportAnchor',
    'DiScope',
    'pathToDiTemplate',
    'DiDependencyGroup',
    'DiBindingType',
    'IModuleCodeContributor',
    'EmptyModuleCodeContributor',
    'IModuleContributorFactory',
    'DslContext',
    'DslAwareCodeGenerator',
    'FileMergeStrategy',
    // Not in the model yet: DI scopes and route conditions come with a
    // module that needs them.
    'DiScopes',
    'ConditionData',
    'DiRuntimeNeed',
    // Navigation of the old router module.
    'NavigationService',
    'NavigationTarget',
    'NavigationStrategy',
    'MainTabsShell',
    'NoModulesScreen',
    // Constants and hooks of the old modules.
    'kBlocStateManagement',
    'kRiverpodStateManagement',
    'kWorkingDirectory',
    'smfStateManagers',
    'hookAssetsB64',
    // The old way to render bricks.
    'DirectoryGeneratorTarget',
    'MustachexProcessor',
    'BricksJson',
    // Dependencies that only their owners may have.
    'mustachex',
    'smf_contribution_engine',
    'getIt',
    'GetIt',
  ])
    _Ban.word(name),
  const _Ban('package:get_it', 'package:get_it/'),
  _Ban('get_it:', RegExp(r'^\s+get_it\s*:')),
  _Ban('kFirebase…', RegExp('(?<![A-Za-z0-9_])kFirebase[A-Za-z0-9_]*')),
  _Ban(
    'k…Module',
    RegExp('(?<![A-Za-z0-9_])k[A-Z][A-Za-z0-9_]*Module(?![A-Za-z0-9_])'),
  ),
  const _Ban('analyze:hooks', 'analyze:hooks'),
  const _Ban('MasonGenerator.fromBundle', 'MasonGenerator.fromBundle'),
  // Template markers of the old modules.
  const _Ban('{{app_name_sc}}', '{{app_name_sc}}'),
  const _Ban('{{#modules}}', '{{#modules}}'),
  _Ban('/noModules', RegExp('/noModules(?![A-Za-z0-9_])')),
  _Ban('main-tabs', RegExp('(?<![A-Za-z0-9_-])main-tabs(?![A-Za-z0-9_-])')),
];

const _lasting = [
  _Exception(
    ['tools/banlist.dart', 'tools/banlist_test.dart'],
    null,
    'The banlist and its test name what it bans.',
  ),
  _Exception(
    ['packages/smf_modules/smf_get_it/'],
    {'getIt', 'GetIt', 'package:get_it', 'get_it:'},
    'smf_get_it provides the GetIt container.',
  ),
  _Exception(
    ['packages/smf_modules/smf_contribution_engine/'],
    {
      'mustachex',
      'smf_contribution_engine',
      'MustachexProcessor',
      '{{app_name_sc}}',
      'sharedFileContributions',
    },
    'The contribution engine patches existing apps with mustachex '
    'templates; its tests keep patches of the old modules as examples.',
  ),
  _Exception(
    ['pubspec.yaml'],
    {'smf_contribution_engine'},
    'The workspace has the contribution engine.',
  ),
  _Exception(
    [
      'packages/smf_contracts/test/lego/architecture_test.dart',
      'packages/smf_flutter_cli/test/architecture_test.dart',
    ],
    {'mustachex', 'smf_contribution_engine'},
    'The test checks that the package does not use them.',
  ),
];

const _migrating = [
  _Exception(
    [
      'packages/smf_contracts/lib/smf_contracts_factory.dart',
      'packages/smf_contracts/lib/smf_contracts_module.dart',
      'packages/smf_contracts/lib/src/',
      'packages/smf_contracts/test/src/',
      'packages/smf_contracts/test/smf_contracts_module_test.dart',
      'packages/smf_contracts/bricks/smf_contracts_brick/',
    ],
    null,
    'The old contracts API stays until no module uses it.',
    except: ['packages/smf_contracts/lib/src/lego/'],
  ),
  _Exception(
    ['packages/smf_contracts/pubspec.yaml'],
    {'smf_contribution_engine'},
    'The old contracts API uses the contribution engine.',
  ),
  _Exception(
    [
      'packages/smf_modules/smf_event_bus/',
      'packages/smf_modules/smf_firebase_analytics/',
      'packages/smf_modules/smf_firebase_core/',
      'packages/smf_modules/smf_firebase_crashlytics/',
    ],
    null,
    'The module has not moved to the new model yet.',
  ),
  _Exception(
    ['.github/workflows/build.yml', 'pubspec.yaml', 'tools/bundle_bricks.dart'],
    {'analyze:hooks', 'hookAssetsB64'},
    'The Firebase Core module still has brick hooks.',
  ),
];

/// Whether the check reads the tracked file [path]: Dart code but the
/// generated bundles, pubspecs, the templates of bricks, and the workflows
/// of CI.
bool _checked(String path) =>
    (path.endsWith('.dart') && !path.contains('/lib/bundles/')) ||
    path == 'pubspec.yaml' ||
    path.endsWith('/pubspec.yaml') ||
    path.contains('/__brick__/') ||
    (path.startsWith('.github/') &&
        (path.endsWith('.yml') || path.endsWith('.yaml')));

/// The problems of [files], the text of each file by its path from the
/// root of the repository: every line that uses a banned name that no
/// exception allows, and every path of an exception that allows nothing.
List<String> problemsOf(Map<String, String> files) {
  final exceptions = [..._lasting, ..._migrating];
  final problems = <String>[];
  final used = <(_Exception, String)>{};
  for (final MapEntry(key: path, value: text) in files.entries) {
    if (!_checked(path)) continue;
    for (final (index, line) in text.split('\n').indexed) {
      for (final ban in _bans) {
        if (!line.contains(ban.pattern)) continue;
        final allowing = [
          for (final exception in exceptions)
            if (exception.entryFor(path, ban.name) case final entry?)
              (exception, entry),
        ];
        if (allowing.isEmpty) problems.add('$path:${index + 1}: ${ban.name}');
        used.addAll(allowing);
      }
    }
  }
  for (final exception in exceptions) {
    for (final entry in exception.files) {
      if (!used.contains((exception, entry))) {
        problems.add(
          'The exception for $entry matches nothing; remove it from '
          'tools/banlist.dart.',
        );
      }
    }
  }
  return problems;
}

void main() {
  final String root;
  final ProcessResult files;
  try {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    if (top.exitCode != 0) {
      stderr.writeln('Run the banlist in the repository: ${top.stderr}');
      exit(2);
    }
    root = '${top.stdout}'.trim();
    files = Process.runSync(
      'git',
      ['ls-files', '-z', '--cached', '--others', '--exclude-standard'],
      workingDirectory: root,
    );
  } on ProcessException catch (error) {
    stderr.writeln('The banlist needs git: ${error.message}');
    exit(2);
  }
  if (files.exitCode != 0) {
    stderr.writeln('git ls-files failed: ${files.stderr}');
    exit(2);
  }
  final texts = <String, String>{};
  for (final path in '${files.stdout}'.split('\u0000')) {
    if (path.isEmpty || !_checked(path)) continue;
    try {
      texts[path] = File('$root/$path').readAsStringSync();
    } on FileSystemException {
      continue; // A binary template or a deleted file.
    }
  }
  final problems = problemsOf(texts);
  if (problems.isEmpty) {
    stdout.writeln('No banned names.');
    return;
  }
  stderr
    ..writeln('Banned names, which the module model replaced:')
    ..writeln(problems.map((problem) => '  $problem').join('\n'));
  exitCode = 1;
}
