import 'dart:io';

import 'package:fixture_registry/broken_providers.dart';
import 'package:fixture_registry/matrix_app_tests.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// Generates in the directory given as the only argument the app of each
/// provider of a role with one known bug (`brokenProviders` of
/// `lib/broken_providers.dart`) with `smf create`, as the matrix does, adds
/// to it the app tests of the fixtures that apply to it (`fixtureAppTests`
/// of `lib/matrix_app_tests.dart`) and runs them with `flutter test` once
/// the app with them passes `flutter analyze`: the tests of the role that
/// the registry names for the provider must fail first on an expectation
/// with the reason that it gives, and every other test of the app must
/// pass; see `runFailingApps`. So each test of a role shows that it fails
/// when a provider breaks the contract that it checks.
Future<void> main(List<String> arguments) async {
  if (arguments case [final directory] when !directory.startsWith('-')) {
    final providers = brokenProviders();
    for (final provider in providers) {
      stdout.writeln(
        '${provider.module.descriptor.id} provides the ${provider.role} with '
        'a bug: ${provider.bug}',
      );
    }
    final code = await runFailingApps(
      [for (final provider in providers) provider.failingApp],
      directory: directory,
      appTests: await fixtureAppTests(),
    );
    await Future.wait<void>([stdout.flush(), stderr.flush()]);
    exit(code);
  }
  stderr.writeln(
    'Usage: dart run tool/broken_providers_matrix.dart <directory>',
  );
  exit(64);
}
