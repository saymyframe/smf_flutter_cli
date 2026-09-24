import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/generators/generator.dart';
import 'package:test/test.dart';

class _NoopGenerator extends Generator {
  const _NoopGenerator();

  @override
  Future<void> generate(
    List<IModuleCodeContributor> modules,
    Logger logger,
    Map<String, dynamic> coreVars,
    String generateTo,
  ) async {}
}

void main() {
  group('Generator.mapMergeStrategy', () {
    const generator = _NoopGenerator();

    test('maps overwrite to FileConflictResolution.overwrite', () {
      expect(
        generator.mapMergeStrategy(FileMergeStrategy.overwrite),
        FileConflictResolution.overwrite,
      );
    });

    test('maps appendToFile to FileConflictResolution.append', () {
      expect(
        generator.mapMergeStrategy(FileMergeStrategy.appendToFile),
        FileConflictResolution.append,
      );
    });
  });
}
