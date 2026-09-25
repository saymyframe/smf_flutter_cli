/// A fake DI container for the tests of the SMF pipeline. Not a module to
/// use.
///
/// It renders the registrations of the app into a map of factories, and
/// supports only the capabilities it is created with, so tests can see
/// that a registration needing another capability is rejected before
/// generation.
library;

import 'package:fake_di/bundles/fake_di_bundle.dart';
import 'package:smf_contracts/lego.dart';

/// A provider of the DI role with a configurable set of capabilities.
final class FakeDiModule extends SmfModule {
  /// Creates the module with [capabilities], all of them by default.
  const FakeDiModule({this.capabilities = _all});

  /// The id of the module.
  static const id = ModuleId('fake_di');

  static const Set<DiCapability> _all = {
    DiCapability.factoryWithParams,
    DiCapability.asyncInit,
    DiCapability.dependsOn,
    DiCapability.dispose,
    DiCapability.instanceName,
  };

  /// The capabilities of the container.
  final Set<DiCapability> capabilities;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'DI with a map of factories (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [FakeDiProvider(capabilities)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      [BrickContribution(fakeDiBundle)];
}

/// Renders the registrations of the app in the order of the DI graph.
///
/// Every file of a type or factory is imported with a prefix of its own,
/// `di0`, `di1`, ..., so names of the app never clash with each other or
/// with the container.
final class FakeDiProvider extends DiProvider {
  /// Creates the provider with [capabilities].
  const FakeDiProvider(this.capabilities);

  @override
  final Set<DiCapability> capabilities;

  @override
  RoleOutput render(RoleHookInput<DiRegistration> input) {
    final appName = input.context.appName;
    final prefixes = <String, String>{};
    String prefixOf(ImportRef import) => prefixes.putIfAbsent(
          import.resolveUri(appName),
          () => 'di${prefixes.length}',
        );
    String type(TypeRef ref) {
      final import = ref.import;
      return import == null ? ref.name : ref.codeWith(prefixOf(import));
    }

    String resolve(ServiceRef service) {
      final name = service.instanceName;
      final named =
          name == null ? '' : 'instanceName: ${SmfNames.dartString(name)}';
      return 'locator.resolve<${type(service.type)}>($named)';
    }

    final lines = <String>[];
    for (final registration in diRole.graphOf(input).ordered) {
      final serviceType = type(registration.type);
      final create = registration.create;
      final factory = create.codeWith(prefixOf(create.import));
      final deps = [for (final dep in create.deps) resolve(dep)];
      final name = registration.instanceName;
      final named = name == null ? '' : ', name: ${SmfNames.dartString(name)}';
      final params = registration.params;
      final call = '$factory(${deps.join(', ')})';
      final paramCall = '$factory(${[
        ...deps,
        if (params.isNotEmpty) 'param1 as ${type(params.first)}',
        if (params.length > 1) 'param2 as ${type(params[1])}',
      ].join(', ')})';
      lines.add(
        switch (registration.lifetime) {
          DiLifetime.singleton when registration.isAsync =>
            '  locator.singleton<$serviceType>(await $call$named);',
          DiLifetime.singleton =>
            '  locator.singleton<$serviceType>($call$named);',
          DiLifetime.lazySingleton =>
            '  locator.lazy<$serviceType>(() => $call$named);',
          DiLifetime.factory when params.isEmpty =>
            '  locator.factoryOf<$serviceType>(() => $call$named);',
          DiLifetime.factory =>
            '  locator.factoryWith<$serviceType>((param1, param2) => '
                '$paramCall$named);',
        },
      );
      if (registration.dispose case final dispose?) {
        final instance =
            name == null ? '' : 'instanceName: ${SmfNames.dartString(name)}';
        lines.add(
          '  locator.onDispose(() => '
          '${dispose.codeWith(prefixOf(dispose.import))}('
          'locator.resolve<$serviceType>($instance)));',
        );
      }
    }
    return RoleOutput(
      vars: {
        'imports': [
          for (final MapEntry(key: uri, value: prefix) in prefixes.entries)
            "import '$uri' as $prefix;",
        ].join('\n'),
        'registrations': lines.isEmpty
            ? ''
            : [
                '  final locator = serviceLocator as _MapLocator;',
                ...lines,
              ].join('\n'),
      },
    );
  }
}
