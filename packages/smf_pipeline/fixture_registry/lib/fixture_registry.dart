/// The registry of the fake modules in `smf_pipeline/test/fixtures/`, for
/// the tests of the SMF pipeline. Not a registry to use.
///
/// Together the fake modules use the features of the module model that the
/// real modules do not use yet; see the README of the fixtures. Real
/// modules take part where the fixtures need them:
/// - flutter_core creates the app;
/// - go_router routes the fake features too, so their routes compile with a
///   real router, which asks their guards too, and bottom tabs provide the
///   layout, so an app with the two fake features has a main navigation
///   with either router, and two screens that can start it;
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
import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_bottom_tabs/smf_bottom_tabs.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_auth/smf_firebase_auth.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';
import 'package:smf_material_theme/smf_material_theme.dart';
import 'package:smf_onboarding/smf_onboarding.dart';
import 'package:smf_riverpod/smf_riverpod.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:smf_sign_in/smf_sign_in.dart';

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
      const FakeLateGateModule(),
      const FakeGateModule(),
      const FakeSocketsModule(),
      const FakeOverlapModule(),
      const FakeL10nModule(),
      const FakeAnalyticsModule(),
      const FakeScreenLogModule(),
      const FakeCrashModule(),
      const FakeEventsModule(),
      const FakePreferencesModule(),
      const FakePreferencesUserModule(),
      const FakeThemeModule(),
      const FakeAuthModule(),
      const FakeRegistrationsModule(),
      const FakeParentModule(),
      const FakeChildModule(),
      const FakeCodegenModule(),
      const FakeClockBadgeModule(),
      const FakeClockUserModule(),
      const BottomTabsModule(),
    ];

/// The modules to ask for so that an app has every fixture that fits, with
/// the state manager [stateManager], the router [router] and the DI
/// container [di]: the fixture late gate and the fixture gates, and so the
/// guards of the routes, are only in an app with the state manager that
/// they depend on. The late gate comes before the gates, as in
/// [fixtureModules], though the app asks its guard after theirs.
List<ModuleId> everyFixture({
  ModuleId stateManager = FakeBlocModule.id,
  ModuleId router = FakeRouterModule.id,
  ModuleId di = FakeDiModule.id,
}) =>
    [
      FakeFeatureModule.id,
      FakeSecondModule.id,
      // The fixture late gate and the fixture gates depend on one of the
      // state managers.
      if (stateManager == FakeGateModule.stateManager) ...[
        FakeLateGateModule.id,
        FakeGateModule.id,
      ],
      router,
      stateManager,
      di,
      FakeSocketsModule.id,
      FakeOverlapModule.id,
      FakeL10nModule.id,
      FakeRegistrationsModule.id,
      FakeCodegenModule.id,
      FakeScreenLogModule.id,
      FakeCrashModule.id,
      FakeEventsModule.id,
      FakePreferencesModule.id,
      FakePreferencesUserModule.id,
      FakeThemeModule.id,
      FakeAuthModule.id,
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
/// a fixture module whose start-up waits for a timer; flutter_core and
/// go_router, the app entry and a router, for the screens that Firebase
/// Analytics logs; get_it, a DI container, in which those roles register
/// their services, for the test of the DI role that the CLI keeps; the
/// fixture events, whose channel opens in the start-up, for the test of the
/// events role that the CLI keeps; shared_preferences, a provider of the
/// preferences role, for the test of that role that the CLI keeps; the
/// settings module of the CLI, for the app test that it keeps for its
/// screen and for the tests of the settings screen role that the CLI keeps,
/// with the two fixtures that have a setting, a feature and a module
/// without screens, so that those tests check a screen with entries on a
/// provider that must work; material_theme, a provider of the theme role,
/// for the tests of that role that the CLI keeps: the theme mode, which
/// shared_preferences remembers, and its entry, which the settings screen
/// shows below those of the two fixtures; the fixture texts, a provider of
/// the localization role, for the two tests of that role that the CLI
/// keeps: the test of the role itself, with the texts of the fixture
/// feature in two languages, and the test of the setting of the language,
/// which the template of the role gives the settings screen of the app
/// after the entry of the theme mode; the onboarding module of the CLI,
/// for the app test that it keeps, whose guard of the routes keeps the user
/// from every other screen of the app until the mocks of that test open it
/// for the tests of the other modules; the home module of the CLI, for
/// the app test that it keeps for its screen. It comes after the fixture
/// feature, on whose screen the app starts, so that test goes to its screen
/// through the navigation of the router role, and reads its texts from the
/// fixture texts; Firebase Authentication, the provider of the auth
/// role that the CLI has, for the app test that it keeps and for the test
/// of that role that the CLI keeps, which run there next to the other
/// Firebase modules and with the fixture texts as the languages of the
/// app; and the sign-in module of the CLI, for the app test that it keeps,
/// with the two state managers of the CLI, bloc and riverpod, since a
/// registry has every provider that one of its modules has a variant for.
/// The app asks for an account, as an app in the first mode of the auth
/// role does, so the guards of the sign-in keep the user from every other
/// screen until the mocks of that test sign an account up for the tests of
/// the other modules.
///
/// With two state managers, the registry has two apps with every module,
/// one for each. Its tool checks the first one, in which the screens of the
/// sign-in keep their state with bloc (see `severalProvidersApps` of
/// `matrix_app_tests.dart`): the matrix of the CLI checks the sign-in with
/// each state manager.
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
      GetItModule(),
      FirebaseCoreModule(),
      FirebaseCrashlyticsModule(),
      FirebaseAnalyticsModule(),
      FakeCrashModule(),
      FakeAnalyticsModule(),
      FakeServiceLogModule(),
      FakeEventsModule(),
      SharedPreferencesModule(),
      FakeSlowStartModule(),
      FakeSecondModule(),
      FakeScreenLogModule(),
      SettingsModule(),
      MaterialThemeModule(),
      FakeL10nModule(),
      OnboardingModule(),
      HomeModule(),
      FirebaseAuthModule(),
      BlocModule(),
      RiverpodModule(),
      SignInModule(),
    ];
