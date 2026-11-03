// That a release build of an app of the fixtures stops without the values of
// .env, whichever module of the registries of the fixtures provides the env
// role, fake_env among them: the compiler stops at the check of the role, in
// an app with keys, with the text of the role, and lets a build go with what
// the tool arguments of fake_env declare, and a build of an app without keys.
// The check and AppEnv need only the Dart SDK, so the test compiles them as
// the compiler of a release build does, without Flutter. A provider whose
// AppEnv.supplied is always true, the bug that the check stops, fails it.
@TestOn('vm')
library;

import 'dart:convert';

import 'package:fake_infra/fake_infra.dart';
import 'package:fixture_registry/fixture_registry.dart';
import 'package:smf_contracts/smf_contracts.dart';
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

/// What a release build of the check of the env role of [app], and of the
/// files that it imports, gives with [defines]: whether it compiled, and
/// what the compiler printed.
Future<({bool compiled, String output})> _releaseOf(
  RenderedApp app, {
  Map<String, String> defines = const {},
}) async {
  final dartApp = DartOnlyApp.write(app, [EnvRole.checkFile]);
  try {
    return await dartApp.compile(_bootstrap, defines: defines);
  } finally {
    dartApp.delete();
  }
}

/// The problem of a release build without the values of [app], the app of
/// [result] or a copy of it, which has keys: that it compiled, or that the
/// compiler did not quote the text of the role; `null` when it stops with
/// that text.
Future<String?> _problemOfRelease(
  ContractResult result,
  RenderedApp app,
) async {
  final text = EnvRole.releaseErrorOf(
    envRole.toolArgumentsIn(envRole.hookInput(result.hook!)),
  );
  final built = await _releaseOf(app);
  if (built.compiled) return 'A release build without the values compiled.';
  return built.output.contains(text)
      ? null
      : 'The compiler did not quote "$text": ${built.output}';
}

/// The keys of the lines of the `.env` of [app], as the template of the role
/// writes them, each without a value.
List<String> _linesOf(RenderedApp app) => [
      for (final line
          in const LineSplitter().convert(app.files[EnvRole.dotEnvFile]!.text))
        if (RegExp('^([A-Z0-9_]+)=').firstMatch(line) case final key?) key[1]!,
    ];

void main() {
  for (final (name, modules) in [
    ('the fixtures', fixtureModules()),
    ('several providers', severalProvidersModules()),
  ]) {
    group('the registry of $name', () {
      final registry = ModuleRegistry(modules);
      final harness = ContractHarness(registry);
      final providers = registry.providersOf(envRole);

      test('has a provider of the env role', () {
        expect(providers, isNotEmpty);
      });

      for (final provider in providers) {
        final id = provider.descriptor.id;

        group('with $id', () {
          late ContractResult every;

          setUpAll(() async {
            every = await harness.check(
              harness.casesOfAll().firstWhere(
                    (contractCase) => contractCase.picks[envRole] == id,
                  ),
            );
            expect(every.errors.map((issue) => '$issue'), isEmpty);
          });

          test(
              'stops a release build of an app with every module without '
              'the values, with the text of the role', () async {
            expect(_linesOf(every.app!), isNotEmpty);
            expect(await _problemOfRelease(every, every.app!), isNull);
          });

          test(
              'lets a release build of an app with every module go with the '
              'lines of its .env, all of them empty', () async {
            final built = await _releaseOf(
              every.app!,
              defines: {for (final key in _linesOf(every.app!)) key: ''},
            );
            expect(built.compiled, isTrue, reason: built.output);
          });

          test('lets a release build of the app of $id alone, without keys, go',
              () async {
            final result = await harness.check(harness.casesOfModule(id).first);
            expect(result.errors.map((issue) => '$issue'), isEmpty);
            expect(envRole.keysIn(envRole.hookInput(result.hook!)), isEmpty);

            final built = await _releaseOf(result.app!);

            expect(built.compiled, isTrue, reason: built.output);
          });
        });
      }
    });
  }

  test(
      'reports a provider whose AppEnv.supplied is always true, in an app with '
      'keys, which a release build without the values would let go', () async {
    final harness = ContractHarness(ModuleRegistry(fixtureModules()));
    final result = await harness.check(
      const ContractCase(
        'fake_env with keys',
        requested: [FakeEnvModule.id, FakeEnvUserModule.id],
      ),
    );
    expect(result.errors.map((issue) => '$issue'), isEmpty);
    final reader = result.app!.files[EnvRole.readerFile]!;
    final supplied = RegExp('static const bool supplied =[^;]*;');
    expect(supplied.allMatches(reader.text), hasLength(1));
    final broken = RenderedApp([
      for (final file in result.app!.files.values)
        if (file.path != EnvRole.readerFile) file,
      RenderedFile(
        path: reader.path,
        bytes: utf8.encode(
          reader.text.replaceFirst(
            supplied,
            'static const bool supplied = true;',
          ),
        ),
        owner: reader.owner,
      ),
    ]);

    expect(await _problemOfRelease(result, result.app!), isNull);
    expect(
      await _problemOfRelease(result, broken),
      'A release build without the values compiled.',
    );
  });
}
