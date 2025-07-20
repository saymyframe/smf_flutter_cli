import 'package:mason/mason.dart' show Logger;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/file_writers/file_writer.dart';

class DryRunWriteStrategy implements FileWriteStrategy {
  const DryRunWriteStrategy(this.logger);

  final Logger logger;

  @override
  Future<void> write(GeneratedFile file) async {
    logger
      ..write('Would write: ${file.path}\n')
      ..write(file.content);
  }
}
