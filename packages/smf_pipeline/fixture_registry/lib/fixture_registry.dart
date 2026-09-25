/// The registry of the fake modules in `smf_pipeline/test/fixtures/`, for
/// the tests of the SMF pipeline. Not a registry to use.
///
/// Together the fake modules use the features of the module model that the
/// real modules do not use yet; see the README of the fixtures.
library;

import 'package:fake_di/fake_di.dart';
import 'package:fake_feature/fake_feature.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fake_roles/fake_roles.dart';
import 'package:fake_router/fake_router.dart';
import 'package:fake_state/fake_state.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';

/// Every fixture module and flutter_core, which creates the app, with a DI
/// container of all capabilities, or of [diCapabilities] if set.
List<SmfModule> fixtureModules({Set<DiCapability>? diCapabilities}) => [
      const FlutterCoreModule(),
      const FakeRouterModule(),
      if (diCapabilities == null)
        const FakeDiModule()
      else
        FakeDiModule(capabilities: diCapabilities),
      const FakeBlocModule(),
      const FakeRiverpodModule(),
      const FakeFeatureModule(),
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
    ];

/// The modules to ask for so that an app has every fixture, with the
/// state manager [stateManager].
List<ModuleId> everyFixture({
  ModuleId stateManager = FakeBlocModule.id,
}) =>
    [
      FakeFeatureModule.id,
      stateManager,
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
