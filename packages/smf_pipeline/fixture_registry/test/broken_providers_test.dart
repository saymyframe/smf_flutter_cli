// The providers of roles with one known bug each (brokenProviders), whose
// apps tool/broken_providers_matrix.dart generates, so that the tests of
// their roles show that they fail on the bug. CI runs the tests of the apps
// only in its job with Flutter; these tests check without Flutter that
// each app can be generated, that the tests that must fail are in it as
// they are named, with their reasons, and that every role whose contract
// the tests of the apps check has a broken provider.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fixture_registry/broken_providers.dart';
import 'package:fixture_registry/fixture_registry.dart';
import 'package:fixture_registry/matrix_app_tests.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix_app_tests.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The full names of the tests that the Dart file with [text] declares
/// with `test` or `testWidgets`, as `flutter test` names them: the
/// descriptions of their groups and their own, with a space between each.
List<String> _testNamesIn(String text) {
  final names = _TestNames();
  parseString(content: text, throwIfDiagnostics: false).unit.accept(names);
  return names.names;
}

/// The values of the string literals of the Dart file with [text], adjacent
/// strings as one, such as the reasons of its expectations.
List<String> _stringsIn(String text) {
  final strings = _Strings();
  parseString(content: text, throwIfDiagnostics: false).unit.accept(strings);
  return strings.values;
}

/// Finds the values of the string literals of a file; see [_stringsIn].
final class _Strings extends RecursiveAstVisitor<void> {
  final values = <String>[];

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    if (node.stringValue case final value?) values.add(value);
    super.visitAdjacentStrings(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    values.add(node.value);
    super.visitSimpleStringLiteral(node);
  }
}

/// Finds the full names of the tests of a file; see [_testNamesIn].
final class _TestNames extends RecursiveAstVisitor<void> {
  final names = <String>[];

  final _groups = <String>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final description = switch (node.argumentList.arguments.firstOrNull) {
      final StringLiteral literal when node.target == null =>
        literal.stringValue,
      _ => null,
    };
    switch ((node.methodName.name, description)) {
      case ('group', final String group):
        _groups.add(group);
        super.visitMethodInvocation(node);
        _groups.removeLast();
      case ('test' || 'testWidgets', final String test):
        names.add([..._groups, test].join(' '));
        super.visitMethodInvocation(node);
      default:
        super.visitMethodInvocation(node);
    }
  }
}

void main() {
  final providers = brokenProviders();

  test('reads the texts of a file, adjacent strings as one', () {
    expect(
      _stringsIn('''
void main() {
  expect(1, 2, reason: 'A reason '
      'on two lines.');
}
'''),
      contains('A reason on two lines.'),
    );
  });

  test('reads the names of the tests of a file', () {
    expect(
      _testNamesIn('''
void main() {
  test('a', () {});
  group('b', () {
    testWidgets('c', (tester) async {});
    group('d' ' e', () {
      test('f', () {});
    });
  });
  other.test('g', () {});
  test(name, () {});
}
'''),
      ['a', 'b c', 'b d e f'],
    );
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
          for (final test in (await fixtureAppTests()).tests)
            if (test.appliesTo(app!)) test,
        ];

        for (final failure in provider.failures) {
          final files = [
            for (final test in tests)
              if (File('${test.directory}/${failure.file}') case final file
                  when file.existsSync())
                file,
          ];
          expect(
            files,
            hasLength(1),
            reason: 'The tests of the app have ${failure.file} once.',
          );
          final text = files.single.readAsStringSync();
          expect(
            _testNamesIn(text),
            contains(failure.test),
            reason: '$failure',
          );
          expect(
            _stringsIn(text),
            anyElement(contains(failure.reason)),
            reason: 'The reason of $failure is a text of its file.',
          );
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
