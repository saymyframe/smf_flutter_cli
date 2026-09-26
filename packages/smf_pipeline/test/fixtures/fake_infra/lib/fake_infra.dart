/// Fake infrastructure modules for the tests of the SMF pipeline. Not
/// modules to use.
library;

import 'package:fake_infra/bundles/fake_analytics_bundle.dart';
import 'package:fake_infra/bundles/fake_codegen_bundle.dart';
import 'package:fake_infra/bundles/fake_crash_bundle.dart';
import 'package:fake_infra/bundles/fake_events_bundle.dart';
import 'package:fake_infra/bundles/fake_parent_bundle.dart';
import 'package:fake_infra/bundles/fake_registrations_bundle.dart';
import 'package:fake_infra/bundles/fake_sockets_bundle.dart';
import 'package:smf_contracts/lego.dart';

const _material = ImportRef('package:flutter/material.dart');
const _foundation = ImportRef('package:flutter/foundation.dart');

/// The section of the README that [FakeSocketsModule] and
/// [FakeOverlapModule] both add.
const _readmeSection = 'The app has something in every socket of its entry, '
    'with `code` and a [link](https://example.com).';

/// A module that puts something into every socket of the app entry that no
/// real module uses yet, and into the `flutter:` section of the pubspec.
final class FakeSocketsModule extends SmfModule {
  /// Creates the module.
  const FakeSocketsModule();

  /// The id of the module.
  static const id = ModuleId('fake_sockets');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Every socket of the app entry (fixture)',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeSocketsBundle),
        const PubspecContribution.sdk('flutter_localizations'),
        const PubspecContribution.hosted('intl', 'any'),
        const PubspecContribution.flutter(
          assets: ['assets/fixture/'],
          fonts: [
            PubspecFont('FixtureSans', [
              PubspecFontAsset('fonts/FixtureSans.ttf', weight: 400),
            ]),
          ],
          generate: true,
        ),
        const SocketContribution.code(
          AppEntryRole.topLevel,
          Fragment(
            "@pragma('vm:entry-point')\n"
            'Future<void> fixtureBackgroundHandler() async {}',
          ),
        ),
        const SocketContribution.code(
          AppEntryRole.bootstrapEarly,
          Fragment("debugPrint('early');", imports: [_foundation]),
        ),
        const SocketContribution.code(
          AppEntryRole.bootstrapPlatform,
          Fragment("debugPrint('platform');", imports: [_foundation]),
        ),
        const SocketContribution.code(
          AppEntryRole.bootstrapDi,
          Fragment("debugPrint('di');", imports: [_foundation]),
        ),
        const SocketContribution.code(
          AppEntryRole.bootstrapLate,
          Fragment("debugPrint('late');", imports: [_foundation]),
        ),
        const SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap(
            'RepaintBoundary(child: ',
            ')',
            imports: [_material],
          ),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'theme',
          Fragment(
            'ThemeData(fontFamily: "FixtureSans")',
            imports: [_material],
          ),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'darkTheme',
          Fragment('ThemeData.dark()', imports: [_material]),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'localizationsDelegates',
          Fragment(
            'AppLocalizations.delegate',
            imports: [ImportRef.app('l10n/app_localizations.dart')],
          ),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'localizationsDelegates',
          Fragment(
            'GlobalMaterialLocalizations.delegate',
            imports: [
              ImportRef(
                'package:flutter_localizations/flutter_localizations.dart',
              ),
            ],
          ),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'supportedLocales',
          Fragment("Locale('en')", imports: [_material]),
        ),
        const SocketContribution.wrap(
          AppEntryRole.appBuilder,
          Fragment.wrap(
            'MediaQuery.withNoTextScaling(child: ',
            ')',
            imports: [_material],
          ),
        ),
        AppEntryRole.iosDeploymentTarget.value('16.0'),
        AppEntryRole.androidManifestPermissions
            .key('android.permission.INTERNET'),
        AppEntryRole.androidManifestPermissions
            .key('android.permission.VIBRATE'),
        AppEntryRole.androidManifestApplicationMeta.entry(
          'com.example.fixture.KEY',
          const AndroidMetaData.value('fixture'),
        ),
        AppEntryRole.androidManifestApplicationMeta.entry(
          'com.example.fixture.ICON',
          const AndroidMetaData.resource('@mipmap/ic_launcher'),
        ),
        const SocketContribution.code(
          AppEntryRole.mainActivityIntentFilters,
          Fragment(
            '<intent-filter>\n'
            '    <action android:name="android.intent.action.VIEW" />\n'
            '    <category android:name="android.intent.category.DEFAULT" />\n'
            '    <category android:name="android.intent.category.BROWSABLE" />\n'
            '    <data android:scheme="fixture" />\n'
            '</intent-filter>',
          ),
        ),
        AppEntryRole.infoPlist.entry(
          'FixtureName',
          const PlistString('Fixture'),
        ),
        AppEntryRole.infoPlist.entry(
          'LSApplicationQueriesSchemes',
          const PlistStringArray(['fixture']),
        ),
        AppEntryRole.infoPlist.entry(
          'UIBackgroundModes',
          const PlistStringArray(['fetch']),
        ),
        // A plugin that only adds a task, so it builds with any version of
        // the Android and Kotlin plugins.
        AppEntryRole.gradleSettingsPlugins.entry(
          'io.github.ben-manes.versions',
          '0.64.0',
        ),
        AppEntryRole.gradleAppPlugins.key('io.github.ben-manes.versions'),
        AppEntryRole.gradleAppDependencies.entry(
          'androidx.annotation:annotation',
          '1.9.1',
        ),
        AppEntryRole.readmeSections.entry('Fixture', _readmeSection),
      ];
}

