import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';

abstract class Generator {
  Future<void> generate(
    List<IModuleCodeContributor> modules,
    Logger logger,
    Map<String, dynamic> coreVars,
    String generateTo,
  );

  FileConflictResolution mapMergeStrategy(FileMergeStrategy strategy) {
    switch (strategy) {
      case FileMergeStrategy.appendToFile:
        return FileConflictResolution.append;
      case FileMergeStrategy.injectByTag:
        return FileConflictResolution.prompt;
      case FileMergeStrategy.overwrite:
    }

    return FileConflictResolution.overwrite;
  }
}
