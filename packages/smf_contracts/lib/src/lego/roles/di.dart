import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/di_role_bundle.dart';
import 'package:smf_contracts/lego.dart';

part 'di/di_dsl.dart';
part 'di/di_graph.dart';

/// The DI role; see [DiRole].
const diRole = DiRole._();

/// The role of the app's dependency injection: a service locator, such as
/// get_it, that creates the app's services and gives them what they need.
///
/// Modules register their services as [DiRegistration]s, and the provider
/// renders them in the form of its container. The role abstracts how
/// services are registered, not how they are consumed: code gets its
/// services as parameters of its factory function (see
/// [FactoryRef.deps]), and only the composition file of a feature resolves
/// them itself, to create what the feature's screens need, such as a Cubit.
/// Consumption through widgets, as with Riverpod or provider, is not part of
/// this role.
///
/// The role's template generates `lib/core/di/service_locator.dart` with
/// the `ServiceLocator` interface, the instance `serviceLocator` created by
/// the provider's [createServiceLocator], and the top-level functions
/// `resolve<T>({instanceName})` and `resolveWith<T>(param1, [param2])`. It
/// also calls the provider's [registerDependencies] in the DI phase of
/// `bootstrap()`.
///
/// A provider extends [DiProvider], renders the registrations of
/// [graphOf] in [DiGraph.ordered] order, makes each singleton wait for the
/// services of [DiGraph.dependsOnOf], and, if [DiGraph.needsAllReady], ends
/// `registerDependencies()` by waiting until all services are ready.
final class DiRole extends Role<DiRegistration> {
  const DiRole._();

  /// The path of the file with `ServiceLocator` and `resolve`.
  static const serviceLocatorFile = 'lib/core/di/service_locator.dart';

  /// The path of the provider's file with [createServiceLocator] and
  /// [registerDependencies].
  static const dependenciesFile = 'lib/core/di/dependencies.dart';

  /// `ServiceLocator createServiceLocator()`, which creates the provider's
  /// implementation of `ServiceLocator` on the first use of
  /// `serviceLocator`.
  static const createServiceLocator = RequiredFunction(
    'createServiceLocator',
    path: dependenciesFile,
    returnType: 'ServiceLocator',
  );

  /// `Future<void> registerDependencies()`, which registers every service of
  /// the app and completes when they can be resolved.
  static const registerDependencies = RequiredFunction(
    'registerDependencies',
    path: dependenciesFile,
    returnType: 'Future<void>',
  );

  @override
  String get id => 'di';

  @override
  String get description => 'Dependency injection';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  RoleInterface get interface => const RoleInterface(
        files: [serviceLocatorFile],
        symbols: [createServiceLocator, registerDependencies],
      );

  @override
  RoleTemplate<DiRegistration> get template => const _DiTemplate();

  @override
  List<StructuralRule<DiRegistration>> get structuralRules => const [
        StructuralRule(
          id: 'di.resolve_in_composition_files',
          description: 'Only the composition file of a feature resolves '
              'services; other code receives them through its factory.',
          check: _checkResolve,
        ),
      ];

  /// The registrations of the app in [input], the input of a hook of this
  /// role or of its provider.
  DiGraph graphOf(RoleHookInput<Object> input) => DiGraph(dataIn(input));
}

final class _DiTemplate extends RoleTemplate<DiRegistration> {
  const _DiTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(diRoleBundle),
        SocketContribution.code(
          AppEntryRole.bootstrapDi,
          Fragment(
            'await ${DiRole.registerDependencies.name}();',
            imports: [DiRole.registerDependencies.importRef],
          ),
        ),
      ];

  @override
  List<SmfIssue> validate(RoleHookInput<DiRegistration> input) =>
      diRole.graphOf(input).issues;
}

/// A module's implementation of the [DiRole], such as get_it.
///
/// It declares what its container can do beyond the basics, and reports the
/// registrations that need more.
abstract base class DiProvider extends RoleProvider<DiRegistration> {
  /// Allows subclasses to have constant constructors.
  const DiProvider();

  @override
  Role<DiRegistration> get role => diRole;

  /// What the container can do beyond singletons, lazy singletons and
  /// factories that take services.
  Set<DiCapability> get capabilities;

  @override
  List<SmfIssue> validate(RoleHookInput<DiRegistration> input) {
    final graph = diRole.graphOf(input);
    return [
      for (final data in graph.registrations)
        for (final capability in graph.capabilitiesOf(data.value))
          if (!capabilities.contains(capability))
            SmfIssue(
              'The registration of ${data.value.key} needs '
              '${capability.name}, which the selected DI container does not '
              'support.',
              origin: data.origin,
            ),
    ];
  }
}

const _resolveNames = {'resolve', 'resolveWith'};

List<SmfIssue> _checkResolve(StructuralRuleInput<DiRegistration> input) {
  final issues = <SmfIssue>[];
  for (final MapEntry(key: path, value: file) in input.files.entries) {
    final owner = input.owners[path];
    if (owner is! ModuleOrigin) continue;
    final module = input.module(owner.module);
    final allowed = module?.kind.compositionFileOf(owner.module);
    final resolves = file.invocations.any(
          (call) =>
              (call.target == null && _resolveNames.contains(call.name)) ||
              call.target == 'serviceLocator',
        ) ||
        file.references.any(
          (reference) =>
              _resolveNames.contains(reference.name) ||
              reference.name == 'serviceLocator',
        ) ||
        file.memberAccesses.any((access) => access.target == 'serviceLocator');
    if (!resolves) continue;
    if (path == allowed) {
      if (!(module?.effectiveRequires.contains(diRole) ?? false)) {
        issues.add(
          SmfIssue(
            '$path resolves services, so the module $owner must require the '
            'DI role instead of only using it.',
            hint: 'Add diRole to the requires of the module.',
            origin: owner,
            path: path,
          ),
        );
      }
    } else {
      issues.add(
        SmfIssue(
          '$path resolves services, but only '
          '${allowed ?? 'the composition file of a feature'} may.',
          hint: 'Take the service as a parameter of the factory function '
              'and list it in FactoryRef.deps.',
          origin: owner,
          path: path,
        ),
      );
    }
  }
  return issues;
}
