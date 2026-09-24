import 'package:mason/mason.dart' show MasonBundle;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('BrickContribution', () {
    test('overwrites existing files and adds no vars by default', () {
      final brick = BrickContribution(
        name: 'b',
        bundle:
            const MasonBundle(name: 'b', description: 'B', version: '0.1.0'),
      );

      expect(brick.mergeStrategy, FileMergeStrategy.overwrite);
      expect(brick.vars, isNull);
    });
  });
}
