/// Fake infrastructure modules for the tests of the SMF pipeline. Not
/// modules to use.
library;

import 'package:fake_infra/bundles/fake_analytics_bundle.dart';
import 'package:fake_infra/bundles/fake_codegen_bundle.dart';
import 'package:fake_infra/bundles/fake_crash_bundle.dart';
import 'package:fake_infra/bundles/fake_events_bundle.dart';
import 'package:fake_infra/bundles/fake_parent_bundle.dart';
import 'package:fake_infra/bundles/fake_preferences_bundle.dart';
import 'package:fake_infra/bundles/fake_preferences_user_bundle.dart';
import 'package:fake_infra/bundles/fake_registrations_bundle.dart';
import 'package:fake_infra/bundles/fake_screen_log_bundle.dart';
import 'package:fake_infra/bundles/fake_screen_log_settings_bundle.dart';
import 'package:fake_infra/bundles/fake_service_log_bundle.dart';
import 'package:fake_infra/bundles/fake_slow_start_bundle.dart';
import 'package:fake_infra/bundles/fake_sockets_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

const _material = ImportRef('package:flutter/material.dart');
const _foundation = ImportRef('package:flutter/foundation.dart');

/// The section of the README that [FakeSocketsModule] and
/// [FakeOverlapModule] both add.
const _readmeSection = 'The app has something in every socket of its entry, '
    'with `code` and a [link](https://example.com).';

/// A module that puts something into every socket of the app entry that no
/// real module uses yet, and into the `flutter:` section of the pubspec.
///
/// Its root wrapper is an inherited widget with a theme mode, and the theme
/// mode that it gives the root of the app reads that widget from the
/// context of the root: an argument of the root that depends on a widget
/// among the root wrappers.
final class FakeSocketsModule extends SmfModule {
  /// Creates the module.
  const FakeSocketsModule();

  /// The id of the module.
  static const id = ModuleId('fake_sockets');

  static const _themeMode = ImportRef.app(
    'core/fixture_theme_mode/fixture_theme_mode.dart',
  );

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
            'FixtureThemeMode(mode: ThemeMode.system, child: ',
            ')',
            imports: [_material, _themeMode],
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
          'themeMode',
          Fragment('FixtureThemeMode.of(context)', imports: [_themeMode]),
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

/// A provider of the analytics role whose service starts asynchronously and
/// sends what it records to a platform side of its own, which only the
/// mocks of its app tests answer, with a navigator observer for every
/// navigator of the router, which notes the routes that come on its
/// navigator, and a listener of the screen the user sees.
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
        description: 'Analytics with a platform side (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(analyticsRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeAnalyticsBundle),
        analyticsRole.data(
          const RoleImplementation.async(
            type: TypeRef('FixtureAnalytics', import: _file),
            init: FactoryRef('initFixtureAnalytics', import: _file),
          ),
        ),
        const SocketContribution.item(
          RouterRole.observers,
          Fragment('() => FixtureObserver()', imports: [_file]),
          when: {routerRole},
        ),
        const SocketContribution.item(
          RouterRole.screenListeners,
          Fragment('noteFixtureScreen', imports: [_file]),
          when: {routerRole},
        ),
      ];
}

/// A module that logs the screens the user sees with a listener of the
/// screen of the router role, which it requires, and has no routes: so an
/// app with it and without routes to start on starts on the fallback screen
/// of the app entry, and an app with it and the fixture analytics has two
/// listeners of the screen. It uses the settings screen role: in an app
/// with a settings screen, it generates the widget of a setting and gives
/// the role an entry for it.
final class FakeScreenLogModule extends SmfModule {
  /// Creates the module.
  const FakeScreenLogModule();

  /// The id of the module.
  static const id = ModuleId('fake_screen_log');

  static const _file = ImportRef.app(
    'core/fixture_screen_log/fixture_screen_log.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A log of the screens the user sees (fixture)',
        kind: ModuleKinds.infrastructure,
        requires: {routerRole},
        uses: {settingsScreenRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeScreenLogBundle),
        const SocketContribution.item(
          RouterRole.screenListeners,
          Fragment('noteFixtureScreenLog', imports: [_file]),
        ),
        // Only an app with a settings screen gets the widget of the
        // setting, and only there does the entry apply.
        BrickContribution(
          fakeScreenLogSettingsBundle,
          when: const {settingsScreenRole},
        ),
        settingsScreenRole.data(
          const SettingsEntry(
            widget: TypeRef(
              'FixtureScreenLogSetting',
              import: ImportRef.app(
                'core/fixture_screen_log/fixture_screen_log_setting.dart',
              ),
            ),
          ),
        ),
      ];
}

