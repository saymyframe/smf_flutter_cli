// The tests that packages keep for the apps of the matrix in `app_tests/`
// (see tool/matrix.dart) run in every app that has their module, whatever
// else the app has. A role that an app can have several providers of, such
// as crash reporting, generates functions that reach all of them, such as
// createCrashReporter(), whose reporter reports to every provider. The
// platform side of a provider is answered only by the tests of its own
// module, so an app test that calls such a function fails in an app with
// another provider, although the app works. A test of a provider uses the
// implementation of its own module instead, such as
// createCrashlyticsCrashReporter().
//
// This test finds those calls in the app tests of the CLI and of the
// packages of its modules. It takes the functions from the roles: the
// public top-level functions of the files of the interface of each role
// that allows several providers, in the apps of its providers that the
// contract harness renders.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The functions of the roles of [modules] that an app can have several
/// providers of, by the path of the file of the role that declares them,
/// such as `lib/core/crash_reporting/crash_reporter.dart`.
///
/// They are the public top-level functions of the files of the interface
/// of each such role, in the app of each of its providers that the
/// contract harness renders first.
Future<Map<String, Set<String>>> _roleFunctionsOf(
  List<SmfModule> modules,
) async {
  final harness = ContractHarness(ModuleRegistry(modules));
  final functions = <String, Set<String>>{};
  for (final module in modules) {
    final roles = [
      for (final role in module.descriptor.provides)
        if (role.cardinality.allowsMany) role,
    ];
    if (roles.isEmpty) continue;
    final result = await harness.check(
      harness.casesOfModule(module.descriptor.id).first,
    );
    final app = result.app;
    if (app == null) {
      fail('The harness renders no app of ${module.descriptor.id}: $result');
    }
    for (final role in roles) {
      for (final path in role.interface.files) {
        final file = app.files[path];
        if (file == null) fail('The app of $result has no $path of $role.');
        final index = DartFileIndexer.index(path, file.text);
        (functions[path] ??= {}).addAll([
          for (final declaration in index.declarations)
            if (declaration.kind == DeclarationKind.function &&
                !declaration.name.startsWith('_'))
              declaration.name,
        ]);
      }
    }
  }
  return functions;
}

/// The uses in [file], a file of app tests, of the [functions] of roles by
/// the path of their file in the app: calls and tear-offs through an import
/// of that file as `package:{{app_name}}/...`, with a prefix or without.
/// Each is described as `<function>() of <path>`.
List<String> _usesIn(DartFileIndex file, Map<String, Set<String>> functions) {
  final uses = <String>[];
  for (final MapEntry(key: path, value: names) in functions.entries) {
    final uri = 'package:{{app_name}}/${path.substring('lib/'.length)}';
    final imports = [
      for (final import in file.imports)
        if (import.uri == uri) import,
    ];
    if (imports.isEmpty) continue;
    final unprefixed = imports.any((import) => import.prefix == null);
    final prefixes = {
      for (final import in imports)
        if (import.prefix case final prefix?) prefix,
    };
    bool through(String? target) =>
        target == null ? unprefixed : prefixes.contains(target);
    final used = {
      for (final call in file.invocations)
        if (names.contains(call.name) && through(call.target)) call.name,
      if (unprefixed)
        for (final reference in file.references)
          if (names.contains(reference.name)) reference.name,
      for (final access in file.memberAccesses)
        if (names.contains(access.name) && prefixes.contains(access.target))
          access.name,
    };
    uses.addAll([for (final name in used) '$name() of $path']);
  }
  return uses;
}

/// The Dart files of the app tests of the CLI and of the packages of the
/// modules it offers, which `lib/src/modules.dart` imports, by their path
/// from the directory of their package, such as
/// `smf_firebase_crashlytics/app_tests/firebase_crashlytics/test/...`.
Future<Map<String, String>> _appTestFiles() async {
  final modules = DartFileIndexer.index(
    'lib/src/modules.dart',
    File('lib/src/modules.dart').readAsStringSync(),
  );
  final packages = {
    'smf_flutter_cli',
    for (final import in modules.imports)
      if (import.uri.startsWith('package:'))
        import.uri.substring('package:'.length, import.uri.indexOf('/')),
  };
  final files = <String, String>{};
  for (final package in packages) {
    final lib = await Isolate.resolvePackageUri(Uri.parse('package:$package/'));
    if (lib == null) fail('No package $package.');
    final appTests = Directory.fromUri(lib.resolve('../app_tests/'));
    if (!appTests.existsSync()) continue;
    for (final file in appTests.listSync(recursive: true)) {
      if (file is File && file.path.endsWith('.dart')) {
        final path = file.uri.path;
        final relative = path.substring(appTests.uri.path.length);
        files['$package/app_tests/$relative'] = file.readAsStringSync();
      }
    }
  }
  return files;
}

