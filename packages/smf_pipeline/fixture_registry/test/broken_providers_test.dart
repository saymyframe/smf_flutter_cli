// The providers of roles with one known bug each (brokenProviders), whose
// apps tool/broken_providers_matrix.dart generates, so that the tests of
// their roles show that they fail on the bug. CI runs the tests of the apps
// only in its job with Flutter; these tests check without Flutter that
// each app can be generated, that the tests that must fail are in it as
// they are named, with their reasons, that it has the files that its tests
// import, and that every role whose contract the tests of the apps check
// has a broken provider.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fixture_registry/broken_providers.dart';
import 'package:fixture_registry/fixture_registry.dart';
import 'package:fixture_registry/matrix_app_tests.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/matrix_app_tests.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// A text that a Dart file writes: its parts in order, each a text of the
/// file, or `null` for a value that the file interpolates, which may be any
/// text.
typedef _Template = List<String?>;

/// The template of [node]: its text, adjacent strings as one, with a value
/// in place of each expression it interpolates.
_Template _templateOf(StringLiteral node) => switch (node) {
      SimpleStringLiteral(:final value) => [value],
      AdjacentStrings(:final strings) => [
          for (final string in strings) ..._templateOf(string),
        ],
      StringInterpolation(:final elements) => [
          for (final element in elements)
            if (element is InterpolationString) element.value else null,
        ],
    };

/// Whether [template], with any text in place of each of its values, writes
/// [text], all of it.
bool _writesAll(_Template template, String text) {
  final parts = [
    for (final part in template) part == null ? '.*' : RegExp.escape(part),
  ];
  return RegExp('^${parts.join()}\$', dotAll: true).hasMatch(text);
}

/// Whether [template], with any text in place of each of its values, writes
/// a text that has [text], with at least one character of the template
/// itself in [text], as a reason of an expectation that names a value of
/// the app, such as a service, does.
bool _writesPart(_Template template, String text) {
  const value = '\u0000';
  final written = [for (final part in template) part ?? value].join();
  if (!written.contains(value)) return written.contains(text);
  for (var start = 0; start < written.length; start++) {
    for (var end = start + 1; end <= written.length; end++) {
      final piece = written.substring(start, end);
      if (piece.replaceAll(value, '').isEmpty) continue;
      final pattern = piece.split(value).map(RegExp.escape).join('.*');
      if (RegExp('^$pattern\$', dotAll: true).hasMatch(text)) return true;
    }
  }
  return false;
}

/// The full names of the tests that the Dart file with [text] declares
/// with `test` or `testWidgets`, as `flutter test` names them: the
/// descriptions of their groups and their own, with a space between each,
/// as templates, since a description may interpolate a value.
List<_Template> _testNamesIn(String text) {
  final names = _TestNames();
  parseString(content: text, throwIfDiagnostics: false).unit.accept(names);
  return names.names;
}

/// The templates of the strings of the Dart file with [text], such as the
/// reasons of its expectations.
List<_Template> _stringsIn(String text) {
  final strings = _Strings();
  parseString(content: text, throwIfDiagnostics: false).unit.accept(strings);
  return strings.templates;
}

/// The texts of the Dart files of the app test in [directory] that [file]
/// imports by a relative path, directly or through one another, such as the
/// probe of the DI role, which writes the problems of the services that the
/// test of the role expects none of. A file that the matrix generates for
/// the app, which [directory] lacks, has no text here.
List<String> _importedTextsOf(File file, String directory) {
  final tests = '${Directory(directory).absolute.uri}';
  final seen = {'${file.absolute.uri}'};
  final texts = <String>[];
  void visit(File importer) {
    final unit = parseString(
      content: importer.readAsStringSync(),
      throwIfDiagnostics: false,
    ).unit;
    for (final directive in unit.directives.whereType<UriBasedDirective>()) {
      final uri = Uri.tryParse(directive.uri.stringValue ?? '');
      if (uri == null || uri.hasScheme) continue;
      final imported = importer.absolute.uri.resolveUri(uri);
      final path = '$imported';
      if (!path.startsWith(tests) || !seen.add(path)) continue;
      final file = File.fromUri(imported);
      if (!file.existsSync()) continue;
      texts.add(file.readAsStringSync());
      visit(file);
    }
  }

  visit(file);
  return texts;
}

