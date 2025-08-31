import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:test/test.dart';

class TestModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  TestModule(this._descriptor);

  final ModuleDescriptor _descriptor;

  @override
  ModuleDescriptor get moduleDescriptor => _descriptor;
}

IModuleCodeContributor makeModule(
  String name, {
  Set<String> dependsOn = const <String>{},
}) =>
    TestModule(
        ModuleDescriptor(name: name, description: name, dependsOn: dependsOn));

void main() {
  group('ModuleDependencyResolver', () {
    const resolver = ModuleDependencyResolver();

    test('returns input when there are no dependencies', () {
      final a = makeModule('a');
      final b = makeModule('b');

      final result = resolver.resolve([a, b]);
      expect(result, containsAll([a, b]));
    });

    test('orders dependencies before dependents', () {
      final a = makeModule('a');
      final b = makeModule('b', dependsOn: {'a'});

      final result = resolver.resolve([b, a]);
      final names = result.map((m) => m.moduleDescriptor.name).toList();
      final indexA = names.indexOf('a');
      final indexB = names.indexOf('b');
      expect(indexA, lessThan(indexB));
    });

    test('handles deep chains', () {
      final a = makeModule('a');
      final b = makeModule('b', dependsOn: {'a'});
      final c = makeModule('c', dependsOn: {'b'});
      final d = makeModule('d', dependsOn: {'c'});

      final result = resolver.resolve([d, c, b, a]);
      final names = result.map((m) => m.moduleDescriptor.name).toList();
      expect(names, equals(['a', 'b', 'c', 'd']));
    });

    test('ignores dependencies that are not in the input set', () {
      final a = makeModule('a', dependsOn: {'ghost'});
      final result = resolver.resolve([a]);
      expect(result.first, equals(a));
    });
  });
}
