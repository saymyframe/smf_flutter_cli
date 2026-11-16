@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/bundles/review_role_bundle.dart';
import 'package:smf_contracts/bundles/review_role_setting_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';
import 'role_support.dart';
import 'router_vm.dart';
import 'support.dart';

/// The file of the fake provider of the reviews in the test app.
const _fakeFile = ImportRef.app('fakes/fake_review.dart');

/// The file of the fake preferences in the test app.
const _fakePreferencesFile = ImportRef.app('fakes/fake_preferences.dart');

/// The file of `appReview`, as code imports it.
const _controllerImport = ImportRef.app('core/review/app_review.dart');

/// The template of the role as its owner, as the pipeline names it.
const _template = RoleTemplateOrigin(reviewRole);

/// The implementation of the service of the test app: one that is created
/// asynchronously, or one created with the app.
RoleImplementation _implementation({required bool async}) => async
    ? const RoleImplementation.async(
        type: TypeRef('FakeReview', import: _fakeFile),
        init: FactoryRef('openFakeReview', import: _fakeFile),
      )
    : const RoleImplementation(
        type: TypeRef('FakeReview', import: _fakeFile),
        create: FactoryRef('createFakeReview', import: _fakeFile),
      );

/// What the template of the role contributes, in every app and in some.
List<Contribution> _contributions() =>
    reviewRole.template.contribute(testContext);

/// The data that the template gives [role], as the pipeline hands it to
/// the hooks of that role: with the template as its origin.
List<RoleData<Object>> _dataFor(Role role) => [
      for (final contribution in _contributions())
        if (contribution case final RoleData<Object> data
            when data.role == role)
          data.withOrigin(_template),
    ];

/// A role that publishes a condition for the routes, as the purchases role
/// publishes premium access.
final class _ShopRole extends Role<NoDsl> {
  const _ShopRole();

  @override
  String get id => 'shop';

  @override
  String get description => 'Shop';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;
}

/// What the screen of the vault of the test app needs.
const _premium = RouteCondition(_ShopRole(), 'premium');

/// A screen of the feature [feature] of the test app.
ScreenRef _screen(String name, String feature) => ScreenRef(
      name,
      import: ImportRef.app(
        'features/$feature/${SmfNames.snakeCaseOf(name)}.dart',
      ),
    );

/// The file of the function of the gate of the feature `intro`.
const _introFile = ImportRef.app('features/intro/intro_status.dart');

/// The file of the function of the guard of the feature `shop`.
const _shopFile = ImportRef.app('features/shop/shop_plan.dart');

/// The routes of an app without guards: a feature whose route can start the
/// app.
final List<RoleData<Object>> _homeRoutes = [
  dataOf(
    routerRole,
    RoutesData([
      Route(
        '/',
        name: 'root',
        screen: _screen('HomeScreen', 'home'),
        startCandidate: true,
      ),
    ]),
  ),
];

/// The routes of an app with guards: those of [_homeRoutes]; a feature with
/// a gate, whose flow is its welcome screen and the terms below it; and a
/// feature with a guard of a condition, whose flow is its paywall and which
/// keeps the user from the vault.
final List<RoleData<Object>> _guardedRoutes = [
  ..._homeRoutes,
  dataOf(
    routerRole,
    RoutesData(
      [
        Route(
          '/',
          name: 'welcome',
          screen: _screen('WelcomeScreen', 'intro'),
          children: [
            Route(
              'terms',
              name: 'terms',
              screen: _screen('TermsScreen', 'intro'),
            ),
          ],
        ),
      ],
      guards: const [
        RouteGuard(
          name: 'firstRun',
          allows: FunctionRef('introDone', import: _introFile),
          redirectTo: 'welcome',
          stage: GuardStage.welcome,
        ),
      ],
    ),
    module: 'intro',
  ),
  dataOf(
    routerRole,
    RoutesData(
      [
        Route('/', name: 'paywall', screen: _screen('PaywallScreen', 'shop')),
        Route(
          '/vault',
          name: 'vault',
          screen: _screen('VaultScreen', 'shop'),
          conditions: const [_premium],
        ),
      ],
      guards: const [
        RouteGuard(
          name: 'premium',
          allows: FunctionRef('isPremium', import: _shopFile),
          redirectTo: 'paywall',
          stage: GuardStage.identity,
          condition: _premium,
        ),
      ],
    ),
    module: 'shop',
  ),
];

/// The files of the role in an app with the role, its preferences, its
/// values of `.env` and the roles in [present], with the [routes] of the
/// router role, rendered with an implementation that is created
/// asynchronously, or with the app, and what the template puts into other
/// sockets.
Future<RenderedTemplate> _rendered({
  Set<Role> present = const {},
  bool async = false,
  List<RoleData<Object>> routes = const [],
}) =>
    renderTemplate(
      reviewRole,
      data: [
        dataOf(
          reviewRole,
          _implementation(async: async),
          module: 'fake_review',
        ),
        ...routes,
      ],
      present: {preferencesRole, envRole, ...present},
    );

/// A stand-in for the part of Flutter's foundation library that the files
/// of the role, of the preferences and of the guards of the router use,
/// with the signatures of Flutter 3.44: the app runs in debug mode, what it
/// prints goes to `debugPrinted`, and a script sets the platform that it
/// runs on with `debugDefaultTargetPlatformOverride`, Android without.
const _foundation = '''
$vmFoundation

const bool kDebugMode = true;

/// What the app printed with [debugPrint], in order.
final List<String> debugPrinted = [];

void debugPrint(String? message, {int? wrapWidth}) =>
    debugPrinted.add('\$message');

enum TargetPlatform { android, fuchsia, iOS, linux, macOS, windows }

TargetPlatform? debugDefaultTargetPlatformOverride;

TargetPlatform get defaultTargetPlatform =>
    debugDefaultTargetPlatformOverride ?? TargetPlatform.android;
''';

/// A stand-in for `AppEnv` of the provider of the env role: the App Store ID
/// is what a script gives it, as `.env` would, and `null` without.
const _appEnv = '''
/// The App Store ID that `.env` has, which a script sets.
String? appStoreIdOfTest;

abstract final class AppEnv {
  static String? get reviewAppStoreId => appStoreIdOfTest;
}
''';

/// A provider of the reviews for the test app, which keeps to the contract
/// of `ReviewService`.
///
/// Whether the store can show the dialog, the version of the app and
/// whether an app of the device opens a page are on variables that stand
/// for the device. The services note their calls, and a test holds a call
/// until it lets it go, or has it throw.
const _fakeReview = r'''
import 'dart:async';

import '../core/review/review_service.dart';

/// Whether the store of the device can show its dialog.
bool available = true;

/// The version of the app.
String? version = '1.0.0';

/// Whether an app of the device opens a page.
bool opens = true;

/// The calls that reached the services, in order.
final List<String> calls = [];

/// The [calls] since it last asked.
List<String> takeCalls() {
  final taken = [...calls];
  calls.clear();
  return taken;
}

/// The calls that wait until their completer completes, by their names.
final Map<String, Completer<void>> holds = {};

/// What the calls throw, by their names.
final Map<String, Object> failures = {};

ReviewService createFakeReview() => FakeReview();

Future<ReviewService> openFakeReview() async {
  await Future<void>.delayed(Duration.zero);
  return FakeReview();
}

final class FakeReview implements ReviewService {
  Future<void> _enter(String call) async {
    calls.add(call);
    await holds[call.split(' ').first]?.future;
    if (failures[call.split(' ').first] case final failure?) throw failure;
  }

  @override
  Future<bool> isAvailable() async {
    await _enter('isAvailable');
    return available;
  }

  @override
  Future<void> requestReview() => _enter('requestReview');

  @override
  Future<bool> openStorePage(Uri page) async {
    await _enter('openStorePage $page');
    return opens;
  }

  @override
  Future<String?> appVersion() async {
    await _enter('appVersion');
    return version;
  }
}
''';

/// Preferences of the test app that read and write an `int` and a
/// `String`, which is all that the role needs, over a map that stands for
/// the disk: each open reads the map anew, and a write takes a moment, and
/// fails when the test says so. Any other read or write throws.
const _fakePreferences = '''
import '../core/preferences/app_preferences.dart';

/// What the preferences have saved.
final Map<String, Object> disk = {};

/// Whether a write fails once it took its moment.
bool writesFail = false;

AppPreferences openFakePreferences() => FakePreferences();

final class FakePreferences implements AppPreferences {
  FakePreferences() : _values = Map.of(disk);

  final Map<String, Object> _values;

  @override
  int? getInt(String key) => switch (_values[key]) {
        final int value => value,
        _ => null,
      };

  @override
  String? getString(String key) => switch (_values[key]) {
        final String value => value,
        _ => null,
      };

  @override
  Future<void> setInt(String key, int value) => _write(key, value);

  @override
  Future<void> setString(String key, String value) => _write(key, value);

  Future<void> _write(String key, Object value) async {
    await Future<void>.delayed(Duration.zero);
    if (writesFail) throw StateError('The write fails.');
    _values[key] = value;
    disk[key] = value;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
''';

