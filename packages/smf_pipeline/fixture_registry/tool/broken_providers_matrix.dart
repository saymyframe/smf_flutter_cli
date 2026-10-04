import 'dart:io';

import 'package:fixture_registry/broken_providers.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// Generates in the directory given as the only argument the app of each
/// provider of a role with one known bug (`brokenProviders` of
/// `lib/broken_providers.dart`) with `smf create`, as the matrix does, adds
/// to it the app tests that apply to it, those of the apps of the fixtures
/// and of the app of several providers (`brokenProviderAppTests`), and runs
/// them with `flutter test` once the app with them passes
/// `flutter analyze`: the tests of the role that the registry names for the
/// provider must fail first on an expectation with the reason that it
/// gives, and every other test of the app must pass; see `runFailingApps`.
/// So each test of a role shows that it fails when a provider breaks the
/// contract that it checks. It does the same with the apps of the modules
/// that break what the app tests expect of every module (`brokenModuleApps`),
/// such as a guard of the routes that nothing opens for the tests.
Future<void> main(List<String> arguments) async {
  if (arguments case [final directory] when !directory.startsWith('-')) {
    final providers = brokenProviders();
    for (final provider in providers) {
      stdout.writeln(
        '${provider.module.descriptor.id} provides the ${provider.role} with '
        'a bug: ${provider.bug}',
      );
    }
    final ofModules = brokenModuleApps();
    for (final app in ofModules) {
      final files = {for (final failure in app.failures) failure.file};
      stdout.writeln('${app.name} must fail ${files.join(', ')}.');
    }
    final code = await runFailingApps(
      [for (final provider in providers) provider.failingApp, ...ofModules],
      directory: directory,
      appTests: MatrixAppTests(await brokenProviderAppTests()),
    );
    await Future.wait<void>([stdout.flush(), stderr.flush()]);
    exit(code);
  }
  stderr.writeln(
    'Usage: dart run tool/broken_providers_matrix.dart <directory>',
  );
  exit(64);
}