/// A module that puts into the sockets of the app entry some of the keys
/// and values that [FakeSocketsModule] does, so an app with both merges
/// them: equal permissions, meta-data, plist strings and README sections
/// agree, the plist arrays are united, the highest versions win, and the
/// supported locale appears once.
final class FakeOverlapModule extends SmfModule {
  /// Creates the module.
  const FakeOverlapModule();

  /// The id of the module.
  static const id = ModuleId('fake_overlap');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'The keys of fake_sockets again (fixture)',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'supportedLocales',
          Fragment("Locale('en')", imports: [_material]),
        ),
        AppEntryRole.iosDeploymentTarget.value('15.4'),
        AppEntryRole.androidManifestPermissions
            .key('android.permission.INTERNET'),
        AppEntryRole.androidManifestApplicationMeta.entry(
          'com.example.fixture.KEY',
          const AndroidMetaData.value('fixture'),
        ),
        AppEntryRole.infoPlist.entry(
          'FixtureName',
          const PlistString('Fixture'),
        ),
        AppEntryRole.infoPlist.entry(
          'UIBackgroundModes',
          const PlistStringArray(['remote-notification']),
        ),
        AppEntryRole.gradleSettingsPlugins.entry(
          'io.github.ben-manes.versions',
          '0.63.0',
        ),
        AppEntryRole.gradleAppPlugins.key('io.github.ben-manes.versions'),
        AppEntryRole.gradleAppDependencies.entry(
          'androidx.annotation:annotation',
          '1.8.0',
        ),
        AppEntryRole.readmeSections.entry('Fixture', _readmeSection),
      ];
}

/// A provider of the analytics role whose service logs nothing, with a
/// navigator observer for every navigator of the router.
final class FakeAnalyticsModule extends SmfModule {
  /// Creates the module.
  const FakeAnalyticsModule();

  /// The id of the module.
  static const id = ModuleId('fake_analytics');

  static const _file = ImportRef.app(
    'core/fixture_analytics/fixture_analytics.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Analytics that logs nothing (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(analyticsRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeAnalyticsBundle),
        analyticsRole.data(
          const RoleImplementation(
            type: TypeRef('FixtureAnalytics', import: _file),
            create: FactoryRef('createFixtureAnalytics', import: _file),
          ),
        ),
        const SocketContribution.item(
          RouterRole.observers,
          Fragment('() => FixtureObserver()', imports: [_file]),
          when: {routerRole},
        ),
      ];
}

