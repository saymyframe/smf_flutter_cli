part of '../services.dart';

/// The analytics role; see [AnalyticsRole].
const analyticsRole = AnalyticsRole._();

/// Whether an app collects analytics before its code chose: the value of
/// [AnalyticsRole.collectionOption], and the choice of the [AnalyticsRole].
enum AnalyticsCollection {
  /// The app collects from its first start, until its code turns collection
  /// off. The default.
  on('Yes, from its first start'),

  /// The app collects nothing until its code turns collection on, as once
  /// the user agreed.
  off('No: only once your code turns it on, as after the user agrees');

  const AnalyticsCollection(this.label);

  /// The value as the question of `smf create` offers it.
  final String label;
}

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
/// `setAnalyticsCollectionEnabled` of the service is the one switch of
/// collection, for every provider of the app:
/// - Once `setAnalyticsCollectionEnabled(false)` completes, no provider
///   sends anything to its backend: neither what the app logs nor what its
///   SDK records itself, such as a screen, a session or an install. This
///   holds until `setAnalyticsCollectionEnabled(true)` completes, and the
///   reverse.
/// - Each provider keeps the setting on the device, so that it holds from
///   the first moment of every later start, before any code of the app
///   runs. No other call of the service changes it.
/// - Until the code first chose, the app collects as the constant
///   `analyticsCollectedFromFirstStart` of [file] says, which the template
///   writes from [collectionOption]. A provider whose SDK starts before
///   Dart follows that value in the native projects too, from its render
///   hook ([collectionIn]).
/// - What an SDK asks its backend for its own configuration is out of the
///   guarantee, and so are crash reports, which are the
///   [crashReportingRole]'s.
///
/// In a debug build of an app that collects nothing before its code chose,
/// `bootstrap()` prints at each start that collection waits for the code to
/// turn it on. The template also writes the section [readmeHeading] of the
/// README of the app: whether the app collects from its first start, the
/// switch, and what consent in the EEA and the UK asks of the app.
///
/// A provider contributes its implementation as a [RoleImplementation]. It
/// may also follow the router, with `when: {routerRole}`: log the screens
/// the user sees with a listener in [RouterRole.screenListeners], or watch
/// the navigators of the router with observers in [RouterRole.observers].
final class AnalyticsRole extends Role<RoleImplementation> {
  const AnalyticsRole._();

  /// The path of the file with `AnalyticsService`.
  static const file = 'lib/core/analytics/analytics_service.dart';

  /// `--analytics-collection`, whether the app collects analytics from its
  /// first start: `on`, the default, or `off`, the names of the
  /// [AnalyticsCollection]s.
  ///
  /// Some SDKs start before any Dart code runs and record an install or a
  /// session there, so only what the app was generated with can make it
  /// start with collection off: the constant that the template writes and
  /// the native defaults that such a provider writes.
  static const collectionOption = RoleOption.mode(
    name: 'analytics-collection',
    help: 'Whether the app collects analytics from its first start (on, the '
        'default), or nothing until its code turns collection on, as once '
        'the user agreed (off).',
    values: ['on', 'off'],
  );

  /// The heading of the section of the README of the app in which the
  /// template tells whether the app collects from its first start, how the
  /// code turns collection on and off, and what consent asks of the app.
  /// The section of a provider whose SDK starts before Dart, on its native
  /// lines, can refer to it.
  static const readmeHeading = 'Analytics';

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
  List<RoleOption> get options => const [collectionOption];

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

  /// Whether the app collects analytics from its first start: the choice of
  /// the role in [input], the input of a render hook of the role or of its
  /// provider.
  AnalyticsCollection collectionIn(RoleHookInput<RoleImplementation> input) =>
      input.choice! as AnalyticsCollection;
}

