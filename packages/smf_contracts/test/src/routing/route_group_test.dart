import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('RouteGroup', () {
    test('empty has no routes, initial route or guards', () {
      final group = RouteGroup.empty();

      expect(group.routes, isEmpty);
      expect(group.initialRoute, isNull);
      expect(group.coreGuards, isEmpty);
    });
  });
}
