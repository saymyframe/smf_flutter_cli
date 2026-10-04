part of '../services.dart';

/// The analytics role; see [AnalyticsRole].
const analyticsRole = AnalyticsRole._();

/// The role of the services that record what users do in the app, such as
/// Firebase Analytics; an app can have any number of them.
///
/// The role's template generates `lib/core/analytics/analytics_service.dart`
/// with the `AnalyticsService` interface and
/// `AnalyticsService createAnalyticsService()`, which returns one service
/// that forwards every call to the implementations of all providers. If
/// some are created asynchronously, `bootstrap()` awaits `initAnalytics()`
/// in its platform phase. With a DI container, the service is registered as
/// a lazy singleton.
///
/// The service of the app calls each implementation on its own, and never
/// fails: an implementation that throws, or whose future fails, keeps no
/// other from the call, and its failure does not reach the code that
/// called. That code may not await the call, and then the failure would be
/// an error that nothing catches, which crash reporting reports. In debug
/// mode the service prints the failure, so that an implementation that
/// does not work shows in the console. Each implementation gets a copy of
/// its own of the map of parameters of a call, so that one that changes the
/// map, such as to add a parameter of its own, changes nothing that the
/// caller or another implementation has. An implementation whose factory
/// throws, or whose asynchronous start fails, is left out, and the app
/// starts and works with the others (see [RoleImplementation]).
///
/// A provider contributes its implementation as a [RoleImplementation]. It
/// may also follow the router, with `when: {routerRole}`: log the screens
/// the user sees with a listener in [RouterRole.screenListeners], or watch
/// the navigators of the router with observers in [RouterRole.observers].
final class AnalyticsRole extends Role<RoleImplementation> {
  const AnalyticsRole._();

  /// The path of the file with `AnalyticsService`.
  static const file = 'lib/core/analytics/analytics_service.dart';

  /// The implementations of the service, which the template renders from
  /// the providers' [RoleImplementation]s; modules do not contribute to it.
  static const implementations = SocketRef<CodeSocket>.role(
    analyticsRole,
    'implementations',
    CodeSocket(),
  );

  @override
  String get id => 'analytics';

  @override
  String get description => 'Analytics';

  @override
  RoleCardinality get cardinality => RoleCardinality.many;

  @override
  Set<Role> get uses => {diRole, routerRole};

  @override
  List<SocketRef> get sockets => const [implementations];

  @override
  RoleInterface get interface => const RoleInterface(files: [file]);

  @override
  RoleTemplate<RoleImplementation> get template => const _AnalyticsTemplate();

  @override
  List<ModuleRule<RoleImplementation>> get moduleRules =>
      const [_implementationsRule];

  @override
  List<StructuralRule<RoleImplementation>> get structuralRules => const [
        StructuralRule(
          id: 'analytics.factory_calls',
          description: 'Only the DI container calls createAnalyticsService().',
          check: _checkAnalyticsFactory,
        ),
        StructuralRule(
          id: 'analytics.implementation_factories',
          description: 'The function of every implementation is in its file '
              'and takes no arguments.',
          check: _checkImplementationFactories,
        ),
      ];
}

List<SmfIssue> _checkAnalyticsFactory(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkFactoryCalls(input, 'createAnalyticsService', AnalyticsRole.file);

final class _AnalyticsTemplate extends _ServiceTemplate {
  const _AnalyticsTemplate();

  @override
  Role<RoleImplementation> get role => analyticsRole;

  @override
  MasonBundle get bundle => analyticsRoleBundle;

  @override
  String get file => AnalyticsRole.file;

  @override
  String get service => 'AnalyticsService';

  @override
  String get factory => 'createAnalyticsService';

  @override
  String get initFunction => 'initAnalytics';

  @override
  String get variable => '_analyticsServices';

  @override
  SocketRef<CodeSocket> get implementations => AnalyticsRole.implementations;

  @override
  String get agentNote => '''
- Record what users do through `$service` of `$file`, never through the SDK of a provider. `$factory()` returns the one service of the app. Call it where the state of a screen is created, or, with a DI container in the app, take the service from the container instead.
- The service never fails, and you need not await a call: in debug mode it prints the failure of a provider.
- A new provider implements `$service`. The function that creates it gets an entry in `$variable` in that file, `?_createAlone('<name>', <function>)`, or, if it starts asynchronously, one in `$initFunction()`, which the file has once a provider needs it.
''';
}