/// The functions of the guards of the test app, over notifiers that a
/// script changes.
const _guardFiles = {
  'lib/features/intro/intro_status.dart': '''
import 'package:flutter/foundation.dart';

/// Whether the user has finished the welcome of the app.
final ValueNotifier<bool> introDoneNow = ValueNotifier(true);

ValueListenable<bool> introDone() => introDoneNow;
''',
  'lib/features/shop/shop_plan.dart': '''
import 'package:flutter/foundation.dart';

/// Whether the user has premium access.
final ValueNotifier<bool> premiumNow = ValueNotifier(true);

ValueListenable<bool> isPremium() => premiumNow;
''',
};

/// The file of the router role that the template of its provider renders,
/// which no script here calls.
const _routerFactory = '''
import 'app_router.dart';

AppRouter createAppRouter() => throw UnimplementedError();
''';

/// What the scripts for the test app share: `pump` lets what is on its way
/// happen, `clock` is the time of the controllers of the tests, `launch()`
/// starts the app once more as a launch of the app does, and `saved()` is
/// what the preferences saved under the keys of the role.
const _notes = '''
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:my_app/core/env/app_env.dart';
import 'package:my_app/core/preferences/app_preferences.dart';
import 'package:my_app/core/review/app_review.dart';
import 'package:my_app/fakes/fake_preferences.dart';
import 'package:my_app/fakes/fake_review.dart';

final result = <String, Object?>{};

Future<void> pump() => Future<void>.delayed(Duration.zero);

/// The time of the clock of the controllers of the tests, which a script
/// moves on.
var clock = DateTime.utc(2026, 1, 1, 12);

/// A launch of the app at the time of [clock]: a new controller of the
/// tests over the preferences that the disk has, started with a new service
/// of the provider, as the next launch of the app starts with what the
/// device kept.
Future<AppReviewController> launch() async {
  final controller = AppReviewController(
    now: () => clock,
    appStoreId: () => appStoreIdOfTest,
  );
  controller.restore(openFakePreferences());
  await controller.start(FakeReview());
  return controller;
}

/// What the preferences saved under the keys of the role, a time as the
/// time of the clock.
Map<String, Object?> saved() => {
      'launches': disk['review.launches'],
      'first launch': timeOf('review.first_launch'),
      'asked at': timeOf('review.asked_at'),
      'asked version': disk['review.asked_version'],
    };

String? timeOf(String key) => switch (disk[key]) {
      final int milliseconds => DateTime.fromMillisecondsSinceEpoch(
          milliseconds,
          isUtc: true,
        ).toIso8601String(),
      _ => null,
    };

/// Saves a state of the reviews on the disk: [launches] launches, the
/// first [daysAgo] days before the clock, and no request.
void seedDue({int launches = 9, int daysAgo = 30}) {
  disk
    ..['review.launches'] = launches
    ..['review.first_launch'] = clock
        .subtract(Duration(days: daysAgo))
        .millisecondsSinceEpoch;
}
''';

/// Launches of the app over weeks, with the requests of each, and a new
/// version: no review is due before the third launch, the app asks once a
/// version, and not again within 14 days, also in a new version.
const _launches = '''
Future<void> main(List<String> arguments, SendPort port) async {
  void note(String step) => result[step] = {'calls': takeCalls(), ...saved()};

  var app = await launch();
  await app.requestIfDue();
  note('the first launch');

  clock = clock.add(const Duration(days: 10));
  app = await launch();
  await app.requestIfDue();
  note('the second launch, ten days later');

  clock = clock.add(const Duration(hours: 1));
  app = await launch();
  await app.requestIfDue();
  note('the third launch');

  await app.requestIfDue();
  note('another call in the third launch');

  clock = clock.add(const Duration(days: 5));
  version = '1.1.0';
  app = await launch();
  await app.requestIfDue();
  note('a new version five days after the request');

  clock = clock.add(const Duration(days: 10));
  app = await launch();
  await app.requestIfDue();
  note('the new version fifteen days after the request');

  clock = clock.add(const Duration(days: 30));
  app = await launch();
  await app.requestIfDue();
  note('the same version thirty days later');
  port.send(result);
}
''';

/// Launches of the app in its first days: no review is due before three
/// days have passed since the first launch, however many launches.
const _firstDays = '''
Future<void> main(List<String> arguments, SendPort port) async {
  final start = clock;
  final calls = <List<String>>[];
  for (var launches = 0; launches < 6; launches++) {
    final app = await launch();
    await app.requestIfDue();
    calls.add(takeCalls());
    clock = clock.add(const Duration(hours: 12));
  }
  result['six launches within three days'] = calls;
  clock = start.add(const Duration(days: 3));
  final app = await launch();
  await app.requestIfDue();
  result['the next launch three days after the first'] = {
    'calls': takeCalls(),
    ...saved(),
  };
  port.send(result);
}
''';

/// Requests on which a review is due that ask nothing, or that the store
/// does not take: a store that cannot show the dialog, a platform that
/// refuses the request, and a version that is unknown.
const _refusals = '''
Future<void> main(List<String> arguments, SendPort port) async {
  void note(String step) => result[step] = {
        'calls': takeCalls(),
        'asked at': timeOf('review.asked_at'),
        'asked version': disk['review.asked_version'],
      };

  seedDue();
  var app = await launch();
  takeCalls();

  available = false;
  await app.requestIfDue();
  note('a store that cannot show the dialog');
  available = true;

  failures['isAvailable'] = StateError('The store broke.');
  await app.requestIfDue();
  note('a store that fails to tell');
  failures.clear();

  failures['requestReview'] = StateError('The platform refused.');
  await app.requestIfDue();
  note('a platform that refuses the request');
  failures.clear();
  result['printed of the refusal'] = [...debugPrinted];
  debugPrinted.clear();

  await app.requestIfDue();
  note('the next call');

  disk.clear();
  seedDue();
  app = await launch();
  takeCalls();
  for (final (step, unknown) in [
    ('no version', null),
    ('an empty version', ' '),
    ('a version that fails', 'fails'),
  ]) {
    version = unknown;
    if (unknown == 'fails') failures['appVersion'] = StateError('No version.');
    await app.requestIfDue();
    note(step);
    failures.clear();
  }
  result['printed of an unknown version'] = [...debugPrinted];
  port.send(result);
}
''';

/// Two calls while the store takes its request.
const _together = '''
Future<void> main(List<String> arguments, SendPort port) async {
  seedDue();
  final app = await launch();
  takeCalls();
  holds['requestReview'] = Completer<void>();
  final first = app.requestIfDue();
  final second = app.requestIfDue();
  await pump();
  await pump();
  result['the calls while the store takes the request'] = takeCalls();
  result['the requests are one'] = identical(first, second);
  result['asked before the store took it'] = timeOf('review.asked_at');
  holds.remove('requestReview')!.complete();
  await first;
  await second;
  result['asked once the store took it'] = timeOf('review.asked_at');
  final third = app.requestIfDue();
  result['a later call is another'] = !identical(first, third);
  await third;
  result['the calls of the later call'] = takeCalls();
  port.send(result);
}
''';

/// A clock of the device that went back: the last request, or the first
/// launch, is still to come.
const _clockBack = '''
Future<void> main(List<String> arguments, SendPort port) async {
  seedDue();
  disk
    ..['review.asked_at'] =
        clock.add(const Duration(days: 1)).millisecondsSinceEpoch
    ..['review.asked_version'] = '0.9.0';
  var app = await launch();
  takeCalls();
  await app.requestIfDue();
  result['a request that is to come'] = takeCalls();

  disk
    ..clear()
    ..['review.launches'] = 9
    ..['review.first_launch'] =
        clock.add(const Duration(days: 1)).millisecondsSinceEpoch;
  app = await launch();
  takeCalls();
  await app.requestIfDue();
  result['a first launch that is to come'] = takeCalls();
  port.send(result);
}
''';

