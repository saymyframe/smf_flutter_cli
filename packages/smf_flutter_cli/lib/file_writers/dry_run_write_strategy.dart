import 'package:mason/mason.dart' show Logger;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/file_writers/file_writer.dart';

/// Logs intended writes without touching the file system.
class DryRunWriteStrategy implements FileWriteStrategy {
  /// Creates a strategy that logs to the provided [logger].
  const DryRunWriteStrategy(this.logger);

  /// Logger used to print file paths and contents.
  final Logger logger;

  @override
  /// Prints the target path and file contents instead of writing to disk.
  Future<void> write(GeneratedFile file) async {
    logger
      ..write('Would write: ${file.path}\n')
      ..write(file.content);
  }
}
