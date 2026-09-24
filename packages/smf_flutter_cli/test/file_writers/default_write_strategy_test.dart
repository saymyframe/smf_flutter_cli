import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/file_writers/file_writer.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultWriteStrategy', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('smf_default_write');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('writes the file content to its path', () async {
      final path = p.join(tempDir.path, 'main.dart');

      await DefaultWriteStrategy().write(GeneratedFile(path, 'void main() {}'));

      expect(File(path).readAsStringSync(), 'void main() {}');
    });

    test('overwrites an existing file', () async {
      final file = File(p.join(tempDir.path, 'main.dart'))
        ..writeAsStringSync('old content that is longer than the new one');

      await DefaultWriteStrategy().write(GeneratedFile(file.path, 'new'));

      expect(file.readAsStringSync(), 'new');
    });
  });
}
