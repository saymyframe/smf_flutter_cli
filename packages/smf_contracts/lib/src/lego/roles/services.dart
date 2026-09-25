import 'package:mason/mason.dart' show MasonBundle;
import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/analytics_role_bundle.dart';
import 'package:smf_contracts/bundles/crash_reporting_role_bundle.dart';
import 'package:smf_contracts/bundles/events_role_bundle.dart';
import 'package:smf_contracts/lego.dart';

part 'services/analytics.dart';
part 'services/crash_reporting.dart';
part 'services/events.dart';

/// The implementation of a service role that a provider contributes as its
/// data, such as the Firebase implementation of `AnalyticsService`.
///
/// The service roles are [eventsRole], [analyticsRole] and
/// [crashReportingRole]. Each generates the interface of its service and a
/// factory that returns the implementation, or, for a role with many
/// providers, one service that forwards every call to all of them. Every
/// provider contributes exactly one implementation:
///
/// ```dart
/// analyticsRole.data(
///   const RoleImplementation(
///     type: TypeRef('FirebaseAnalyticsService', import: file),
///     create: FactoryRef('createFirebaseAnalyticsService', import: file),
///   ),
/// )
/// ```
///
/// The factory takes no services: the services work without a DI
/// container. The role registers its service in the DI container when one
/// is present.
@immutable
final class RoleImplementation {
  /// An implementation of [type] that [create] returns.
  const RoleImplementation({
    required this.type,
    required FactoryRef this.create,
  }) : init = null;

  /// An implementation of [type] created asynchronously: [init] returns a
  /// `Future` of it, which the role awaits in the platform phase of
  /// `bootstrap()`.
  const RoleImplementation.async({
    required this.type,
    required FactoryRef this.init,
  }) : create = null;

  /// The class of the implementation.
  final TypeRef type;

  /// The function that returns the implementation, if it is created
  /// synchronously.
  final FactoryRef? create;

  /// The function that returns a `Future` of the implementation, if it is
  /// created asynchronously.
  final FactoryRef? init;

  /// Whether the implementation is created asynchronously.
  bool get isAsync => init != null;

  /// The function that creates the implementation: [create] or [init].
  FactoryRef get factory => create ?? init!;

  /// Describes what is wrong with the implementation, or returns an empty
  /// list.
  List<String> problems() => [
        ...type.problems(),
        ...factory.problems(),
        if (factory.deps.isNotEmpty)
          'The factory ${factory.name} of $type must take no services.',
      ];

  @override
  String toString() => 'implementation $type';
}

List<SmfIssue> _checkImplementations(
  ModuleRuleInput<RoleImplementation> input,
) {
  final role = input.roleInput.role;
  final provides = input.module.provides.contains(role);
  final origin = ModuleOrigin(input.module.id);
  return [
    if (!provides && input.data.isNotEmpty)
      SmfIssue(
        'The module contributes an implementation to the $role, which only '
        'its providers do.',
        origin: origin,
      ),
    if (provides && input.data.length != 1)
      SmfIssue(
        'A provider of the $role contributes exactly one implementation, but '
        'the module contributes ${input.data.length}.',
        origin: origin,
      ),
  ];
}

const _implementationsRule = ModuleRule<RoleImplementation>(
  id: 'services.implementations',
  description: 'Every provider of a service role, and only a provider, '
      'contributes one implementation.',
  check: _checkImplementations,
);

/// The template shared by the service roles: the brick with the service's
/// interface, the implementations in the socket [implementations], and the
/// registration of the service in the DI container.
abstract base class _ServiceTemplate extends RoleTemplate<RoleImplementation> {
  const _ServiceTemplate();

  Role<RoleImplementation> get role;

  MasonBundle get bundle;

  /// The path of the file of the brick, relative to the project root.
  String get file;

  /// The interface of the service, such as `AnalyticsService`.
  String get service;

  /// The function that returns the service, such as
  /// `createAnalyticsService`.
  String get factory;

  /// The function that creates the implementations created asynchronously,
  /// such as `initAnalytics`.
  String get initFunction;

  /// The name of the private variable with the implementations, or with the
  /// only implementation for a role with at most one provider.
  String get variable;

  SocketRef<CodeSocket> get implementations;

  ImportRef get import => ImportRef.app(file.substring('lib/'.length));

  bool get single => !role.cardinality.allowsMany;

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bundle),
        diRole.data(
          DiRegistration(
            type: TypeRef(service, import: import),
            create: FactoryRef(factory, import: import),
          ),
        ),
      ];

  /// Checks each implementation; the module rule of the role checks that
  /// every provider contributes exactly one.
  @override
  List<SmfIssue> validate(RoleHookInput<RoleImplementation> input) => [
        for (final data in input.data)
          for (final problem in data.value.problems())
            SmfIssue(problem, origin: data.origin),
      ];

  @override
  RoleOutput render(RoleHookInput<RoleImplementation> input) {
    final all = [for (final data in input.data) data.value];
    final asynchronous = [
      for (final implementation in all)
        if (implementation.isAsync) implementation,
    ];
    return RoleOutput(
      fragments: [
        SocketContribution.code(
          implementations,
          Fragment(
            single ? _single(all) : _many(all),
            imports: [
              for (final implementation in all) implementation.factory.import,
            ],
          ),
        ),
        if (bootstrap(hasAsync: asynchronous.isNotEmpty) case final code?)
          SocketContribution.code(
            AppEntryRole.bootstrapPlatform,
            Fragment(code, imports: [import]),
          ),
      ],
    );
  }

  /// The code of the platform phase of `bootstrap()`, or `null` if the role
  /// needs none.
  String? bootstrap({required bool hasAsync}) =>
      hasAsync ? 'await $initFunction();' : null;

  String _single(List<RoleImplementation> all) {
    if (all.isEmpty) return '';
    final implementation = all.single;
    final factory = implementation.factory.code;
    if (!implementation.isAsync) {
      return 'final $service $variable = $factory();';
    }
    return '''
late final $service $variable;

/// Creates the $service of the app, which starts asynchronously;
/// `bootstrap()` awaits it.
Future<void> $initFunction() async {
  $variable = await $factory();
}''';
  }

  String _many(List<RoleImplementation> all) {
    final buffer = StringBuffer('final List<$service> $variable = [\n');
    for (final implementation in all) {
      if (!implementation.isAsync) {
        buffer.writeln('  ${implementation.factory.code}(),');
      }
    }
    buffer.write('];');
    final asynchronous = [
      for (final implementation in all)
        if (implementation.isAsync) implementation,
    ];
    if (asynchronous.isEmpty) return buffer.toString();
    buffer
      ..writeln()
      ..writeln()
      ..writeln('/// Creates the implementations of $service that start')
      ..writeln('/// asynchronously; `bootstrap()` awaits it.')
      ..writeln('Future<void> $initFunction() async {')
      ..writeln('  $variable.addAll(')
      ..writeln('    await Future.wait<$service>([');
    for (final implementation in asynchronous) {
      buffer.writeln('      ${implementation.factory.code}(),');
    }
    buffer
      ..writeln('    ]),')
      ..writeln('  );')
      ..write('}');
    return buffer.toString();
  }
}
