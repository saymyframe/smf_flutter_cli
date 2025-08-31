import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/promts/models/cli_context.dart';
import 'package:smf_flutter_cli/utils/module_creator.dart';
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

class TestFactory implements IModuleContributorFactory {
  TestFactory({
    required this.name,
    required this.description,
    this.dependsOn = const <String>{},
    this.supportsProfile = true,
  });

  final String name;
  final String description;
  final Set<String> dependsOn;
  final bool supportsProfile;

  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    return TestModule(
      ModuleDescriptor(
        name: name,
        description: description,
        dependsOn: dependsOn,
      ),
    );
  }

  @override
  bool supports(ModuleProfile profile) => supportsProfile;
}

void main() {
  group('ModuleCreator', () {
    late Map<String, IModuleContributorFactory> registry;
    late ModuleCreator creator;
    late ModuleDependencyResolver resolver;
    const profile = ModuleProfile(stateManager: StateManager.bloc);

    setUp(() {
      registry = <String, IModuleContributorFactory>{};
      resolver = const ModuleDependencyResolver();
      creator = ModuleCreator(
        resolver,
        registry,
      );
    });

    test('includes core via constructor-provided keys', () {
      creator = ModuleCreator(
        resolver,
        registry,
        coreModuleKeys: const ['core', 'contracts'],
      );
      registry['core'] = TestFactory(name: 'core', description: 'Core');
      registry['contracts'] =
          TestFactory(name: 'contracts', description: 'Contracts');

      final modules = creator.build(
        const <IModuleContributorFactory>[],
        profile,
        strictMode: StrictMode.lenient,
      );

      final names = modules.map((m) => m.moduleDescriptor.name).toSet();
      expect(names, containsAll(['core', 'contracts']));
    });

    test('creates dependencies from registry when only dependent is selected',
        () {
      registry['a'] =
          TestFactory(name: 'a', description: 'A', dependsOn: {'b'});
      registry['b'] = TestFactory(name: 'b', description: 'B');

      final modules = creator.build(
        <IModuleContributorFactory>[registry['a']!],
        profile,
        strictMode: StrictMode.lenient,
      );

      final names = modules.map((m) => m.moduleDescriptor.name).toList();
      expect(names, containsAll(['a', 'b']));
    });

    test('skips unsupported root in lenient mode', () {
      registry['u'] = TestFactory(
        name: 'u',
        description: 'Unsupported',
        supportsProfile: false,
      );

      final modules = creator.build(
        <IModuleContributorFactory>[registry['u']!],
        profile,
        strictMode: StrictMode.lenient,
      );

      final names = modules.map((m) => m.moduleDescriptor.name).toSet();
      expect(names.contains('u'), isFalse);
    });

    test('throws on unsupported root in strict mode', () {
      registry['u'] = TestFactory(
        name: 'u',
        description: 'Unsupported',
        supportsProfile: false,
      );

      expect(
        () => creator.build(
          <IModuleContributorFactory>[registry['u']!],
          profile,
          strictMode: StrictMode.strict,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('skips dependent when its dependency is unsupported (lenient)', () {
      registry['root'] =
          TestFactory(name: 'root', description: 'Root', dependsOn: {'dep'});
      registry['dep'] =
          TestFactory(name: 'dep', description: 'Dep', supportsProfile: false);

      final modules = creator.build(
        <IModuleContributorFactory>[registry['root']!],
        profile,
        strictMode: StrictMode.lenient,
      );

      final names = modules.map((m) => m.moduleDescriptor.name).toSet();
      expect(names.contains('root'), isFalse);
      expect(names.contains('dep'), isFalse);
    });

    test('throws when dependency is missing in registry (strict)', () {
      registry['a'] =
          TestFactory(name: 'a', description: 'A', dependsOn: {'missing'});

      expect(
        () => creator.build(
          <IModuleContributorFactory>[registry['a']!],
          profile,
          strictMode: StrictMode.strict,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('skips module when dependency is missing in registry (lenient)', () {
      registry['a'] =
          TestFactory(name: 'a', description: 'A', dependsOn: {'missing'});

      final modules = creator.build(
        <IModuleContributorFactory>[registry['a']!],
        profile,
        strictMode: StrictMode.lenient,
      );

      final names = modules.map((m) => m.moduleDescriptor.name).toSet();
      expect(names.contains('a'), isFalse);
    });

    test('deduplicates factories passed multiple times', () {
      registry['x'] = TestFactory(name: 'x', description: 'X');

      final modules = creator.build(
        <IModuleContributorFactory>[registry['x']!, registry['x']!],
        profile,
        strictMode: StrictMode.lenient,
      );

      final countX =
          modules.where((m) => m.moduleDescriptor.name == 'x').length;
      expect(countX, lessThanOrEqualTo(1));
    });
  });
}
