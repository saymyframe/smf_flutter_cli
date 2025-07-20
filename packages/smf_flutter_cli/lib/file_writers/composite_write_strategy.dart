import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/file_writers/file_writer.dart';

class CompositeWriteStrategy implements FileWriteStrategy {
  const CompositeWriteStrategy(this.strategies);

  final List<FileWriteStrategy> strategies;

  @override
  Future<void> write(GeneratedFile file) async {
    for (final strategy in strategies) {
      await strategy.write(file);
    }
  }
}