/// What a Dart file of an app test writes before the path of a file of the
/// app that it imports: the package of the app, whose name the matrix
/// fills in.
const _appPackage = 'package:{{app_name}}/';

/// The files of an app that the Dart files of [test] import, each as its
/// path in the app, in `lib/`, and the file of [test] that imports it, by
/// its path from the directory of the app tests of its package, such as
/// `analytics_role/test/analytics_role_test.dart`.
List<({String path, String importer})> _appFilesImportedBy(
  MatrixAppTest test,
) {
  final directory = Directory(test.directory);
  return [
    for (final file in directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')))
      for (final directive in parseString(
        content: file.readAsStringSync(),
        throwIfDiagnostics: false,
      ).unit.directives.whereType<UriBasedDirective>())
        if (directive.uri.stringValue case final uri?
            when uri.startsWith(_appPackage))
          (
            path: 'lib/${uri.substring(_appPackage.length)}',
            importer: file.path.substring(directory.parent.path.length + 1),
          ),
  ];
}

/// The files of the app of [provider], by their paths, as the contract
/// harness renders it.
Future<Set<String>> _filesOfAppOf(BrokenProvider provider) async {
  final harness = ContractHarness(ModuleRegistry(provider.modules));
  final files = <Set<String>>[];
  for (final contractCase in harness.casesOfAll()) {
    final result = await harness.check(contractCase);
    final modules = {
      for (final module in result.resolution!.modules) module.id,
    };
    if (provider.app.every(modules.contains)) {
      files.add(result.app!.files.keys.toSet());
    }
  }
  return files.single;
}

/// Finds the templates of the strings of a file; see [_stringsIn].
final class _Strings extends RecursiveAstVisitor<void> {
  final templates = <_Template>[];

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    templates.add(_templateOf(node));
    super.visitAdjacentStrings(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    templates.add(_templateOf(node));
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    templates.add(_templateOf(node));
    super.visitStringInterpolation(node);
  }
}

/// Finds the full names of the tests of a file; see [_testNamesIn].
final class _TestNames extends RecursiveAstVisitor<void> {
  final names = <_Template>[];

  final _groups = <_Template>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final description = switch (node.argumentList.arguments.firstOrNull) {
      final StringLiteral literal when node.target == null =>
        _templateOf(literal),
      _ => null,
    };
    switch ((node.methodName.name, description)) {
      case ('group', final _Template group):
        _groups.add(group);
        super.visitMethodInvocation(node);
        _groups.removeLast();
      case ('test' || 'testWidgets', final _Template test):
        names.add([
          for (final group in _groups) ...[...group, ' '],
          ...test,
        ]);
        super.visitMethodInvocation(node);
      default:
        super.visitMethodInvocation(node);
    }
  }
}

