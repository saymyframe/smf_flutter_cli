/// The registry of the fake modules in `smf_pipeline/test/fixtures/`, for
/// the tests of the SMF pipeline. Not a registry to use.
///
/// Together the fake modules use the features of the module model that the
/// real modules do not use yet; see the README of the fixtures. Real
/// modules take part where the fixtures need them:
/// - flutter_core creates the app;
/// - go_router routes the fake features too, so their routes compile with a
///   real router, and bottom tabs provide the layout, so an app with the two
///   fake features has a main navigation with either router, and two
///   screens that can start it;
/// - get_it registers the services of the fixtures too, so their
///   registrations compile with a real container.
///
/// The registry of several providers ([severalProvidersModules]) puts the
/// modules of the CLI that provide a role an app can have several
/// providers of next to fixture providers of the same roles.
library;

import 'package:fake_di/fake_di.dart';
import 'package:fake_feature/fake_feature.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fake_roles/fake_roles.dart';
import 'package:fake_router/fake_router.dart';
import 'package:fake_state/fake_state.dart';
import 'package:smf_bottom_tabs/smf_bottom_tabs.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_go_router/smf_go_router.dart';

/// Every fixture module, with a fake DI container of all capabilities, or
/// of [diCapabilities] if set, and the real modules: flutter_core, which
/// creates the app, go_router, a second router, bottom tabs, and get_it, a
/// second DI container.
List<SmfModule> fixtureModules({Set<DiCapability>? diCapabilities}) => [
      const FlutterCoreModule(),
      const FakeRouterModule(),
      const GoRouterModule(),
      if (diCapabilities == null)
        const FakeDiModule()
      else
        FakeDiModule(capabilities: diCapabilities),
      const GetItModule(),
      const FakeBlocModule(),
      const FakeRiverpodModule(),
      const FakeFeatureModule(),
      const FakeSecondModule(),
      const FakeSocketsModule(),
      const FakeOverlapModule(),
      const FakeAnalyticsModule(),
      const FakeScreenLogModule(),
      const FakeCrashModule(),
      const FakeEventsModule(),
      const FakeRegistrationsModule(),
      const FakeParentModule(),
      const FakeChildModule(),
      const FakeCodegenModule(),
      const FakeClockBadgeModule(),
      const FakeClockUserModule(),
      const BottomTabsModule(),
    ];

/// The modules to ask for so that an app has every fixture, with the
/// state manager [stateManager], the router [router] and the DI container
/// [di].
List<ModuleId> everyFixture({
  ModuleId stateManager = FakeBlocModule.id,
  ModuleId router = FakeRouterModule.id,
  ModuleId di = FakeDiModule.id,
}) =>
    [
      FakeFeatureModule.id,
      FakeSecondModule.id,
      router,
      stateManager,
      di,
      FakeSocketsModule.id,
      FakeOverlapModule.id,
      FakeRegistrationsModule.id,
      FakeCodegenModule.id,
      FakeScreenLogModule.id,
      FakeCrashModule.id,
      FakeEventsModule.id,
      FakeChildModule.id,
      FakeClockUserModule.id,
      FakeClockBadgeModule.id,
    ];

/// The registry of several providers: the modules of the CLI that provide a
/// role an app can have several providers of, Firebase Crashlytics and
/// Firebase Analytics, with the module they depend on, next to the fixture
/// providers of the same roles, whose start-up and services go through
/// platform channels of their own; a fixture that provides both roles and
/// notes each call that reaches it, which the tests of the roles look at;
/// a fixture module whose start-up waits for a timer; and flutter_core and
/// go_router, the app entry and a router, for the screens that Firebase
/// Analytics logs.
///
/// Its app with every module is where the tests that the providers keep
/// for the apps they are in run next to the other providers of their
/// roles and whatever else the start-up of an app does: they must pass in
/// every app with their module, whose other modules only their own tests
/// know. There the tests of the roles check that each call reaches every
/// provider, whatever the others do with it.
List<SmfModule> severalProvidersModules() => const [
      FlutterCoreModule(),
      GoRouterModule(),
      FirebaseCoreModule(),
      FirebaseCrashlyticsModule(),
      FirebaseAnalyticsModule(),
      FakeCrashModule(),
      FakeAnalyticsModule(),
      FakeServiceLogModule(),
      FakeSlowStartModule(),
    ];