/// A provider of the crash reporting role whose service is ready only
/// after an asynchronous start.
final class FakeCrashModule extends SmfModule {
  /// Creates the module.
  const FakeCrashModule();

  /// The id of the module.
  static const id = ModuleId('fake_crash');

  static const _file = ImportRef.app('core/fixture_crash/fixture_crash.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Crash reporting that starts asynchronously (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(crashReportingRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeCrashBundle),
        crashReportingRole.data(
          const RoleImplementation.async(
            type: TypeRef('FixtureCrashReporter', import: _file),
            init: FactoryRef('initFixtureCrashReporter', import: _file),
          ),
        ),
      ];
}

/// A provider of the events role, which has at most one provider, whose
/// channel opens asynchronously.
final class FakeEventsModule extends SmfModule {
  /// Creates the module.
  const FakeEventsModule();

  /// The id of the module.
  static const id = ModuleId('fake_events');

  static const _file = ImportRef.app(
    'core/fixture_events/fixture_events.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Events that start asynchronously (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(eventsRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeEventsBundle),
        eventsRole.data(
          const RoleImplementation.async(
            type: TypeRef('FixtureEvents', import: _file),
            init: FactoryRef('openFixtureEvents', import: _file),
          ),
        ),
      ];
}

/// A module that registers services with every capability of the DI role,
/// in each form a DI container can have to render: singletons, lazy
/// singletons and factories, with and without names; singletons created
/// asynchronously, and singletons that wait for them, named or not, by
/// saying so or by taking them; factories with one and two parameters; and
/// functions that dispose of singletons of each kind.
final class FakeRegistrationsModule extends SmfModule {
  /// Creates the module.
  const FakeRegistrationsModule();

  /// The id of the module.
  static const id = ModuleId('fake_registrations');

  static const _file = ImportRef.app(
    'core/fixture_services/fixture_services.dart',
  );

  static const _config = TypeRef('FixtureConfig', import: _file);
  static const _api = TypeRef('FixtureApi', import: _file);
  static const _session = TypeRef('FixtureSession', import: _file);
  static const _cache = TypeRef('FixtureCache', import: _file);
  static const _greeting = TypeRef('FixtureGreeting', import: _file);
  static const _label = TypeRef('FixtureLabel', import: _file);
  static const _zone = TypeRef('FixtureZone', import: _file);
  static const _stamp = TypeRef('FixtureStamp', import: _file);
  static const _log = TypeRef('FixtureLog', import: _file);
  static const _index = TypeRef('FixtureIndex', import: _file);
  static const _replica = TypeRef('FixtureReplica', import: _file);
  static const _counter = TypeRef('FixtureCounter', import: _file);

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Services with every DI capability (fixture)',
        kind: ModuleKinds.infrastructure,
        requires: {diRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeRegistrationsBundle),
        diRole.data(
          const DiRegistration(
            type: _config,
            create: FactoryRef('createFixtureConfig', import: _file),
            lifetime: DiLifetime.singleton,
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _api,
            create: FactoryRef(
              'createFixtureApi',
              import: _file,
              deps: [ServiceRef(_config)],
            ),
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _session,
            create: FactoryRef('openFixtureSession', import: _file),
            lifetime: DiLifetime.singleton,
            isAsync: true,
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _cache,
            create: FactoryRef(
              'createFixtureCache',
              import: _file,
              deps: [ServiceRef(_api)],
            ),
            lifetime: DiLifetime.singleton,
            dependsOn: [ServiceRef(_session)],
            dispose: FunctionRef('closeFixtureCache', import: _file),
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _greeting,
            create: FactoryRef(
              'createFixtureGreeting',
              import: _file,
              deps: [ServiceRef(_config)],
            ),
            lifetime: DiLifetime.factory,
            params: [TypeRef('String'), TypeRef('int')],
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _label,
            create: FactoryRef(
              'createFixtureLabel',
              import: _file,
              deps: [ServiceRef(_config)],
            ),
            lifetime: DiLifetime.factory,
            params: [TypeRef('String')],
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _zone,
            create: FactoryRef('createUtcZone', import: _file),
            instanceName: 'utc',
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _stamp,
            create: FactoryRef(
              'createFixtureStamp',
              import: _file,
              deps: [ServiceRef(_zone, instanceName: 'utc')],
            ),
            lifetime: DiLifetime.factory,
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _log,
            create: FactoryRef('createAuditLog', import: _file),
            lifetime: DiLifetime.singleton,
            dispose: FunctionRef('closeFixtureLog', import: _file),
            instanceName: 'audit',
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _index,
            create: FactoryRef(
              'createFixtureIndex',
              import: _file,
              deps: [ServiceRef(_session)],
            ),
            lifetime: DiLifetime.singleton,
            instanceName: 'primary',
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _session,
            create: FactoryRef('openBackupSession', import: _file),
            lifetime: DiLifetime.singleton,
            isAsync: true,
            dispose: FunctionRef('closeFixtureSession', import: _file),
            instanceName: 'backup',
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _replica,
            create: FactoryRef('openFixtureReplica', import: _file),
            lifetime: DiLifetime.singleton,
            isAsync: true,
            dependsOn: [ServiceRef(_session, instanceName: 'backup')],
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _counter,
            create: FactoryRef('createFixtureCounter', import: _file),
            dispose: FunctionRef('closeFixtureCounter', import: _file),
          ),
        ),
      ];
}

