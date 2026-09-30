import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/di_role_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contracts/src/roles/symbol_uses.dart';

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
/// [FactoryRef.deps]), and only the composition file of a feature (see
/// [CompositionFile]) resolves them itself, to create what the feature's
/// screens need, such as a Cubit.
/// Consumption through widgets, as with Riverpod or provider, is not part of
/// this role.
///
/// The role's template generates `lib/core/di/service_locator.dart` with
/// the `ServiceLocator` interface, the instance `serviceLocator` created by
/// the provider's [createServiceLocator], and the top-level function
/// `resolve<T>({instanceName})`. It also calls the provider's
/// [registerDependencies] in the DI phase of `bootstrap()`.
///
/// A provider extends [DiProvider], renders the registrations of
/// [graphOf] in [DiGraph.ordered] order, makes each singleton wait for the
/// services of [DiGraph.dependsOnOf], and, if [DiGraph.needsAllReady], ends
/// `registerDependencies()` by waiting until all services are ready. Its
/// files call or tear off the factory of every registration and its
/// dispose function, which the contract harness checks, so the tests of a
/// module that registers a service check the registration through
/// [graphOf], not in the files of a provider. Its [resetDependencies]
/// disposes of the services that the container created and removes every
/// service, so that `registerDependencies()` can register them again.
final class DiRole extends Role<DiRegistration> {
  const DiRole._();

  /// The path of the file with `ServiceLocator` and `resolve`.
  static const serviceLocatorFile = 'lib/core/di/service_locator.dart';

  /// The path of the provider's file with [createServiceLocator],
  /// [registerDependencies] and [resetDependencies].
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