/// The pages of the app in its store on each platform, with an App Store
/// ID and without a usable one, and what opening them reaches.
const _pages = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  Map<String, Object?> pagesOf(AppReviewController app) => {
        'page': '${app.storePage()}',
        'review page': '${app.storePage(review: true)}',
        'has a page': app.hasStorePage,
      };

  final idle = AppReviewController(appStoreId: () => '1234567890');
  result['opened before the start'] = await idle.openStorePage();
  result['the calls before the start'] = takeCalls();

  final app = await launch();
  takeCalls();
  result['android'] = pagesOf(app);
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  for (final id in ['1234567890', null, '', 'id123', '123 ', '12a4']) {
    appStoreIdOfTest = id;
    result['iOS with ${id == null ? 'none' : "'$id'"}'] = pagesOf(app);
  }
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  appStoreIdOfTest = '1234567890';
  result['another platform'] = pagesOf(app);

  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  result['opened'] = await app.openStorePage(review: true);
  opens = false;
  result['opened where no app opens it'] = await app.openStorePage();
  opens = true;
  failures['openStorePage'] = StateError('The platform broke.');
  result['opened by a service that fails'] = await app.openStorePage();
  failures.clear();
  appStoreIdOfTest = null;
  result['opened without a page'] = await app.openStorePage();
  result['the calls'] = takeCalls();
  port.send(result);
}
''';

/// What the app prints in debug mode at a start: on iOS without an App
/// Store ID, once.
const _hints = '''
Future<void> main(List<String> arguments, SendPort port) async {
  await launch();
  result['on Android'] = [...debugPrinted];
  debugPrinted.clear();
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  appStoreIdOfTest = '1234567890';
  await launch();
  result['on iOS with an App Store ID'] = [...debugPrinted];
  debugPrinted.clear();
  appStoreIdOfTest = null;
  final app = await launch();
  await app.start(FakeReview());
  result['on iOS without one, at two starts'] = [...debugPrinted];
  port.send(result);
}
''';

/// Preferences that fail to save: the start and the request go on, with
/// what they keep in memory.
const _failedWrites = '''
Future<void> main(List<String> arguments, SendPort port) async {
  seedDue();
  writesFail = true;
  final app = await launch();
  result['the calls of the start'] = takeCalls();
  await app.requestIfDue();
  result['the calls of the request'] = takeCalls();
  await app.requestIfDue();
  result['the calls of the next call'] = takeCalls();
  result['saved'] = saved();
  result['printed'] = [...debugPrinted];
  port.send(result);
}
''';

/// The start of `appReview` in `bootstrap()`, and the next one: each counts
/// a launch, and keeps the first launch and what else was saved.
const _nextStart = '''
Future<void> main(List<String> arguments, SendPort port) async {
  disk['review.asked_version'] = '0.9.0';
  await initPreferences();
  await initReview();
  final first = disk['review.first_launch'];
  result['the first start'] = {
    'launches': disk['review.launches'],
    'has its first launch': first is int,
    'the service': createReviewService() is FakeReview,
  };
  await initPreferences();
  await initReview();
  result['the next start'] = {
    'launches': disk['review.launches'],
    'keeps the first launch': disk['review.first_launch'] == first,
    'keeps the request': disk['review.asked_version'],
  };
  await appReview.requestIfDue();
  result['a call at the second launch'] = takeCalls();
  port.send(result);
}
''';

/// A review that is due while the user is in the flow of a guard of the
/// routes, and once out of it, in an app with guards: a gate that does not
/// allow, a screen of the flow of a gate, the target of a guard of a
/// condition on top, a gate that stops allowing while the request is on
/// its way, and a screen outside every flow.
///
/// It goes after [_flowsImports] and [_notes].
const _flows = '''
Future<void> main(List<String> arguments, SendPort port) async {
  seedDue();
  final app = await launch();
  takeCalls();

  introDoneNow.value = false;
  await app.requestIfDue();
  result['a gate that does not allow'] = takeCalls();
  introDoneNow.value = true;

  noteScreenForReview('intro.terms', '/intro/terms');
  await app.requestIfDue();
  result['a screen of the flow of a gate that allows'] = takeCalls();

  premiumNow.value = false;
  noteScreenForReview('shop.paywall', '/shop');
  await app.requestIfDue();
  result['the target of a guard of a condition'] = takeCalls();

  noteScreenForReview('home.root', '/');
  holds['isAvailable'] = Completer<void>();
  final request = app.requestIfDue();
  await pump();
  introDoneNow.value = false;
  holds.remove('isAvailable')!.complete();
  await request;
  result['a gate that stops allowing during the request'] = takeCalls();
  introDoneNow.value = true;

  await app.requestIfDue();
  result['a screen outside every flow'] = takeCalls();
  result['asked version'] = disk['review.asked_version'];
  port.send(result);
}
''';

/// The libraries of the functions of the guards of the test app, which
/// [_flows] changes what they allow through.
const _flowsImports = '''
import 'package:my_app/features/intro/intro_status.dart';
import 'package:my_app/features/shop/shop_plan.dart';
''';

/// The files of the test app: the files of the role, as its template
/// generates them in an app with the [routes] of the router role and the
/// roles in [present], the file of the preferences with the restorer of the
/// role, a stand-in for `AppEnv`, the fakes, and in an app with guards the
/// files of the router role and of the functions of the guards. The entry
/// of the settings screen is checked on its own, since it needs Flutter's
/// material library.
Future<DartFiles> _app({
  bool async = false,
  List<RoleData<Object>> routes = const [],
  Set<Role> present = const {},
}) async {
  final review = await _rendered(
    present: {if (routes.isNotEmpty) routerRole, ...present},
    async: async,
    routes: routes,
  );
  final preferences = await renderTemplate(
    preferencesRole,
    data: [
      dataOf(
        preferencesRole,
        const RoleImplementation(
          type: TypeRef('FakePreferences', import: _fakePreferencesFile),
          create: FactoryRef(
            'openFakePreferences',
            import: _fakePreferencesFile,
          ),
        ),
        module: 'fake_preferences',
      ),
    ],
    fromModules: [
      for (final contribution in review.contributions)
        if (contribution case final SocketContribution restorer
            when restorer.socket == PreferencesRole.restorers)
          restorer,
    ],
  );
  final router =
      routes.isEmpty ? null : await renderTemplate(routerRole, data: routes);
  return DartFiles.write(
    {
      for (final MapEntry(key: path, value: text) in review.files.entries)
        if (path.endsWith('.dart')) path: text,
      ...preferences.files,
      'lib/core/env/app_env.dart': _appEnv,
      'lib/fakes/fake_review.dart': _fakeReview,
      'lib/fakes/fake_preferences.dart': _fakePreferences,
      if (router != null) ...{
        RouterRole.appRouterFile: router.files[RouterRole.appRouterFile]!,
        RouterRole.navigationFile: router.files[RouterRole.navigationFile]!,
        RouterRole.appRouterFactoryFile: _routerFactory,
        ..._guardFiles,
      },
    },
    flutter: const {
      'foundation.dart': _foundation,
      'widgets.dart': vmWidgets,
    },
  );
}

/// The top-level functions of [unit], by name.
Map<String, FunctionDeclaration> _functionsOf(CompilationUnit unit) => {
      for (final function in unit.declarations.whereType<FunctionDeclaration>())
        function.name.lexeme: function,
    };

/// The statements of the body of [function].
List<String> _statementsOf(FunctionDeclaration function) => [
      for (final statement
          in (function.functionExpression.body as BlockFunctionBody)
              .block
              .statements)
        '$statement',
    ];

/// The signature of [member], a method or a getter, as its code.
String _signatureOf(MethodDeclaration member) => [
      '${member.returnType} ',
      if (member.isGetter) 'get ',
      member.name.lexeme,
      '${member.parameters ?? ''}',
    ].join();

/// The members of the class [name] of [unit] that are methods or getters,
/// each as its signature, but those that are private.
List<String> _methodsOf(CompilationUnit unit, String name) => [
      for (final member in unit.declarations
          .whereType<ClassDeclaration>()
          .singleWhere((type) => type.namePart.typeName.lexeme == name)
          .body
          .members)
        if (member is MethodDeclaration && !member.name.lexeme.startsWith('_'))
          _signatureOf(member),
    ];

/// The top-level variables of [unit], each as its declaration.
Map<String, String> _variablesOf(CompilationUnit unit) => {
      for (final declaration
          in unit.declarations.whereType<TopLevelVariableDeclaration>())
        for (final variable in declaration.variables.variables)
          variable.name.lexeme: declaration.toSource(),
    };

/// The named arguments of each creation of the class [className], in the
/// order of the code.
final class _NamedArgumentsOf extends RecursiveAstVisitor<void> {
  _NamedArgumentsOf(this.className);

  final String className;

  final found = <Map<String, String>>[];

  void _note(String name, ArgumentList arguments) {
    if (name != className) return;
    found.add({
      for (final argument in arguments.arguments.whereType<NamedArgument>())
        argument.name.lexeme: argument.argumentExpression.toSource(),
    });
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _note(node.constructorName.type.name.lexeme, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  // Unresolved code has the creation of a class without `new` or `const`
  // as the call of a method.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) _note(node.methodName.name, node.argumentList);
    super.visitMethodInvocation(node);
  }
}

/// The provider of the role and a feature that uses the role.
const _provider = ModuleDescriptor(
  id: ModuleId('fake_review'),
  description: 'Reviews',
  kind: ModuleKinds.infrastructure,
  providers: [RoleProvider.plain(reviewRole)],
);
const _feature = ModuleDescriptor(
  id: ModuleId('notes'),
  description: 'Notes',
  kind: ModuleKinds.feature,
  uses: {reviewRole},
);

/// The template of a role whose code may open the page of the app in its
/// store, as the template of a role of updates would.
final _otherRole = TestRole<NoDsl>('updates', requires: {reviewRole});

/// The implementation of the provider of the apps of the rules: its class
/// in one file and its function in another.
const _providerImplementation = RoleImplementation(
  type: TypeRef(
    'FakeReviewService',
    import: ImportRef.app('core/review/fake_review_service.dart'),
  ),
  create: FactoryRef(
    'createFakeReviewService',
    import: ImportRef.app('core/review/fake_review.dart'),
  ),
);

/// The file of the function of [_providerImplementation], which imports
/// the file of `ReviewService`, as the file of an implementation may.
const _factoryFile = DartFileIndex(
  path: 'lib/core/review/fake_review.dart',
  imports: [IndexedImport('review_service.dart')],
  declarations: [
    IndexedDeclaration(
      name: 'createFakeReviewService',
      kind: DeclarationKind.function,
    ),
  ],
);

/// The issues of the structural rules of the role in an app of the
/// provider with [_providerImplementation] and with [files], each with its
/// owner, and with the [texts] of files; a file without an owner has
/// `null`.
List<SmfIssue> _structureIssues(
  Map<DartFileIndex, ContributionOrigin?> files, {
  Map<String, (String, ContributionOrigin?)> texts = const {},
}) =>
    reviewRole.checkStructure(
      StructuralRuleRequest(
        hook: RoleHookRequest(
          data: [
            dataOf(
              reviewRole,
              _providerImplementation,
              module: 'fake_review',
            ),
          ],
          presentRoles: {reviewRole, preferencesRole, envRole},
          context: testContext,
        ),
        files: {
          _factoryFile.path: _factoryFile,
          for (final file in files.keys) file.path: file,
        },
        texts: {
          for (final MapEntry(key: path, value: (text, _)) in texts.entries)
            path: text,
        },
        owners: {
          _factoryFile.path: ModuleOrigin(_provider.id),
          for (final MapEntry(key: file, value: owner) in files.entries)
            if (owner != null) file.path: owner,
          for (final MapEntry(key: path, value: (_, owner)) in texts.entries)
            if (owner != null) path: owner,
        },
        modules: const [_provider, _feature],
      ),
    );

/// The index of the file at [path] that imports the file of `appReview`
/// and calls [function] of it.
DartFileIndex _calling(String path, String function) => DartFileIndex(
      path: path,
      imports: const [
        IndexedImport('package:my_app/core/review/app_review.dart'),
      ],
      invocations: [IndexedInvocation(function)],
    );

/// The index of the file at [path] that imports the file of `appReview`
/// and calls [method] on `appReview`.
DartFileIndex _invoking(String path, String method) => DartFileIndex(
      path: path,
      imports: const [
        IndexedImport('package:my_app/core/review/app_review.dart'),
      ],
      invocations: [IndexedInvocation(method, target: 'appReview')],
    );

void main() {
  group('the review role', () {
    test(
        'takes one provider, requires the preferences and the values of the '
        'app, and works with the router, a settings screen and the languages '
        'of the app', () {
      expect(reviewRole.id, 'review');
      expect(reviewRole.description, 'Store reviews');
      expect(reviewRole.presenceFlag, 'has_review');
      expect('$reviewRole', 'store reviews role');
      expect(reviewRole.cardinality, RoleCardinality.atMostOne);
      expect(reviewRole.requires, {preferencesRole, envRole});
      expect(
        reviewRole.uses,
        {routerRole, settingsScreenRole, localizationRole},
      );
      // Its provider uses what the role uses, so the contract harness
      // builds the apps of a provider with each of those roles and without.
      expect(
        _provider.effectiveUses,
        {routerRole, settingsScreenRole, localizationRole},
      );
      expect(_provider.effectiveRequires, {preferencesRole, envRole});
      expect(reviewRole.sockets, const [ReviewRole.implementations]);
      expect(ReviewRole.implementations.tag, 'smf_review__implementations');
      expect(reviewRole.options, isEmpty);
      expect(
        [for (final rule in reviewRole.moduleRules) rule.id],
        ['services.implementations'],
      );
      expect(
        [for (final rule in reviewRole.structuralRules) rule.id],
        [
          'review.factory_calls',
          'review.start_calls',
          'review.implementation_factories',
          'review.requests',
        ],
      );
    });

    test(
        'guarantees the files of the service and of the controller, but not '
        'the file of the entry of the settings screen', () {
      expect(reviewRole.interface.files, [
        'lib/core/review/review_service.dart',
        'lib/core/review/app_review.dart',
      ]);
      expect(reviewRole.interface.files, [
        ReviewRole.serviceFile,
        ReviewRole.controllerFile,
      ]);
      expect(reviewRole.interface.symbols, isEmpty);
      expect(ReviewRole.settingFile, 'lib/core/review/review_setting.dart');
      expect(ReviewRole.readmeHeading, 'Store reviews');
      // <owner id>.<setting>, as the preferences role names its keys.
      expect(ReviewRole.keys, [
        ReviewRole.launchesKey,
        ReviewRole.firstLaunchKey,
        ReviewRole.askedAtKey,
        ReviewRole.askedVersionKey,
      ]);
      expect(ReviewRole.keys, [
        'review.launches',
        'review.first_launch',
        'review.asked_at',
        'review.asked_version',
      ]);
      for (final key in ReviewRole.keys) {
        expect(key, startsWith('${reviewRole.id}.'));
      }
    });

    test(
        'has the key of the App Store ID, after the id of the role, and its '
        'step by hand', () {
      expect(ReviewRole.appStoreIdKey.name, 'REVIEW_APP_STORE_ID');
      expect(ReviewRole.appStoreIdKey.getter, 'reviewAppStoreId');
      expect(ReviewRole.appStoreIdKey.problems(), isEmpty);
      expect(
        ReviewRole.appStoreIdKey.name,
        startsWith('${reviewRole.id.toUpperCase()}_'),
      );
      const step = ReviewRole.appStoreIdStep;
      expect(step.id.wire, 'review.app_store_id');
      expect(step.id.role, same(reviewRole));
      expect(step.id.module, isNull);
      expect(
        step.title,
        'Copy the App Store ID of the app from App Store Connect into .env',
      );
      expect(
        step.title.length,
        lessThanOrEqualTo(ManualStep.maxTitleLength),
      );
      expect(step.title, matches(RegExp(r'^[A-Z][^\n\\]*[^.\s]$')));
      // In every app with the role, which a step of the role applies in.
      expect(step.when, isEmpty);
    });

    test('has the texts of the entry in English and in Ukrainian', () {
      const texts = [ReviewRole.settingTitle, ReviewRole.settingFailed];
      for (final text in texts) {
        expect(text.problems(), isEmpty, reason: text.name);
        expect(text.languages, ['en', 'uk'], reason: text.name);
      }
      expect(
        [for (final text in texts) (text.en, text.textIn('uk'))],
        [
          ('Rate the app', 'Оцінити застосунок'),
          ("Couldn't open the store.", 'Не вдалося відкрити магазин.'),
        ],
      );
    });
  });

  group('the review template', () {
    test(
        'generates the files of the role in every app, and the entry only in '
        'an app with a settings screen', () async {
      final bricks = _contributions().whereType<BrickContribution>().toList();
      expect(
        [for (final brick in bricks) brick.bundle.name],
        [reviewRoleBundle.name, reviewRoleSettingBundle.name],
      );
      expect(
        [for (final brick in bricks) brick.when],
        [
          isEmpty,
          {settingsScreenRole},
        ],
      );
      expect(
        templatesOf(reviewRoleSettingBundle).keys,
        [ReviewRole.settingFile],
      );

      for (final settings in [false, true]) {
        final rendered = await _rendered(
          present: {if (settings) settingsScreenRole},
        );
        expect(
          rendered.files.keys.toSet(),
          {
            ...reviewRole.interface.files,
            if (settings) ReviewRole.settingFile,
          },
          reason: 'settings: $settings',
        );
        for (final MapEntry(key: path, value: text) in rendered.files.entries) {
          expectParses(text, reason: path);
        }
      }
    });

    test(
        'registers nothing in a DI container, gives the preferences the '
        'restorer of what the role keeps, the values of the app the key of '
        'the App Store ID, and lists its step by hand', () {
      final contributions = _contributions();

      expect(_dataFor(diRole), isEmpty);
      final restorer = contributions
          .whereType<SocketContribution>()
          .singleWhere((item) => item.socket == PreferencesRole.restorers);
      expect(restorer.fragment!.code, 'restoreReview');
      expect(restorer.fragment!.imports, [_controllerImport]);
      expect(restorer.when, isEmpty);
      final key = _dataFor(envRole).single;
      expect(key.value, ReviewRole.appStoreIdKey);
      expect(key.when, isEmpty);
      expect(
        contributions.whereType<ManualStep>(),
        [ReviewRole.appStoreIdStep],
      );
      final input = inputOf(envRole, data: _dataFor(envRole));
      expect(envRole.template.validate(input), isEmpty);
      expect(
        [for (final key in envRole.keysIn(input)) key.name],
        ['REVIEW_APP_STORE_ID'],
      );
    });

    test(
        'generates the interface that a provider implements, with the '
        'version of the app', () async {
      final rendered = await _rendered();
      final unit = parseString(
        content: rendered.files[ReviewRole.serviceFile]!,
      ).unit;

      expect(_methodsOf(unit, 'ReviewService'), [
        'Future<bool> isAvailable()',
        'Future<void> requestReview()',
        'Future<bool> openStorePage(Uri page)',
        'Future<String?> appVersion()',
      ]);
      // The file of the provider needs nothing of Flutter and no other file
      // of the app.
      expect(unit.directives, isEmpty);
    });

    test(
        'generates the controller with the policy, and the application id '
        'of the app in Google Play: that of the flavor for a release',
        () async {
      final rendered = await _rendered();
      final code = rendered.files[ReviewRole.controllerFile]!;
      final unit = parseString(content: code).unit;

      expect(
        _variablesOf(unit)['googlePlayId'],
        "const String googlePlayId = 'com.example.my_app';",
      );
      expect(
        AppEntryRole.releaseFlavor.applicationIdIn(testContext.appIdentity),
        'com.example.my_app',
      );
      for (final flavor in AppEntryRole.flavors) {
        if (flavor.idSuffix.isEmpty) continue;
        expect(code, isNot(contains("'com.example.my_app${flavor.idSuffix}'")));
      }
      expect(
        _methodsOf(unit, 'AppReviewController'),
        [
          'bool get hasStorePage',
          'Uri? storePage({bool review = false})',
          'Future<bool> openStorePage({bool review = false})',
          'Future<void> requestIfDue()',
          'void restore(AppPreferences preferences)',
          'Future<void> start(ReviewService service)',
        ],
      );
      final policy =
          unit.declarations.whereType<ClassDeclaration>().singleWhere(
                (type) => type.namePart.typeName.lexeme == 'ReviewPolicy',
              );
      expect(
        [
          for (final member
              in policy.body.members.whereType<FieldDeclaration>())
            '${member.fields}',
        ],
        [
          'const int launches = 3',
          'const Duration sinceFirstLaunch = Duration(days: 3)',
          'const Duration between = Duration(days: 14)',
        ],
      );
      // The keys of the preferences are those of the role.
      for (final key in ReviewRole.keys) {
        expect(code, contains("'$key'"));
      }
    });

    for (final async in [true, false]) {
      final how = async ? 'created asynchronously' : 'created with the app';

      test(
          'creates an implementation $how in initReview(), starts appReview '
          'with it, and awaits that in the last phase of bootstrap()',
          () async {
        final rendered = await _rendered(async: async);
        final code = rendered.files[ReviewRole.controllerFile]!;
        final unit = parseString(content: code).unit;

        final init = _functionsOf(unit)['initReview']!;
        expect('${init.returnType}', 'Future<void>');
        expect(init.functionExpression.parameters!.parameters, isEmpty);
        expect(_statementsOf(init), [
          if (async)
            '_reviewService = await impl0.openFakeReview();'
          else
            '_reviewService = impl0.createFakeReview();',
          'await appReview.start(_reviewService);',
        ]);
        expect(
          _variablesOf(unit)['_reviewService'],
          'late ReviewService _reviewService;',
        );
        expect(
          code,
          contains("import 'package:my_app/fakes/fake_review.dart' as impl0;"),
        );
        final start = rendered.elsewhere.singleWhere(
          (entry) =>
              entry.socket == AppEntryRole.bootstrapLate ||
              entry.socket == AppEntryRole.bootstrapPlatform,
        );
        expect(start.socket, AppEntryRole.bootstrapLate);
        expect(start.fragment!.code, 'await initReview();');
        expect(start.fragment!.imports, [_controllerImport]);
        expect(start.when, isEmpty);
      });
    }

    test(
        'tells whether the user is in the flow of a guard of the routes only '
        'in an app with guards, where it hears of the screens', () async {
      /// The code of `_inAGuardFlow` and of the listener of the screen in
      /// the file of the controller, and the listeners of the screen that
      /// the template gives the router.
      Future<(String, String?, List<SocketContribution>)> shapeWith({
        required bool router,
        List<RoleData<Object>> routes = const [],
      }) async {
        final rendered = await _rendered(
          present: {if (router) routerRole},
          routes: routes,
        );
        final code = rendered.files[ReviewRole.controllerFile]!;
        final functions = _functionsOf(parseString(content: code).unit);
        return (
          functions['_inAGuardFlow']!.toSource(),
          functions['noteScreenForReview']?.toSource(),
          [
            for (final entry in rendered.elsewhere)
              if (entry.socket == RouterRole.screenListeners) entry,
          ],
        );
      }

      for (final (name, router, routes) in [
        ('without a router', false, const <RoleData<Object>>[]),
        ('with a router and no guards', true, _homeRoutes),
      ]) {
        final (inAFlow, listener, listeners) = await shapeWith(
          router: router,
          routes: routes,
        );
        expect(inAFlow, 'bool _inAGuardFlow() => false;', reason: name);
        expect(listener, isNull, reason: name);
        expect(listeners, isEmpty, reason: name);
      }

      final (inAFlow, listener, listeners) = await shapeWith(
        router: true,
        routes: _guardedRoutes,
      );
      expect(
        inAFlow,
        'bool _inAGuardFlow() => routeGuards.any((guard) => (guard.routes == '
        'null && !guard.allows.value) || guard.flow.contains(_screen));',
      );
      expect(
        listener,
        'void noteScreenForReview(String? route, String location) => '
        '_screen = route;',
      );
      expect(listeners.single.fragment!.code, 'noteScreenForReview');
      expect(listeners.single.fragment!.imports, [_controllerImport]);
      final rendered = await _rendered(
        present: {routerRole},
        routes: _guardedRoutes,
      );
      expect(
        rendered.files[ReviewRole.controllerFile],
        contains("import 'package:my_app/core/router/app_router.dart';"),
      );
    });

    test('reports the problems of the implementation', () {
      final issues = reviewRole.template.validate(
        inputOf(
          reviewRole,
          data: [
            dataOf(
              reviewRole,
              const RoleImplementation(
                type: TypeRef('_Private'),
                create: FactoryRef('create', import: _fakeFile),
              ),
              module: 'fake_review',
            ),
          ],
          present: {preferencesRole, envRole},
        ),
      );
      expect(
        issues.single.origin,
        const ModuleOrigin(ModuleId('fake_review')),
      );
    });
  });

  group('the generated controller', () {
    for (final async in [false, true]) {
      group(
          'with an implementation '
          '${async ? 'created asynchronously' : 'created with the app'}', () {
        late DartFiles app;

        setUpAll(() async => app = await _app(async: async));

        tearDownAll(() => app.delete());

        test('is code that type-checks', () async {
          expect(await app.analysisProblems(), isEmpty);
        });

        test(
            'counts each start of the app as a launch, keeps the first '
            'launch and what else was saved, and asks nothing at a second '
            'launch', () async {
          expect(await app.run('$_notes$_nextStart'), {
            'the first start': {
              'launches': 1,
              'has its first launch': true,
              'the service': true,
            },
            'the next start': {
              'launches': 2,
              'keeps the first launch': true,
              'keeps the request': '0.9.0',
            },
            'a call at the second launch': <Object?>[],
          });
        });
      });
    }

    group('in an app without guards', () {
      late DartFiles app;

      setUpAll(() async => app = await _app());

      tearDownAll(() => app.delete());

      test(
          'asks from the third launch, once a version, and not again within '
          '14 days, also in a new version', () async {
        const start = '2026-01-01T12:00:00.000Z';
        const asked = '2026-01-11T13:00:00.000Z';
        const askedAgain = '2026-01-26T13:00:00.000Z';
        expect(await app.run('$_notes$_launches'), {
          'the first launch': {
            'calls': <Object?>[],
            'launches': 1,
            'first launch': start,
            'asked at': null,
            'asked version': null,
          },
          'the second launch, ten days later': {
            'calls': <Object?>[],
            'launches': 2,
            'first launch': start,
            'asked at': null,
            'asked version': null,
          },
          'the third launch': {
            'calls': ['appVersion', 'isAvailable', 'requestReview'],
            'launches': 3,
            'first launch': start,
            'asked at': asked,
            'asked version': '1.0.0',
          },
          'another call in the third launch': {
            'calls': <Object?>[],
            'launches': 3,
            'first launch': start,
            'asked at': asked,
            'asked version': '1.0.0',
          },
          'a new version five days after the request': {
            'calls': <Object?>[],
            'launches': 4,
            'first launch': start,
            'asked at': asked,
            'asked version': '1.0.0',
          },
          'the new version fifteen days after the request': {
            'calls': ['appVersion', 'isAvailable', 'requestReview'],
            'launches': 5,
            'first launch': start,
            'asked at': askedAgain,
            'asked version': '1.1.0',
          },
          'the same version thirty days later': {
            'calls': ['appVersion'],
            'launches': 6,
            'first launch': start,
            'asked at': askedAgain,
            'asked version': '1.1.0',
          },
        });
      });

      test(
          'asks for no review before three days have passed since the first '
          'launch, however many launches', () async {
        expect(await app.run('$_notes$_firstDays'), {
          'six launches within three days': List.filled(6, <Object?>[]),
          'the next launch three days after the first': {
            'calls': ['appVersion', 'isAvailable', 'requestReview'],
            'launches': 7,
            'first launch': '2026-01-01T12:00:00.000Z',
            'asked at': '2026-01-04T12:00:00.000Z',
            'asked version': '1.0.0',
          },
        });
      });

      test(
          'saves no request that the store did not take: a store that cannot '
          'show the dialog, a platform that refuses, or a version that is '
          'unknown, which it tells once in debug mode', () async {
        const refused = 'The store did not take the request for a review: '
            'Bad state: The platform refused.';
        const unknown =
            'The version of the app is unknown, so the app asks for no review.';
        expect(await app.run('$_notes$_refusals'), {
          'a store that cannot show the dialog': {
            'calls': ['appVersion', 'isAvailable'],
            'asked at': null,
            'asked version': null,
          },
          'a store that fails to tell': {
            'calls': ['appVersion', 'isAvailable'],
            'asked at': null,
            'asked version': null,
          },
          'a platform that refuses the request': {
            'calls': ['appVersion', 'isAvailable', 'requestReview'],
            'asked at': null,
            'asked version': null,
          },
          'printed of the refusal': [refused],
          // A platform that refused counts as no dialog, so the next call
          // asks again.
          'the next call': {
            'calls': ['appVersion', 'isAvailable', 'requestReview'],
            'asked at': '2026-01-01T12:00:00.000Z',
            'asked version': '1.0.0',
          },
          'no version': {
            'calls': ['appVersion'],
            'asked at': null,
            'asked version': null,
          },
          'an empty version': {
            'calls': ['appVersion'],
            'asked at': null,
            'asked version': null,
          },
          'a version that fails': {
            'calls': ['appVersion'],
            'asked at': null,
            'asked version': null,
          },
          'printed of an unknown version': [
            unknown,
            'The version of the app is unknown: Bad state: No version.',
          ],
        });
      });

      test(
          'makes one request of two calls at once, and saves it once the '
          'store took it', () async {
        expect(await app.run('$_notes$_together'), {
          'the calls while the store takes the request': [
            'appVersion',
            'isAvailable',
            'requestReview',
          ],
          'the requests are one': true,
          'asked before the store took it': null,
          'asked once the store took it': '2026-01-01T12:00:00.000Z',
          'a later call is another': true,
          'the calls of the later call': <Object?>[],
        });
      });

      test(
          'takes a time that is to come, after the clock of the device went '
          'back, as recent', () async {
        expect(await app.run('$_notes$_clockBack'), {
          'a request that is to come': <Object?>[],
          'a first launch that is to come': <Object?>[],
        });
      });

      test(
          'has the Google Play page of the app on Android, the App Store page '
          'on iOS only with an App Store ID of digits, and opens exactly the '
          'page through the service', () async {
        const play =
            'https://play.google.com/store/apps/details?id=com.example.my_app';
        const appStore = 'https://apps.apple.com/app/id1234567890';
        const none = {
          'page': 'null',
          'review page': 'null',
          'has a page': false,
        };
        expect(await app.run('$_notes$_pages'), {
          'opened before the start': false,
          'the calls before the start': <Object?>[],
          'android': {'page': play, 'review page': play, 'has a page': true},
          "iOS with '1234567890'": {
            'page': appStore,
            'review page': '$appStore?action=write-review',
            'has a page': true,
          },
          'iOS with none': none,
          "iOS with ''": none,
          "iOS with 'id123'": none,
          "iOS with '123 '": none,
          "iOS with '12a4'": none,
          'another platform': none,
          'opened': true,
          'opened where no app opens it': false,
          'opened by a service that fails': false,
          'opened without a page': false,
          'the calls': [
            'openStorePage $appStore?action=write-review',
            'openStorePage $appStore',
            'openStorePage $appStore',
          ],
        });
      });

      test(
          'tells once in debug mode, on iOS, that the app has no App Store '
          'page without the App Store ID', () async {
        const hint = 'REVIEW_APP_STORE_ID in .env has no App Store ID, so '
            'the app has no App Store page: appReview.hasStorePage is false '
            'on iOS, and appReview.openStorePage() opens nothing there. Put '
            'the Apple ID of the app in App Store Connect there.';
        expect(await app.run('$_notes$_hints'), {
          'on Android': <Object?>[],
          'on iOS with an App Store ID': <Object?>[],
          'on iOS without one, at two starts': [hint],
        });
      });

      test(
          'goes on with what it keeps in memory when the preferences fail to '
          'save', () async {
        const launchNotSaved = 'The launch of the app was not saved for the '
            'reviews: Bad state: The write fails.';
        const requestNotSaved = 'The request for a review was not saved: Bad '
            'state: The write fails.';
        expect(await app.run('$_notes$_failedWrites'), {
          'the calls of the start': <Object?>[],
          'the calls of the request': [
            'appVersion',
            'isAvailable',
            'requestReview',
          ],
          'the calls of the next call': <Object?>[],
          'saved': {
            'launches': 9,
            'first launch': '2025-12-02T12:00:00.000Z',
            'asked at': null,
            'asked version': null,
          },
          'printed': [launchNotSaved, requestNotSaved],
        });
      });
    });

    group('in an app with guards of the routes', () {
      late DartFiles app;

      setUpAll(() async => app = await _app(routes: _guardedRoutes));

      tearDownAll(() => app.delete());

      test('is code that type-checks with the files of the router role',
          () async {
        expect(await app.analysisProblems(), isEmpty);
      });

      test(
          'asks for no review while the user is in the flow of a guard, also '
          'when the user comes into one while the request is on its way, '
          'and asks once out of every flow', () async {
        expect(await app.run('$_flowsImports$_notes$_flows'), {
          'a gate that does not allow': <Object?>[],
          'a screen of the flow of a gate that allows': <Object?>[],
          'the target of a guard of a condition': <Object?>[],
          'a gate that stops allowing during the request': [
            'appVersion',
            'isAvailable',
          ],
          'a screen outside every flow': [
            'appVersion',
            'isAvailable',
            'requestReview',
          ],
          'asked version': '1.0.0',
        });
      });
    });
  });

  group('the entry of the settings screen', () {
    late String code;
    late CompilationUnit unit;

    setUpAll(() async {
      final rendered = await renderTemplate(
        reviewRole,
        data: [
          dataOf(
            reviewRole,
            _implementation(async: false),
            module: 'fake_review',
          ),
          ..._dataFor(localizationRole),
        ],
        present: {
          preferencesRole,
          envRole,
          settingsScreenRole,
          localizationRole,
        },
      );
      code = rendered.files[ReviewRole.settingFile]!;
      unit = parseString(content: code).unit;
    });

    /// The named arguments of each creation of [className] in the file.
    List<Map<String, String>> created(String className) {
      final found = _NamedArgumentsOf(className);
      unit.accept(found);
      return found.found;
    }

    test(
        'is given to the settings screen role, which shows it while the app '
        'has a page in its store, and has a constant constructor that '
        'requires no arguments', () {
      final data = _dataFor(settingsScreenRole);
      final input = inputOf(
        settingsScreenRole,
        data: data,
        present: {routerRole},
      );

      expect(settingsScreenRole.template.validate(input), isEmpty);
      final entry = settingsScreenRole.entriesIn(input).single;
      expect(entry.widget.name, 'ReviewSetting');
      expect(entry.file, ReviewRole.settingFile);
      expect(entry.showIf!.name, 'reviewSettingShows');
      expect('lib/${entry.showIf!.import.uri}', ReviewRole.settingFile);
      // The data needs no condition: it applies only with the role.
      expect(data.single.when, isEmpty);
      final constructor = unit.declarations
          .whereType<ClassDeclaration>()
          .singleWhere(
            (type) => type.namePart.typeName.lexeme == 'ReviewSetting',
          )
          .body
          .members
          .whereType<ConstructorDeclaration>()
          .single;
      expect(constructor.constKeyword, isNotNull);
      expect(constructor.name, isNull);
      expect('${constructor.parameters}', '({super.key})');
      final shows = _functionsOf(unit)['reviewSettingShows']!;
      expect(
        '${shows.returnType} ${shows.functionExpression.parameters}',
        'bool ()',
      );
      expect(
        '${shows.functionExpression.body}',
        '=> appReview.hasStorePage;',
      );

      // The rule of the role holds the class and the function of the entry
      // to what the screen does with them.
      const index = DartFileIndex(
        path: ReviewRole.settingFile,
        declarations: [
          IndexedDeclaration(
            name: 'ReviewSetting',
            kind: DeclarationKind.classType,
            constructors: [
              IndexedConstructor(
                isConst: true,
                parameters: [
                  IndexedParameter(
                    'key',
                    kind: ParameterKind.optionalNamed,
                  ),
                ],
              ),
            ],
          ),
          IndexedDeclaration(
            name: 'reviewSettingShows',
            kind: DeclarationKind.function,
            type: 'bool',
          ),
        ],
      );
      expect(
        settingsScreenRole.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: data,
              presentRoles: {settingsScreenRole, routerRole, reviewRole},
              context: testContext,
            ),
            files: {ReviewRole.settingFile: index},
            owners: const {ReviewRole.settingFile: _template},
          ),
        ),
        isEmpty,
      );
    });

    test(
        'gives the localization role its texts only in an app with a '
        'settings screen, and reads them from the texts of the app', () {
      final texts = _dataFor(localizationRole);
      expect(texts.single.when, {settingsScreenRole});
      final input = inputOf(
        localizationRole,
        data: texts,
        present: {settingsScreenRole},
      );
      expect(localizationRole.template.validate(input), isEmpty);
      expect(
        [for (final text in localizationRole.textsIn(input)) text.getter],
        ['reviewSettingTitle', 'reviewSettingFailed'],
      );
      for (final text in localizationRole.textsIn(input)) {
        expect(text.owner, _template);
      }

      expect(
        created('ListTile').single['title'],
        '_WholeWords(context.l10n.reviewSettingTitle)',
      );
      expect(
        code,
        contains('final failed = context.l10n.reviewSettingFailed;'),
      );
    });

    test('writes its texts in English in an app without the localization role',
        () async {
      final rendered = await _rendered(present: {settingsScreenRole});
      final english = rendered.files[ReviewRole.settingFile]!;

      expect(english, contains("title: _WholeWords('Rate the app'),"));
      expect(english, contains(r"final failed = 'Couldn\'t open the store.';"));
      expectParses(english);
    });

    test(
        'opens the page for a review on a tap, never asks for the dialog, '
        'and tells in a snack bar that the page did not open', () {
      final row = created('ListTile').single;
      expect(row['leading'], 'const Icon(Icons.star_outline_rounded)');
      expect(
        row['trailing'],
        'SizedBox.square(dimension: 24, child: Icon(Icons.open_in_new_rounded, '
        'size: 20, color: muted))',
      );
      expect(row['onTap'], contains('appReview.openStorePage(review: true)'));
      expect(row['onTap'], contains('SnackBar(content: Text(failed))'));
      expect(code, isNot(contains('requestIfDue')));
      expect(
        [
          for (final directive in unit.directives.whereType<ImportDirective>())
            directive.uri.stringValue,
        ],
        unorderedEquals([
          'package:flutter/material.dart',
          'app_review.dart',
          'package:my_app/core/l10n/l10n.dart',
        ]),
      );
    });
  });

  group('the notes of the review role for coding agents', () {
    test(
        'name what the files of the role declare, in every app and in the '
        'apps with a settings screen', () async {
      final rendered = await _rendered(present: {settingsScreenRole});

      expectNamesOfCode(
        agentNoteOf(reviewRole),
        {
          ReviewRole.controllerFile: [
            'appReview',
            'AppReviewController.requestIfDue',
            'AppReviewController.openStorePage',
            'AppReviewController.hasStorePage',
            'AppReviewController.start',
            'ReviewPolicy',
            'googlePlayId',
            'initReview',
            'createReviewService',
          ],
          ReviewRole.serviceFile: ['ReviewService'],
        },
        files: rendered.files,
      );
      expectNamesOfCode(
        agentNoteOf(reviewRole, when: {settingsScreenRole}),
        {
          ReviewRole.settingFile: ['ReviewSetting'],
        },
        files: rendered.files,
      );
      final note = agentNoteOf(reviewRole).text;
      // The note opens with the call at a natural break, with an example.
      expect(
        note.split('\n').first,
        allOf(
          contains('`appReview.requestIfDue()`'),
          contains('natural break'),
          contains('`unawaited(appReview.requestIfDue());`'),
        ),
      );
      expect(note, contains('`${ReviewRole.appStoreIdKey.name}`'));
      expect(
        agentNoteOf(reviewRole, when: {settingsScreenRole}).text,
        contains('`${ReviewRole.settingFile}`'),
      );
    });
  });

  group('the section of the review role in the README of the app', () {
    /// The section in an app with the roles in [present] and the [routes]
    /// of the router role.
    Future<String> sectionWith(
      Set<Role> present, {
      List<RoleData<Object>> routes = const [],
    }) async {
      final rendered = await _rendered(present: present, routes: routes);
      final section = rendered.elsewhere.singleWhere(
        (entry) => entry.socket == AppEntryRole.readmeSections,
      );
      expect(section.entryKey, ReviewRole.readmeHeading);
      return section.entryValue! as String;
    }

    test(
        'opens with the call at a natural break, with an example, and tells '
        'when a review is due and the pages of the app in its stores, with '
        'the names of the code', () async {
      final rendered = await _rendered(present: {settingsScreenRole});
      final section = await sectionWith({settingsScreenRole});

      expect(
        section.split('\n\n').first,
        'The app asks for a review only where its code calls '
        '`appReview.requestIfDue()` of `${ReviewRole.controllerFile}`. Call '
        'it at a natural break, such as when the user has finished a task:',
      );
      expect(
        section,
        contains(
          '```dart\n'
          'await saveNote(note);\n'
          'unawaited(appReview.requestIfDue());\n'
          '```',
        ),
      );
      expectNamesOfCodeIn(
        section,
        {
          ReviewRole.controllerFile: [
            'appReview',
            'AppReviewController.requestIfDue',
            'AppReviewController.openStorePage',
            'AppReviewController.hasStorePage',
            'ReviewPolicy',
            'ReviewPolicy.launches',
            'ReviewPolicy.sinceFirstLaunch',
            'ReviewPolicy.between',
            'googlePlayId',
          ],
          ReviewRole.settingFile: ['ReviewSetting'],
        },
        files: rendered.files,
      );
      expect(
        section,
        allOf(
          contains('`com.example.my_app`'),
          contains('`${ReviewRole.appStoreIdKey.name}`'),
        ),
      );
    });

    test(
        'tells of the guards of the routes only in an app with guards, and '
        'of the entry only in an app with a settings screen', () async {
      const flows = 'It is never due in the flow of a guard of the routes';
      const entry = 'The entry `ReviewSetting` of the settings screen';

      expect(await sectionWith(const {}), isNot(contains(flows)));
      expect(
        await sectionWith({routerRole}, routes: _homeRoutes),
        isNot(contains(flows)),
      );
      expect(
        await sectionWith({routerRole}, routes: _guardedRoutes),
        contains(flows),
      );
      expect(await sectionWith(const {}), isNot(contains(entry)));
      expect(
        await sectionWith({settingsScreenRole}),
        allOf(contains(entry), contains('`${ReviewRole.settingFile}`')),
      );
    });
  });

  group('the rules of the review role', () {
    const service = 'package:my_app/core/review/review_service.dart';
    const providerFile = 'lib/core/review/fake_review_service.dart';
    const screen = 'lib/features/notes/notes_screen.dart';
    const ofProvider = ModuleOrigin(ModuleId('fake_review'));
    const ofFeature = ModuleOrigin(ModuleId('notes'));
    const requestsHint = 'The code of the app asks for a review at a natural '
        'break of its own, and the role keeps its state to itself.';

    test(
        'let each provider contribute one implementation, and no module put '
        'code into the socket of the implementation', () {
      List<SmfIssue> issuesOf(
        ModuleDescriptor module, {
        List<RoleImplementation> implementations = const [],
        List<Contribution> contributions = const [],
      }) =>
          reviewRole.checkModule(
            ModuleRuleRequest(
              hook: RoleHookRequest(
                data: [
                  for (final implementation in implementations)
                    reviewRole
                        .data(implementation)
                        .withOrigin(ModuleOrigin(module.id)),
                ],
                presentRoles: {reviewRole, preferencesRole, envRole},
                context: testContext,
              ),
              module: module,
              contributions: contributions,
            ),
          );
      final implementation = _implementation(async: false);

      expect(issuesOf(_provider, implementations: [implementation]), isEmpty);
      expect(issuesOf(_feature), isEmpty);
      expect(
        issuesOf(_provider).single.message,
        contains('exactly one implementation, but the module contributes 0'),
      );
      expect(
        issuesOf(_feature, implementations: [implementation]).single.message,
        contains('which only its providers do'),
      );
      final issue = issuesOf(
        _provider,
        implementations: [implementation],
        contributions: const [
          SocketContribution.code(
            ReviewRole.implementations,
            Fragment('late ReviewService _reviewService;'),
          ),
        ],
      ).single;
      expect(issue.message, contains('socket review.implementations'));
    });

    test(
        'review.factory_calls: a file of a module, or of the template of '
        'another role, that calls createReviewService() or imports the file '
        'of ReviewService is reported, but for the files of the '
        'implementation', () {
      const hint = 'Open the page of the app in its store with appReview of '
          'lib/core/review/app_review.dart.';
      const widget = DartFileIndex(
        path: 'lib/core/review/fake_review_widget.dart',
        imports: [IndexedImport('review_service.dart')],
      );
      const prefixed = DartFileIndex(
        path: screen,
        imports: [IndexedImport(service, prefix: 'review')],
      );
      const ofClass = DartFileIndex(
        path: providerFile,
        imports: [IndexedImport('review_service.dart')],
      );

      final issues = _structureIssues({
        _calling('lib/features/notes/notes.dart', 'createReviewService'):
            ofFeature,
        _calling('lib/core/updates/updates.dart', 'createReviewService'):
            RoleTemplateOrigin(_otherRole),
        // Another file of the template of the role itself, and a file that
        // neither a module nor the template of a role owns.
        _calling('lib/core/review/more.dart', 'createReviewService'): _template,
        _calling('lib/mine.dart', 'createReviewService'): null,
        widget: ofProvider,
        prefixed: ofFeature,
        // The file of the class of the implementation, and that of its
        // function, which the helper adds, may.
        ofClass: ofProvider,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          ('lib/features/notes/notes.dart', ofFeature),
          ('lib/core/updates/updates.dart', RoleTemplateOrigin(_otherRole)),
          (widget.path, ofProvider),
          (screen, ofFeature),
        ],
      );
      for (final issue in issues) {
        expect(issue.hint, hint);
      }
      expect(
        issues.first.message,
        'lib/features/notes/notes.dart calls createReviewService(), which no '
        'module may call.',
      );
      expect(
        issues.last.message,
        '$screen imports ${ReviewRole.serviceFile}, the file of '
        'ReviewService, which only the files of the implementation of the '
        'provider of the store reviews role import.',
      );
    });

    test(
        'review.start_calls: only bootstrap() calls initReview(), and no '
        'module calls appReview.start()', () {
      const startHint = 'The role starts the reviews in bootstrap(), which '
          'counts each launch of the app.';
      final issues = _structureIssues({
        _calling(AppEntryRole.bootstrapFile, 'initReview'): null,
        _calling(providerFile, 'initReview'): ofProvider,
        _invoking(screen, 'start'): ofFeature,
        // The template of the role starts the controller itself.
        const DartFileIndex(
          path: 'lib/core/review/more.dart',
          imports: [IndexedImport('app_review.dart')],
          invocations: [IndexedInvocation('start', target: 'appReview')],
        ): _template,
      });

      expect(
        [for (final issue in issues) (issue.message, issue.hint)],
        [
          (
            '$providerFile calls initReview(), which only bootstrap() calls.',
            startHint,
          ),
          (
            '$screen calls appReview.start(), which only initReview() calls.',
            startHint,
          ),
        ],
      );
    });

    test(
        'review.requests: a file of a module, its provider too, or of the '
        'template of another role, that calls appReview.requestIfDue() is '
        'reported, and the code of the app is not', () {
      final issues = _structureIssues({
        _invoking(screen, 'requestIfDue'): ofFeature,
        _invoking(providerFile, 'requestIfDue'): ofProvider,
        _invoking('lib/core/updates/updates.dart', 'requestIfDue'):
            RoleTemplateOrigin(_otherRole),
        // Through a prefix of the import of the file of appReview.
        const DartFileIndex(
          path: 'lib/features/notes/notes_done.dart',
          imports: [
            IndexedImport(
              'package:my_app/core/review/app_review.dart',
              prefix: 'review',
            ),
          ],
          invocations: [
            IndexedInvocation('requestIfDue', target: 'review.appReview'),
          ],
        ): ofFeature,
        // The template of the role itself, and the code of the app, which
        // asks at a natural break of its own.
        _invoking('lib/core/review/more.dart', 'requestIfDue'): _template,
        _invoking('lib/mine.dart', 'requestIfDue'): null,
        // Another object with a method of that name.
        const DartFileIndex(
          path: 'lib/features/notes/notes_list.dart',
          imports: [
            IndexedImport('package:my_app/core/review/app_review.dart'),
          ],
          invocations: [IndexedInvocation('requestIfDue', target: 'other')],
        ): ofFeature,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin, issue.hint)],
        [
          (screen, ofFeature, requestsHint),
          (providerFile, ofProvider, requestsHint),
          (
            'lib/core/updates/updates.dart',
            RoleTemplateOrigin(_otherRole),
            requestsHint,
          ),
          ('lib/features/notes/notes_done.dart', ofFeature, requestsHint),
        ],
      );
      expect(
        issues.first.message,
        '$screen calls appReview.requestIfDue(), which no module calls.',
      );
    });

    test(
        'review.requests: a Dart file of a module, or of the template of '
        'another role, with a key of the role as a string is reported, and '
        'the files of the template of the role are not', () {
      final issues = _structureIssues(
        const {},
        texts: {
          screen: (
            "final asked = preferences.getInt('review.asked_at');",
            ofFeature,
          ),
          'lib/features/notes/notes_count.dart': (
            'final launches = preferences.getInt("review.launches");',
            ofFeature,
          ),
          'lib/core/updates/updates.dart': (
            "const key = 'review.asked_version';",
            RoleTemplateOrigin(_otherRole),
          ),
          // The template of the role keeps its keys, the code of the app
          // is its own, and a file that is no Dart file, or a word that is
          // no string, is no read or write of a key.
          ReviewRole.controllerFile: (
            "static const _askedAtKey = 'review.asked_at';",
            _template,
          ),
          'lib/mine.dart': ("getInt('review.launches');", null),
          'lib/features/notes/README.md': ("'review.launches'", ofFeature),
          'lib/features/notes/notes_text.dart': (
            '// The app keeps review.launches.',
            ofFeature,
          ),
        },
      );

      expect(
        [for (final issue in issues) (issue.message, issue.origin)],
        [
          (
            '$screen has the key review.asked_at of the review role, which '
                'the role keeps to itself.',
            ofFeature,
          ),
          (
            'lib/features/notes/notes_count.dart has the key review.launches '
                'of the review role, which the role keeps to itself.',
            ofFeature,
          ),
          (
            'lib/core/updates/updates.dart has the key review.asked_version '
                'of the review role, which the role keeps to itself.',
            RoleTemplateOrigin(_otherRole),
          ),
        ],
      );
      for (final issue in issues) {
        expect(issue.hint, requestsHint);
      }
    });

    test(
        'review.implementation_factories: the function of the '
        'implementation is in its file and takes no arguments', () {
      final missing = reviewRole.checkStructure(
        StructuralRuleRequest(
          hook: RoleHookRequest(
            data: [
              dataOf(
                reviewRole,
                _implementation(async: false),
                module: 'fake_review',
              ),
            ],
            presentRoles: {reviewRole, preferencesRole, envRole},
            context: testContext,
          ),
          files: const {
            'lib/fakes/fake_review.dart':
                DartFileIndex(path: 'lib/fakes/fake_review.dart'),
          },
        ),
      );
      expect(
        missing.single.message,
        contains('does not declare function createFakeReview()'),
      );
    });
  });
}
