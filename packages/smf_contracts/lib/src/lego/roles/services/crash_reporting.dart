part of '../services.dart';

/// The crash reporting role; see [CrashReportingRole].
const crashReportingRole = CrashReportingRole._();

/// The role of the services that report errors of the app, such as Firebase
/// Crashlytics; an app can have any number of them.
///
/// The role's template generates `lib/core/crash_reporting/crash_reporter.dart`
/// with:
/// - the `CrashReporter` interface;
/// - `CrashReporter createCrashReporter()`, which returns one reporter that
///   forwards every call to the implementations of all providers;
/// - `installCrashReporting()`, which reports the errors that Flutter, the
///   platform dispatcher and the current isolate do not handle.
///
/// `bootstrap()` calls `installCrashReporting()` in its platform phase,
/// after the providers and the modules they depend on have set up their
/// SDKs, and after awaiting `initCrashReporting()` if some implementations
/// are created asynchronously. The handlers belong to the role, so a
/// provider whose SDK installs global handlers of its own turns them off.
/// With a DI container, the reporter is registered as a lazy singleton.
final class CrashReportingRole extends Role<RoleImplementation> {
  const CrashReportingRole._();

  /// The path of the file with `CrashReporter`.
  static const file = 'lib/core/crash_reporting/crash_reporter.dart';

  /// The implementations of the reporter, which the template renders from
  /// the providers' [RoleImplementation]s; modules do not contribute to it.
  static const implementations = SocketRef<CodeSocket>.role(
    crashReportingRole,
    'implementations',
    CodeSocket(),
  );

  @override
  String get id => 'crash_reporting';

  @override
  String get description => 'Crash reporting';

  @override
  RoleCardinality get cardinality => RoleCardinality.many;

  @override
  Set<Role> get uses => {diRole};

  @override
  List<SocketRef> get sockets => const [implementations];

  @override
  RoleInterface get interface => const RoleInterface(files: [file]);

  @override
  RoleTemplate<RoleImplementation> get template =>
      const _CrashReportingTemplate();

  @override
  List<ModuleRule<RoleImplementation>> get moduleRules =>
      const [_implementationsRule];
}

final class _CrashReportingTemplate extends _ServiceTemplate {
  const _CrashReportingTemplate();

  @override
  Role<RoleImplementation> get role => crashReportingRole;

  @override
  MasonBundle get bundle => crashReportingRoleBundle;

  @override
  String get file => CrashReportingRole.file;

  @override
  String get service => 'CrashReporter';

  @override
  String get factory => 'createCrashReporter';

  @override
  String get initFunction => 'initCrashReporting';

  @override
  String get variable => '_crashReporters';

  @override
  SocketRef<CodeSocket> get implementations =>
      CrashReportingRole.implementations;

  @override
  String bootstrap({required bool hasAsync}) => [
        if (hasAsync) 'await $initFunction();',
        'installCrashReporting();',
      ].join('\n');
}
