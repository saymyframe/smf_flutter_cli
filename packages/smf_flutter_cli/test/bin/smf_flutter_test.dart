import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:smf_flutter_cli/version.dart';
import 'package:test/test.dart';

/// Runs `bin/smf_flutter.dart` in a separate Dart VM, so the real exit code
/// and output of the executable can be checked.
Future<ProcessResult> _runSmf(List<String> args) async {
  final libDir = await Isolate.resolvePackageUri(
    Uri.parse('package:smf_flutter_cli/'),
  );
  final packageConfig = await Isolate.packageConfig;
  final entrypoint = p.join(
    p.dirname(libDir!.toFilePath()),
    'bin',
    'smf_flutter.dart',
  );

  return Process.run(Platform.resolvedExecutable, [
    '--packages=${packageConfig!.toFilePath()}',
    entrypoint,
    ...args,
  ]);
}

void main() {
  group('smf executable', () {
    test(
      'prints the version and exits with 0',
      () async {
        final result = await _runSmf(['--version']);

        expect(result.exitCode, 0);
        expect(result.stdout, contains('CLI version: $packageVersion'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'reports an unknown command as a usage error with exit code 64',
      () async {
        final result = await _runSmf(['bogus']);

        expect(result.exitCode, 64);
        expect(result.stderr, contains('Could not find a command named'));
        expect(result.stderr, isNot(contains('Unhandled exception')));
      },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: 'Bug: main() does not catch UsageException, so a typo prints '
          'a Dart stack trace and exits with 255',
    );
  });
}
