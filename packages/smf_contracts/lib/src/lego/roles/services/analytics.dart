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
/// A provider contributes its implementation as a [RoleImplementation]. It
/// may also watch the router's navigators, with `when: {routerRole}`, as
/// Firebase Analytics does with `FirebaseAnalyticsObserver` in
/// [RouterRole.observers].
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
}
