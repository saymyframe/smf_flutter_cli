// That a release build of an app of the CLI stops without the values of
// .env, whichever module that the CLI offers provides the env role: the
// compiler stops at the check of the role, in an app with keys, with the
// text of the role, and lets a build of an app without keys go. The check and
// AppEnv need only the Dart SDK, so the test compiles them as the compiler
// of a release build does, without Flutter. A job of CI builds an app with
// every module with flutter build, in env_release_build_test.dart of
// smf_contracts.
@TestOn('vm')
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The import of the check of the env role in an app of the harness.
final String _check = 'package:${ContractHarness.defaultContext.appName}/'
    '${EnvRole.checkFile.substring('lib/'.length)}';

/// A program that calls the check of the env role as `bootstrap()` does.
final String _bootstrap = '''
import '$_check';

void main() => checkEnvValues(print);
''';

/// What a release build of the check of the env role of [result], and of
/// the files that it imports, gives without a declaration: whether it
/// compiled, and what the compiler printed.
Future<({bool compiled, String output})> _releaseWithoutValues(
  ContractResult result,
) async {
  final app = DartOnlyApp.write(result.app!, [EnvRole.checkFile]);
  try {
    return await app.compile(_bootstrap);
  } finally {
    app.delete();
  }
}

/// The result of [contractCase], which has no errors and is rendered.
Future<ContractResult> _rendered(
  ContractHarness harness,
  ContractCase contractCase,
) async {
  final result = await harness.check(contractCase);
  expect(result.errors.map((issue) => '$issue'), isEmpty);
  return result;
}

void main() {
  final registry = ModuleRegistry(smfModules);
  final harness = ContractHarness(registry);
  final providers = registry.providersOf(envRole);

  test('finds the providers of the env role that the CLI offers', () {
    expect(providers, isNotEmpty);
  });

  for (final provider in providers) {
    final id = provider.descriptor.id;

    test(
        'stops a release build of an app with every module and $id without '
        'the values, with the text of the role', () async {
      final result = await _rendered(
        harness,
        harness.casesOfAll().firstWhere(
              (contractCase) => contractCase.picks[envRole] == id,
            ),
      );
      final input = envRole.hookInput(result.hook!);
      expect(envRole.keysIn(input), isNotEmpty);

      final built = await _releaseWithoutValues(result);

      expect(built.compiled, isFalse, reason: 'It compiled.');
      expect(
        built.output,
        contains(
          compilerQuoteOf(
            EnvRole.releaseErrorOf(envRole.toolArgumentsIn(input)),
          ),
        ),
      );
    });

    test('lets a release build of the app of $id alone, without keys, go',
        () async {
      final result = await _rendered(harness, harness.casesOfModule(id).first);
      expect(envRole.keysIn(envRole.hookInput(result.hook!)), isEmpty);

      final built = await _releaseWithoutValues(result);

      expect(built.compiled, isTrue, reason: built.output);
    });
  }
}
