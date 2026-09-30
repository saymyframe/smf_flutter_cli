// Tests tool/flutterfire_version.dart, from which CI takes the version of
// flutterfire_cli that it activates for the apps that it configures with
// Firebase, and the name of the check of the FlutterFire CLI that it finds
// in what smf create --explain says, so that CI tests what the module does
// rather than what the workflows would repeat.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:smf_firebase_core/src/preflight/flutterfire_cli.dart';
import 'package:test/test.dart';

void main() {
  test(
      'prints the version of flutterfire_cli that the module activates and '
      'the name of its check of the machine, on one line of JSON', () async {
    final packageConfig = await Isolate.packageConfig;

    final result = await Process.run(
      Platform.resolvedExecutable,
      [
        'run',
        '--packages=${packageConfig!.toFilePath()}',
        'tool/flutterfire_version.dart',
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    // The workflows read the standard output as JSON.
    final lines = const LineSplitter().convert('${result.stdout}');
    expect(lines, hasLength(1));
    expect(jsonDecode(lines.single), {
      'version': flutterfireVersion,
      'check': const FlutterfireCliCheck().description,
    });
  });
}