List<SmfIssue> _checkAnalyticsFactory(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkFactoryCalls(input, 'createAnalyticsService', AnalyticsRole.file);

/// What `bootstrap()` of a debug build of an app that collects nothing
/// before its code chose prints at each start.
const _collectionOffMessage = 'Analytics: this app collects nothing on a '
    'device until its code turns collection on there with '
    'setAnalyticsCollectionEnabled(true), as once the user agreed. See the '
    'section ${AnalyticsRole.readmeHeading} of README.md.';

/// The section of the role in the README of an app that collects as
/// [collection] says from its first start: what the app does before its
/// code chose, the switch, which every provider keeps, how to change what
/// the app does before its code chose, consent in the EEA and the UK, the
/// switch that withdraws consent, the privacy policy, and what the setting
/// does not cover. It holds with every provider and names none.
String _analyticsReadmeSection(AnalyticsCollection collection) {
  final option = '--${AnalyticsRole.collectionOption.name}';
  final mode = switch (collection) {
    AnalyticsCollection.on => 'This app was generated with `$option=on`: it '
        'collects analytics from its first start, until its code turns '
        'collection off. `analyticsCollectedFromFirstStart` in '
        '`${AnalyticsRole.file}` is `true`.',
    AnalyticsCollection.off => 'This app was generated with `$option=off`: it '
        'collects nothing until its code turns collection on, as once the '
        'user agreed. `analyticsCollectedFromFirstStart` in '
        '`${AnalyticsRole.file}` is `false`, and a debug build prints a line '
        'at each start that says so.',
  };
  return '''
$mode

`setAnalyticsCollectionEnabled()` of the analytics service is the one switch, for every provider of the app. Once a call with `false` completes, no provider sends anything to its backend, neither what the app logs nor what an SDK records itself, such as a screen or a session, until a call with `true` completes. Every provider keeps the setting on the device, so what the code chose holds from the first moment of every later start. `analyticsCollectedFromFirstStart` applies only on a device where the code never chose.

Off means that nothing is sent. It does not mean that no SDK writes to the device: an SDK keeps at least the setting there.

To change what the app does before its code chose, change `analyticsCollectedFromFirstStart`, and the native lines of each provider whose SDK starts before Dart, which its section of this README names. Or generate the app again with the other value of `$option`.

In the European Economic Area, the ePrivacy rules generally need the consent of the user before an app stores or reads analytics data on the device. In the UK, the Privacy and Electronic Communications Regulations, as the Data (Use and Access) Act 2025 amended them, let some analytics run without consent: storage whose only purpose is statistics on how the app is used, to improve it, as long as the user gets clear information about it and a simple and free way to object. The guidance of the ICO tells what qualifies. Where consent is needed, generate the app with `$option=off`, ask the user in a screen of your own, such as a page of the onboarding, and call `setAnalyticsCollectionEnabled(true)` once the user agreed. SMF shows no consent dialog.

Apple's App Review Guideline 5.1.1(ii) asks for an easily accessible and understandable way to withdraw consent: give the settings screen a switch that calls `setAnalyticsCollectionEnabled()`.

The App Store and Google Play ask for a link to a privacy policy in the listing of the app and inside the app. Say there what the analytics of the app collect.

Crash reports are another role, which this setting does not stop.

This is not legal advice.
''';
}

final class _AnalyticsTemplate extends _ServiceTemplate<RoleImplementation> {
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
- `setAnalyticsCollectionEnabled()` is the one switch of collection, and every provider keeps it on the device across starts. Until the code first chose, the app collects as `analyticsCollectedFromFirstStart` in that file says, and a provider whose SDK starts before Dart has native lines for it, which its section of `README.md` names. Change them together.
- A new provider implements `$service`. The function that creates it gets an entry in `$variable` in that file, `?_createAlone('<name>', <function>)`, or, if it starts asynchronously, one in `$initFunction()`, which the file has once a provider needs it.
''';

  /// Whether the app collects from its first start: the value of
  /// [AnalyticsRole.collectionOption], or its first value, which the
  /// question offers first and which a run without a terminal takes without
  /// asking.
  @override
  Future<Object?> choose(RoleChoiceContext<RoleImplementation> context) async {
    final given = context.option(AnalyticsRole.collectionOption.name);
    if (given != null) return AnalyticsCollection.values.byName(given);
    final environment = context.environment;
    if (!environment.interactive) return AnalyticsCollection.values.first;
    return environment.prompter.select<AnalyticsCollection>(
      'Does the app collect analytics before the user agrees?',
      AnalyticsCollection.values,
      display: (collection) => collection.label,
      defaultValue: AnalyticsCollection.values.first,
    );
  }

  @override
  Map<String, String> optionsOf(Object? choice) => {
        AnalyticsRole.collectionOption.name:
            (choice! as AnalyticsCollection).name,
      };

  /// The implementations, whether the app collects from its first start as
  /// the value of the constant `analyticsCollectedFromFirstStart`, the
  /// section of the role in the README of the app, and, in an app that
  /// collects nothing before its code chose, the line that `bootstrap()` of
  /// a debug build prints about it.
  @override
  RoleOutput render(RoleHookInput<RoleImplementation> input) {
    final collection = analyticsRole.collectionIn(input);
    return RoleOutput(
      fragments: [
        ...super.render(input).fragments,
        if (collection == AnalyticsCollection.off)
          SocketContribution.code(
            AppEntryRole.bootstrapEarly,
            Fragment(
              'if (kDebugMode && !analyticsCollectedFromFirstStart) {\n'
              '  debugPrint(${SmfNames.dartString(_collectionOffMessage)});\n'
              '}',
              imports: [_foundation, import],
            ),
          ),
        AppEntryRole.readmeSections.entry(
          AnalyticsRole.readmeHeading,
          _analyticsReadmeSection(collection),
        ),
      ],
      vars: {
        'analytics_collected_from_first_start':
            collection == AnalyticsCollection.on,
      },
    );
  }
}
