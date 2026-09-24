import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('ModuleDescriptor', () {
    test('declares no module or pub dependencies by default', () {
      const descriptor = ModuleDescriptor(name: 'a', description: 'A');

      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.pubDependency, isEmpty);
      expect(descriptor.pubDevDependency, isEmpty);
    });
  });
}