/// A module with sockets of its own, which only the modules that depend on
/// it fill: code that runs when it is set up, and a family with a member
/// for each kind of channel it opens.
final class FakeParentModule extends SmfModule {
  /// Creates the module.
  const FakeParentModule();

  /// The id of the module.
  static const id = ModuleId('fake_parent');

  /// Statements that run in `setUpFixtureParent()`, which the late phase of
  /// `bootstrap()` calls.
  static const setup = SocketRef<CodeSocket>.module(id, 'setup', CodeSocket());

  /// Statements that run when the channels of a kind open; the kinds are
  /// `alerts` and `news`.
  static const channels = SocketFamily<String, CodeSocket>.module(
    id,
    'channels',
    CodeSocket(),
    keyOf: _channelSegments,
    segments: 1,
  );

  static List<String> _channelSegments(String kind) => [kind];

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Sockets for the modules that depend on it (fixture)',
        kind: ModuleKinds.infrastructure,
        sockets: [setup],
        socketFamilies: [channels],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeParentBundle),
        const SocketContribution.code(
          AppEntryRole.bootstrapLate,
          Fragment(
            'setUpFixtureParent();',
            imports: [ImportRef.app('core/fixture_parent/fixture_parent.dart')],
          ),
        ),
      ];
}

/// A module that depends on [FakeParentModule] and fills its sockets.
final class FakeChildModule extends SmfModule {
  /// Creates the module.
  const FakeChildModule();

  /// The id of the module.
  static const id = ModuleId('fake_child');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Fills the sockets of fake_parent (fixture)',
        kind: ModuleKinds.infrastructure,
        dependsOn: {FakeParentModule.id},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        const SocketContribution.code(
          FakeParentModule.setup,
          Fragment("debugPrint('child set up');", imports: [_foundation]),
        ),
        SocketContribution.code(
          FakeParentModule.channels('alerts'),
          const Fragment("debugPrint('child alerts');", imports: [_foundation]),
        ),
      ];
}

/// A module that needs code generation: a JSON model for `build_runner`.
final class FakeCodegenModule extends SmfModule {
  /// Creates the module.
  const FakeCodegenModule();

  /// The id of the module.
  static const id = ModuleId('fake_codegen');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A model generated by build_runner (fixture)',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeCodegenBundle),
        const PubspecContribution.hosted('json_annotation', '^4.9.0'),
        const PubspecContribution.hosted(
          'json_serializable',
          '^6.9.0',
          dev: true,
        ),
        const CodegenRequest(description: 'JSON code of FixtureModel'),
      ];
}