/// Checks that [functions], the functions of the roles of a registry by
/// the path of the file of the role that declares them, are what the guard
/// can look for.
void _expectRoleFunctions(Map<String, Set<String>> functions) {
  expect(functions, isNotEmpty);
  for (final MapEntry(key: path, value: names) in functions.entries) {
    expect(names, isNotEmpty, reason: path);
  }
}

/// A role that an app can have several providers of, whose file declares
/// only types, so none of its functions reaches every provider.
final class _TypesRole extends Role<String> {
  const _TypesRole();

  /// The file of the role in the app.
  static const file = 'lib/core/types/types.dart';

  @override
  String get id => 'types';

  @override
  String get description => 'Types';

  @override
  RoleCardinality get cardinality => RoleCardinality.many;

  @override
  RoleInterface get interface => const RoleInterface(files: [file]);

  @override
  RoleTemplate<String> get template => const _TypesTemplate();
}

const _typesRole = _TypesRole();

/// The template of [_typesRole], which generates its file.
final class _TypesTemplate extends RoleTemplate<String> {
  const _TypesTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          MasonBundle(
            name: 'types_role',
            description: 'The types of the role',
            version: '0.1.0',
            files: [
              MasonBundledFile(
                _TypesRole.file,
                base64.encode(
                  utf8.encode(
                    '/// A type of the role.\n'
                    'abstract interface class Types {}\n',
                  ),
                ),
                'text',
              ),
            ],
          ),
        ),
      ];
}

/// A provider of [_typesRole].
final class _TypesProvider extends SmfModule {
  const _TypesProvider();

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: ModuleId('types_provider'),
        description: 'Types',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(_typesRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => const [];
}

void main() {
  test(
      'no app test calls a function of a role that an app can have several '
      'providers of', () async {
    final functions = await _roleFunctionsOf(smfModules);
    final files = await _appTestFiles();

    _expectRoleFunctions(functions);
    expect(files, isNotEmpty);
    expect(
      [
        for (final MapEntry(key: path, value: text) in files.entries)
          for (final use
              in _usesIn(DartFileIndexer.index(path, text), functions))
            '$path: $use',
      ],
      isEmpty,
      reason: 'These functions reach every provider of their role; a test '
          'of a provider uses the implementation of its own module instead.',
    );
  });

  group('a use of a function of a role', () {
    const path = 'lib/core/crash_reporting/crash_reporter.dart';
    const functions = {
      path: {'createCrashReporter', 'installCrashReporting'},
    };
    const imports = """
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart';
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart'
    as role;
""";

    for (final (use, code) in [
      ('a call of it', 'createCrashReporter();'),
      ('a call of it with a prefix', 'role.createCrashReporter();'),
      ('a tear-off of it', 'final create = createCrashReporter;'),
      (
        'a tear-off of it with a prefix',
        'final create = role.createCrashReporter;'
      ),
    ]) {
      test('is $use, through an import of its file', () {
        final file = DartFileIndexer.index(
          'test/a_test.dart',
          '$imports\nvoid main() {\n  $code\n}\n',
        );

        expect(_usesIn(file, functions), ['createCrashReporter() of $path']);
      });
    }

    test('is no use of a function of the same name from another file', () {
      final file = DartFileIndexer.index('test/a_test.dart', """
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart'
    as role;
import 'package:{{app_name}}/core/crash_reporting/other_crash_reporter.dart';
import 'package:{{app_name}}/core/crash_reporting/other_crash_reporter.dart'
    as other;

void main() {
  createCrashReporter();
  other.installCrashReporting();
  final create = other.createCrashReporter;
}
""");

      expect(file.imports.map((import) => import.prefix), [
        'role',
        null,
        'other',
      ]);
      expect(_usesIn(file, functions), isEmpty);
    });
  });

  test(
      'a role that an app can have several providers of, whose file declares '
      'only types, leaves the guard nothing to look for, and no problem',
      () async {
    final functions = await _roleFunctionsOf(
      const [FlutterCoreModule(), _TypesProvider()],
    );

    expect(functions, {_TypesRole.file: isEmpty});
    _expectRoleFunctions(functions);
  });
}