  /// `Future<void> resetDependencies()`, which disposes of the services
  /// that the container created, with the [DiRegistration.dispose] function
  /// of each, in the reverse order of their registration, and then removes
  /// every service, so that [registerDependencies] can register them again.
  ///
  /// It creates no service: a lazy singleton that was never resolved is
  /// neither created nor disposed of. The app itself does not call it; its
  /// tests do, such as a test that registers the services again.
  static const resetDependencies = RequiredFunction(
    'resetDependencies',
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
        symbols: [
          createServiceLocator,
          registerDependencies,
          resetDependencies,
        ],
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
        StructuralRule(
          id: 'di.factories',
          description: 'The factory of every registration is a top-level '
              'function in its file that takes the dependencies of the '
              'registration, and its dispose function takes the service.',
          check: _checkFactories,
        ),
        StructuralRule(
          id: 'di.registrations_rendered',
          description: 'The files of the provider of the role call or tear '
              'off the factory of every registration, and its dispose '
              'function.',
          check: _checkRendered,
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
/// registrations that need more. Its `dependencies.dart` imports the file of
/// every type and function that the registrations name with a prefix of its
/// own, such as `di0` for the first file, and refers to them with
/// [TypeRef.codeWith], [FactoryRef.codeWith] and [FunctionRef.codeWith], so
/// names of different modules never collide with each other or with the
/// names of the file.
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

/// The file where a module of a kind may resolve services, such as the
/// composition file of a feature, which creates what its screens need.
///
/// A kind lists it in [ModuleKind.roleRules]. A module of the kind may
/// resolve services in this file and nowhere else, and only if it requires
/// the [DiRole]; a module of a kind without it resolves no service itself.
/// Other code gets its services as parameters of its factory function (see
/// [FactoryRef.deps]).
final class CompositionFile extends KindRule {
  /// Creates the rule for the file at [path].
  const CompositionFile(this.path);

  /// The path of the file relative to the project root, where `<id>` stands
  /// for the module id, such as `lib/features/<id>/<id>_composition.dart`.
  final String path;

  @override
  Role get role => diRole;

  /// [path] for the module [module].
  String pathOf(ModuleId module) => path.replaceAll('<id>', module.value);
}

const _resolveNames = {'resolve', 'serviceLocator'};

/// Whether [file] resolves services: it calls, tears off or reads `resolve`
/// or `serviceLocator` of the service locator's file, which it imports with
/// or without a prefix.
bool _resolves(DartFileIndex file) =>
    usesSymbols(file, _resolveNames, DiRole.serviceLocatorFile);

List<SmfIssue> _checkResolve(StructuralRuleInput<DiRegistration> input) {
  final issues = <SmfIssue>[];
  for (final MapEntry(key: path, value: file) in input.files.entries) {
    final owner = input.owners[path];
    if (owner is! ModuleOrigin) continue;
    final module = input.module(owner.module);
    // The container implements resolving itself.
    if (module?.provides.contains(diRole) ?? false) continue;
    final allowed =
        module?.kind.ruleOf<CompositionFile>()?.pathOf(owner.module);
    if (!_resolves(file)) continue;
    if (path == allowed) {
      if (!(module?.effectiveRequires.contains(diRole) ?? false)) {
        issues.add(
          SmfIssue(
            '$path resolves services, so the module $owner must require the '
            '$diRole instead of only using it.',
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

/// The problems with the functions that registrations name: a factory or a
/// dispose function that is missing from its file of the app, a factory
/// that cannot take its dependencies as positional arguments, and a dispose
/// function that cannot take the service.
///
/// Functions from other packages are left to the compiler.
List<SmfIssue> _checkFactories(StructuralRuleInput<DiRegistration> input) {
  final issues = <SmfIssue>[];
  void check(
    String name,
    ImportRef import, {
    required int arguments,
    required String hint,
    required ContributionOrigin? origin,
  }) {
    if (!import.isAppFile) return;
    final symbol = RequiredFunction(
      name,
      path: 'lib/${import.uri}',
      positionalArguments: arguments,
    );
    for (final issue in symbol.checkIn(input.files)) {
      issues.add(
        SmfIssue(issue.message, hint: hint, origin: origin, path: issue.path),
      );
    }
  }

  for (final data in diRole.graphOf(input.roleInput).registrations) {
    final registration = data.value;
    final create = registration.create;
    check(
      create.name,
      create.import,
      arguments: create.deps.length,
      hint: 'The pipeline calls it with the dependencies of the registration.',
      origin: data.origin,
    );
    if (registration.dispose case final dispose?) {
      check(
        dispose.name,
        dispose.import,
        arguments: 1,
        hint: 'The container calls it with the service of the registration '
            'when it disposes of the service.',
        origin: data.origin,
      );
    }
  }
  return issues;
}

/// The registrations that the provider of the role does not render: those
/// whose factory, or dispose function, none of the files of the provider
/// calls or tears off, through an import of the file or library that
/// declares it.
///
/// So no provider leaves out a service that a module declares, and the
/// tests of the modules need not look into the files of any provider.
/// Without the descriptor of a provider in [input], no file renders the
/// registrations and there is nothing to check.
List<SmfIssue> _checkRendered(StructuralRuleInput<DiRegistration> input) {
  final providers = {
    for (final module in input.modules)
      if (module.provides.contains(diRole)) module.id,
  };
  if (providers.isEmpty) return const [];
  final files = [
    for (final MapEntry(key: path, value: file) in input.files.entries)
      if (input.owners[path] case ModuleOrigin(:final module)
          when providers.contains(module))
        file,
  ];
  final issues = <SmfIssue>[];
  void check(
    RoleData<DiRegistration> data,
    String function,
    String name,
    ImportRef import,
  ) {
    if (files.any((file) => usesImported(file, name, import))) return;
    final library = import.isAppFile ? 'lib/${import.uri}' : import.uri;
    issues.add(
      SmfIssue(
        'The provider of the $diRole does not render the ${data.value}: '
        'none of its files calls or tears off its $function $name() of '
        '$library.',
        hint: 'Register every service of DiRole.graphOf() with a call or a '
            'tear-off of its factory, and of its dispose function if it has '
            'one.',
        origin: data.origin,
        path: DiRole.dependenciesFile,
      ),
    );
  }

  for (final data in diRole.graphOf(input.roleInput).registrations) {
    final registration = data.value;
    final create = registration.create;
    check(data, 'factory', create.name, create.import);
    if (registration.dispose case final dispose?) {
      check(data, 'dispose function', dispose.name, dispose.import);
    }
  }
  return issues;
}
