import 'dart:convert';
import 'dart:io';

import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';

/// Prints, on one line of JSON for `$GITHUB_OUTPUT`, the matrix of the
/// versions of Flutter that the nightly workflow of CI checks the apps of
/// the modules of `smf create` with: every stable release that the apps
/// allow, from the lists of releases of Flutter for Linux, macOS and
/// Windows; see `flutterVersionsOf`. What the versions are goes to the
/// standard error.
Future<void> main() async {
  try {
    final (:flutter, :dart) = await matrixSdkConstraints(smfModules);
    final client = HttpClient();
    final releases = {
      for (final system in FlutterSystem.values)
        system: stableReleasesOf(await _json(client, system.releases), system),
    };
    client.close();
    final versions = flutterVersionsOf(
      releases,
      flutter: flutter,
      dart: dart,
    );
    stderr.writeln(
      'The apps allow Flutter $flutter and Dart $dart: '
      '${versions.join(', ')}.',
    );
    stdout.writeln(jsonEncode(flutterVersionsMatrix(versions)));
  } on Exception catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

/// The JSON at [uri], with two more tries after a failure of the network.
Future<Object?> _json(HttpClient client, Uri uri) async {
  for (var tries = 1;; tries++) {
    try {
      final response = await (await client.getUrl(uri)).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      return jsonDecode(await response.transform(utf8.decoder).join());
    } on IOException catch (error) {
      if (tries == 3) rethrow;
      stderr.writeln('$uri: $error. Trying again.');
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }
}
