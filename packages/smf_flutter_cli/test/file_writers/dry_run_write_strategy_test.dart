import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/file_writers/file_writer.dart';
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';

void main() {
  group('DryRunWriteStrategy', () {
    late Directory tempDir;
    late MockLogger logger;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('smf_dry_run_write');
      logger = MockLogger();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('logs the target path followed by the content', () async {
      final path = p.join(tempDir.path, 'router.dart');

      await DryRunWriteStrategy(logger).write(GeneratedFile(path, 'content'));

      verifyInOrder([
        () => logger.write('Would write: $path\n'),
        () => logger.write('content'),
      ]);
      verifyNoMoreInteractions(logger);
    });

    test('does not touch the file system', () async {
      final path = p.join(tempDir.path, 'router.dart');

      await DryRunWriteStrategy(logger).write(GeneratedFile(path, 'content'));

      expect(File(path).existsSync(), isFalse);
      expect(tempDir.listSync(), isEmpty);
    });
  });
}
