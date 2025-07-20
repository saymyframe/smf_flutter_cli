import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/file_writers/file_writer.dart';

class DefaultWriteStrategy implements FileWriteStrategy {
  @override
  Future<void> write(GeneratedFile file) async {
    final ioFile = File(file.path);
    await ioFile.writeAsString(file.content);
  }
}
