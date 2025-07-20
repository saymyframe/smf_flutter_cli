import 'package:smf_contracts/smf_contracts.dart';

abstract interface class FileWriteStrategy {
  Future<void> write(GeneratedFile file);
}
