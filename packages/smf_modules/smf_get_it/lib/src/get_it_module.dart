import 'package:smf_contracts/lego.dart';
import 'package:smf_get_it/bundles/get_it_bundle.dart';
import 'package:smf_get_it/src/registrations.dart';

/// The module that provides dependency injection with get_it, and so the DI
/// role.
///
/// It adds `get_it` to the dependencies of the app and generates
/// `lib/core/di/dependencies.dart`: `createServiceLocator()`, whose
/// `resolve` and `resolveWith` find the services in the global instance of
/// get_it, and `registerDependencies()`, which the app runs before its first
/// frame. It registers the services that the modules of the app declare,
/// each after the services it takes or waits for, since get_it creates a
/// singleton while it is registered:
/// - a singleton with `registerSingleton`, or, if it has to wait for
///   services that are created asynchronously, with
///   `registerSingletonWithDependencies`, or with `registerSingletonAsync`
///   when it is created asynchronously itself; it waits for the services it
///   names and for those it takes, directly or through lazy singletons and
///   factories, that are created asynchronously or wait themselves;
/// - a lazy singleton with `registerLazySingleton`;
/// - a factory with `registerFactory`, or with `registerFactoryParam` when
///   it takes parameters, `void` standing for a second one it does not
///   take.
///
/// Each factory function gets its services from get_it, by type and by
/// name, then the parameters of the registration. A function that disposes
/// of a service goes to get_it with it, and `registerDependencies()` waits
/// until every service is ready when some are created asynchronously.
///
/// The file imports the file of every type and function it names with a
/// prefix of its own, so their names never clash.
final class GetItModule extends SmfModule {
  /// Creates the module.
  const GetItModule();

  /// The id of the module.
  static const id = ModuleId('get_it');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Service locator with get_it',
        kind: ModuleKinds.infrastructure,
        providers: [_GetItProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(getItBundle),
        const PubspecContribution.hosted('get_it', '^9.3.0'),
      ];
}

/// Renders the registrations of the app into the brick of the module.
final class _GetItProvider extends DiProvider {
  const _GetItProvider();

  @override
  Set<DiCapability> get capabilities => const {
        DiCapability.factoryWithParams,
        DiCapability.asyncInit,
        DiCapability.dependsOn,
        DiCapability.dispose,
        DiCapability.instanceName,
      };

  @override
  RoleOutput render(RoleHookInput<DiRegistration> input) => RoleOutput(
        vars: {
          'registrations': registrationsOf(
            diRole.graphOf(input),
            appName: input.context.appName,
          ),
        },
      );
}
