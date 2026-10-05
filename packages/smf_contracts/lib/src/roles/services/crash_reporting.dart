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
/// - `installCrashReporting()`, which reports the errors of the main
///   isolate that the app does not handle, once each, through
///   `FlutterError.onError` for the errors that Flutter catches and
///   `PlatformDispatcher.instance.onError` for the others.
///
/// `bootstrap()` calls `installCrashReporting()` in its platform phase,
/// after the providers and the modules they depend on have set up their
/// SDKs, and after awaiting `initCrashReporting()` if some implementations
/// are created asynchronously. The handlers belong to the role, so a
/// provider whose SDK installs global handlers of its own turns them off.
/// The handlers also show the errors: Flutter presents the errors it
/// catches as it does by default, and in debug mode the engine prints the
/// others. So an implementation only reports, and prints nothing. The
/// handlers cover the main isolate only: `compute()` and `Isolate.run()`
/// throw the errors of their isolates to the code that awaits them, and
/// the app reports the errors of an isolate it spawns itself through the
/// error listener of that isolate. With a DI container, the reporter is
/// registered as a lazy singleton.
///
/// The reporter of the app calls each implementation on its own, and never
/// fails: an implementation that throws, or whose future fails, keeps no
/// other from a report, and its failure reaches neither the code that
/// called nor the handlers. The handlers do not await their reports, so the
/// failure would come back to them as an error that nothing catches, and
/// they would report it to the same implementation again, without end. In
/// debug mode the reporter prints the failure, so that an implementation
/// that does not work shows in the console. An implementation whose
/// factory throws, or whose asynchronous start fails, is left out, and the
/// app starts, installs the handlers and reports to the others (see
/// [RoleImplementation]).
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

  @override
  List<StructuralRule<RoleImplementation>> get structuralRules => const [
        StructuralRule(
          id: 'crash_reporting.factory_calls',
          description: 'Only the DI container calls createCrashReporter().',
          check: _checkCrashReportingFactory,
        ),
        StructuralRule(
          id: 'crash_reporting.implementation_factories',
          description: 'The function of every implementation is in its file '
              'and takes no arguments.',
          check: _checkImplementationFactories,
        ),
      ];
}

List<SmfIssue> _checkCrashReportingFactory(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkFactoryCalls(input, 'createCrashReporter', CrashReportingRole.file);

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

  @override
  String get agentNote => '''
- `installCrashReporting()` of `$file`, which `${AppEntryRole.bootstrap.name}()` calls, reports the errors of the main isolate that nothing handles, through `FlutterError.onError` and `PlatformDispatcher.instance.onError`. Set these two nowhere else.
- Report an error that the code catches with `recordError()` of `$service`. `$factory()` returns the one reporter of the app, which reports to every provider and never fails. Call it where the state of a screen is created, or, with a DI container in the app, take the reporter from the container instead.
- A new provider implements `$service`. The function that creates it gets an entry in `$variable` in that file, `?_createAlone('<name>', <function>)`, or, if it starts asynchronously, one in `$initFunction()`, which the file has once a provider needs it.
''';
}
