import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('every module follows the rules of its roles in every app', () async {
    final results =
        await ContractHarness(ModuleRegistry(smfModules)).checkAll();

    expect(results, isNotEmpty);
    for (final result in results) {
      expect(
        result.errors.map((issue) => '$issue'),
        isEmpty,
        reason: '$result',
      );
      expect(result.app, isNotNull, reason: '$result');
    }
  });
}