/// A provider of the crash reporting role whose service is ready only
/// after an asynchronous start, and which sends every report to a platform
/// side of its own, which only the mocks of its app tests answer.
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

/// A provider of the analytics role and of the crash reporting role whose
/// services, created synchronously, note each call in lists that the tests
/// of those roles read, and misbehave when a test says so: their factories
/// throw, they throw as they are called or return a future that fails, and
/// the analytics service changes the map of parameters that it gets.
///
/// The tests of a role that an app can have several providers of look at
/// what reaches it, next to the other providers of the role, whose own
/// tests check what they do with a call.
final class FakeServiceLogModule extends SmfModule {
  /// Creates the module.
  const FakeServiceLogModule();

  /// The id of the module.
  static const id = ModuleId('fake_service_log');

  static const _file = ImportRef.app(
    'core/fixture_service_log/fixture_service_log.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Analytics and crash reporting that note every call '
            '(fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [
          RoleProvider.plain(analyticsRole),
          RoleProvider.plain(crashReportingRole),
        ],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeServiceLogBundle),
        analyticsRole.data(
          const RoleImplementation(
            type: TypeRef('ServiceLogAnalytics', import: _file),
            create: FactoryRef('createServiceLogAnalytics', import: _file),
          ),
        ),
        crashReportingRole.data(
          const RoleImplementation(
            type: TypeRef('ServiceLogCrashReporter', import: _file),
            create: FactoryRef('createServiceLogCrashReporter', import: _file),
          ),
        ),
      ];
}

/// A module whose start-up does what the start-up of a real app may do and
/// what the fake time of a widget test does not let finish: it waits for a
/// timer, leaves another one running and replaces the widget that shows
/// the errors of a build.
final class FakeSlowStartModule extends SmfModule {
  /// Creates the module.
  const FakeSlowStartModule();

  /// The id of the module.
  static const id = ModuleId('fake_slow_start');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A start-up that waits for a timer (fixture)',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeSlowStartBundle),
        const SocketContribution.code(
          AppEntryRole.bootstrapLate,
          Fragment(
            'await startFixture();',
            imports: [ImportRef.app('core/fixture_start/fixture_start.dart')],
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

/// A provider of the preferences role, which has at most one provider,
/// whose preferences are created with the app: they keep the settings in
/// memory, over a map that stands for the disk of a device, which each start
/// of the app reads anew.
final class FakePreferencesModule extends SmfModule {
  /// Creates the module.
  const FakePreferencesModule();

  /// The id of the module.
  static const id = ModuleId('fake_preferences');

  static const _file = ImportRef.app(
    'core/fixture_preferences/fixture_preferences.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Preferences in memory (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(preferencesRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakePreferencesBundle),
        preferencesRole.data(
          const RoleImplementation(
            type: TypeRef('FixturePreferences', import: _file),
            create: FactoryRef('createFixturePreferences', import: _file),
          ),
        ),
      ];
}

/// A module that works with the preferences when the app has them: it
/// keeps a setting, a number, which its restorer takes from the preferences
/// when the app starts and which it saves there from then on. It gives the
/// role two restorers, which note what they read and throw when a test says
/// so. Without the preferences, the setting lasts only as long as the app
/// runs.
final class FakePreferencesUserModule extends SmfModule {
  /// Creates the module.
  const FakePreferencesUserModule();

  /// The id of the module.
  static const id = ModuleId('fake_preferences_user');

  static const _file = ImportRef.app(
    'core/fixture_setting/fixture_setting.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A setting that the preferences remember (fixture)',
        kind: ModuleKinds.infrastructure,
        uses: {preferencesRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakePreferencesUserBundle),
        const SocketContribution.item(
          PreferencesRole.restorers,
          Fragment('noteFixtureSetting', imports: [_file]),
          when: {preferencesRole},
        ),
        const SocketContribution.item(
          PreferencesRole.restorers,
          Fragment('restoreFixtureSetting', imports: [_file]),
          when: {preferencesRole},
        ),
      ];
}

/// A module that registers services with every capability of the DI role,
/// in each form a DI container can have to render: singletons, lazy
/// singletons and factories, with and without names; singletons created
/// asynchronously, and singletons that wait for them, named or not, by
/// saying so or by taking them; and functions that dispose of singletons of
/// each kind.
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
            type: _stamp,
            create: FactoryRef('createLocalStamp', import: _file),
            lifetime: DiLifetime.factory,
            instanceName: 'local',
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