void main() {
  final providers = brokenProviders();

  test(
      'reads the texts of a file, adjacent strings as one, and a text that '
      'it writes with a value of the app in it', () {
    final strings = _stringsIn(r'''
void main() {
  expect(1, 2, reason: 'A reason '
      'on two lines.');
  problems.add('${service.name} does not resolve: $error');
}
''');
    bool writes(String text) =>
        strings.any((string) => _writesPart(string, text));

    expect(writes('A reason on two lines.'), isTrue);
    expect(writes('reason on two'), isTrue);
    expect(writes('FixtureReplica does not resolve:'), isTrue);
    expect(writes('FixtureReplica does not resolve: Bad state: gone.'), isTrue);
    expect(writes('A reason on three lines.'), isFalse);
    expect(writes('FixtureReplica is not resolved:'), isFalse);
  });

  test(
      'reads the names of the tests of a file, with any text in place of a '
      'value that a name interpolates', () {
    final names = _testNamesIn(r'''
void main() {
  test('a', () {});
  group('b', () {
    testWidgets('c', (tester) async {});
    group('d' ' e', () {
      test('f', () {});
    });
  });
  for (final how in ['throws', 'fails']) {
    test('a service that $how ' 'keeps no other', () {});
  }
  other.test('g', () {});
  test(name, () {});
}
''');
    bool named(String name) => names.any((test) => _writesAll(test, name));

    expect(names, hasLength(4));
    for (final name in [
      'a',
      'b c',
      'b d e f',
      'a service that fails keeps no other',
    ]) {
      expect(named(name), isTrue, reason: name);
    }
    for (final name in ['b', 'c', 'g', 'a service that fails']) {
      expect(named(name), isFalse, reason: name);
    }
  });

  test(
      'the apps of the broken providers get the app tests of the apps of the '
      'fixtures and of the app of several providers, each directory once, '
      'those of the fixtures first', () async {
    final directories = [
      for (final test in await brokenProviderAppTests()) test.directory,
    ];
    final ofFixtures = [
      for (final test in (await fixtureAppTests()).tests) test.directory,
    ];
    final ofSeveralProviders = [
      for (final test in (await severalProvidersAppTests()).tests)
        test.directory,
    ];

    expect(directories.toSet(), hasLength(directories.length));
    expect(directories.take(ofFixtures.length), ofFixtures);
    expect(directories.toSet(), {...ofFixtures, ...ofSeveralProviders});
    // Both have the tests of the events role, the tests of the DI role and
    // the mocks of the fixture providers.
    expect(ofSeveralProviders.where(ofFixtures.contains), isNotEmpty);
  });

  test(
      'each broken provider provides its role, and has a bug and tests that '
      'must fail on it', () {
    expect(providers, isNotEmpty);
    for (final provider in providers) {
      final id = provider.module.descriptor.id;
      expect(provider.module.descriptor.provides, contains(provider.role));
      expect(provider.bug.trim(), isNotEmpty, reason: '$id');
      expect(provider.failures, isNotEmpty, reason: '$id');
      expect(provider.app, isNot(contains(id)), reason: '$id');
    }
    expect(
      {for (final provider in providers) provider.module.descriptor.id},
      hasLength(providers.length),
      reason: 'Each broken provider is a module of its own.',
    );
  });

  test(
      'the registry of a broken provider has the fixture modules, with the '
      'broken provider in place of the other providers of its role, and its '
      'app the app entry, the broken provider and the modules it names', () {
    for (final provider in providers) {
      final id = provider.module.descriptor.id;
      final ids = {
        for (final module in provider.registry) module.descriptor.id,
      };

      expect(ModuleRegistry.problemsOf(provider.registry), isEmpty);
      expect(
        [
          for (final module in provider.registry)
            if (module.descriptor.provides.contains(provider.role))
              module.descriptor.id,
        ],
        [id],
      );
      for (final module in fixtureModules()) {
        if (module.descriptor.provides.contains(provider.role)) continue;
        expect(ids, contains(module.descriptor.id));
      }
      final modules = [
        for (final module in provider.modules) module.descriptor.id,
      ];
      expect(ModuleRegistry.problemsOf(provider.modules), isEmpty);
      expect(modules.take(2 + provider.app.length), [
        const ModuleId('flutter_core'),
        id,
        ...provider.app,
      ]);
      // The other modules of the registry are the providers that the
      // modules of the app have variants for.
      for (final other in modules.skip(2 + provider.app.length)) {
        expect(
          provider.modules.any(
            (module) =>
                module.descriptor.variants?.byProvider.containsKey(other) ??
                false,
          ),
          isTrue,
          reason: '$other',
        );
      }
      final app = provider.failingApp;
      expect(app.name, '$id');
      expect(app.modules, provider.modules);
      expect(app.providers, provider.app);
      expect(app.failures, provider.failures);
    }
  });

  for (final provider in providers) {
    final id = provider.module.descriptor.id;

    group('$id:', () {
      test(
          'the module keeps the rules of its role that the contract harness '
          'checks, so that only a running app shows its bug', () async {
        final harness = ContractHarness(ModuleRegistry(provider.registry));
        final cases = harness.casesOfModule(id);

        expect(cases, isNotEmpty);
        for (final contractCase in cases) {
          final result = await harness.check(contractCase);
          expect(
            result.errors.map((issue) => '$issue'),
            isEmpty,
            reason: '$contractCase',
          );
        }
      });

      test(
          'its app is an app with every module of its registry, which the '
          'contract harness renders without errors', () async {
        final (:app, :problems) = await provider.failingApp.check();

        expect(problems, isEmpty);
        expect(app!.modules, containsAll([id, ...provider.app]));
        expect(app.everyModuleWith, isNotNull);
        expect(app.hook, isNotNull);
      });

      test(
          'the tests that must fail are among the tests of its app, as they '
          'are named, with their reasons', () async {
        final (:app, problems: _) = await provider.failingApp.check();
        final tests = [
          for (final test in await brokenProviderAppTests())
            if (test.appliesTo(app!)) test,
        ];

        for (final failure in provider.failures) {
          final files = [
            for (final test in tests)
              if (File('${test.directory}/${failure.file}') case final file
                  when file.existsSync())
                (file: file, directory: test.directory),
          ];
          expect(
            files,
            hasLength(1),
            reason: 'The tests of the app have ${failure.file} once.',
          );
          final (:file, :directory) = files.single;
          final text = file.readAsStringSync();
          expect(
            _testNamesIn(text).any((name) => _writesAll(name, failure.test)),
            isTrue,
            reason: '$failure is a test of its file.',
          );
          expect(
            [text, ..._importedTextsOf(file, directory)]
                .expand(_stringsIn)
                .any((text) => _writesPart(text, failure.reason)),
            isTrue,
            reason: 'The reason of $failure is a text that its file writes, '
                'or a file of its tests that it imports.',
          );
        }
      });

      test(
          'the files of the app that the tests of its app import are in its '
          'app, such as those of the fixture providers that the tests of '
          'the analytics role and of the crash reporting role look at',
          () async {
        final (:app, problems: _) = await provider.failingApp.check();
        final files = await _filesOfAppOf(provider);

        for (final test in await brokenProviderAppTests()) {
          if (!test.appliesTo(app!)) continue;
          for (final (:path, :importer) in _appFilesImportedBy(test)) {
            expect(
              files.contains(path) ||
                  File('${test.directory}/$path').existsSync(),
              isTrue,
              reason: '$importer imports $path, which the app of $id does '
                  'not have: add the module that renders it to the app of '
                  '$id in brokenProviders().',
            );
          }
        }
      });
    });
  }

  test(
      'every role whose contract the app tests check has a broken provider, '
      'or an exemption with its reason, and no exemption is left unused',
      () async {
    final tested = <Role>{
      for (final appTests in [
        await smfAppTests(),
        await fixtureAppTests(),
        await severalProvidersAppTests(),
      ]) ...{
        ...appTests.testedRoles,
        for (final test in appTests.tests) ...test.roles,
      },
    };
    final broken = {for (final provider in providers) provider.role};

    expect(tested, isNotEmpty);
    for (final role in tested) {
      expect(
        broken.contains(role) ||
            (brokenProviderExemptions[role]?.trim().isNotEmpty ?? false),
        isTrue,
        reason: 'The app tests check the contract of the $role, but no '
            'broken provider of the $role shows that they fail when a '
            'provider breaks it: add one to brokenProviders() in '
            'lib/broken_providers.dart, or exempt the role in '
            'brokenProviderExemptions with the reason.',
      );
    }
    for (final role in brokenProviderExemptions.keys) {
      expect(
        tested.contains(role) && !broken.contains(role),
        isTrue,
        reason: 'brokenProviderExemptions exempts the $role, but the app '
            'tests check no contract of it, or it has a broken provider: '
            'remove the exemption.',
      );
    }
  });

  test('no broken provider is in a registry of apps that must work', () {
    final working = {
      for (final module in [
        ...fixtureModules(),
        ...severalProvidersModules(),
        ...smfModules,
      ])
        module.descriptor.id,
    };

    for (final provider in providers) {
      expect(working, isNot(contains(provider.module.descriptor.id)));
    }
  });
}
