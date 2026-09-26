/// The registry of the fake modules in `smf_pipeline/test/fixtures/`, for
/// the tests of the SMF pipeline. Not a registry to use.
///
/// Together the fake modules use the features of the module model that the
/// real modules do not use yet; see the README of the fixtures. Real
/// modules take part where the fixtures need them: flutter_core creates the
/// app, go_router routes the fake features too, so their routes compile
/// with a real router, bottom tabs provide the layout, so an app with the
/// two fake features and go_router has a main navigation, which the fake
/// router does not have, and get_it registers the services of the fixtures
/// too, so their registrations compile with a real container. Either way,
/// the app has two screens that can start it.
library;

import 'package:fake_di/fake_di.dart';
import 'package:fake_feature/fake_feature.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fake_roles/fake_roles.dart';
import 'package:fake_router/fake_router.dart';
import 'package:fake_state/fake_state.dart';
import 'package:smf_bottom_tabs/smf_bottom_tabs.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_go_router/smf_go_router.dart';

/// Every fixture module, flutter_core, which creates the app, go_router, a
/// second router, bottom tabs, and get_it, a second DI container, with a
/// fake DI container of all capabilities, or of [diCapabilities] if set.
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
      FakeCrashModule.id,
      FakeEventsModule.id,
      FakeChildModule.id,
      FakeClockUserModule.id,
      FakeClockBadgeModule.id,
    ];
