import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

class _DescriptorOnlyModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  @override
  ModuleDescriptor get moduleDescriptor =>
      const ModuleDescriptor(name: 'bare', description: 'Bare module');
}

void main() {
  group('EmptyModuleCodeContributor', () {
    test('contributes nothing besides its descriptor', () {
      final module = _DescriptorOnlyModule();

      expect(module.moduleDescriptor.name, 'bare');
      expect(module.brickContributions, isEmpty);
      expect(module.sharedFileContributions, isEmpty);
      expect(module.di, isEmpty);
      expect(module.routes.routes, isEmpty);
      expect(module.routes.initialRoute, isNull);
    });
  });
}
