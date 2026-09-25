/// Fake infrastructure modules for the tests of the SMF pipeline. Not
/// modules to use.
library;

import 'package:fake_infra/bundles/fake_analytics_bundle.dart';
import 'package:fake_infra/bundles/fake_codegen_bundle.dart';
import 'package:fake_infra/bundles/fake_crash_bundle.dart';
import 'package:fake_infra/bundles/fake_registrations_bundle.dart';
import 'package:fake_infra/bundles/fake_sockets_bundle.dart';
import 'package:smf_contracts/lego.dart';

const _material = ImportRef('package:flutter/material.dart');
const _foundation = ImportRef('package:flutter/foundation.dart');

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
        AppEntryRole.iosDeploymentTarget.value('14.0'),
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
        AppEntryRole.gradleSettingsPlugins.entry(
          'org.jetbrains.kotlin.plugin.serialization',
          '2.1.0',
        ),
        AppEntryRole.gradleAppPlugins
            .key('org.jetbrains.kotlin.plugin.serialization'),
        AppEntryRole.gradleAppDependencies.entry(
          'androidx.annotation:annotation',
          '1.9.1',
        ),
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
            type: TypeRef('AnalyticsService'),
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
            type: TypeRef('CrashReporter'),
            init: FactoryRef(
              'initFixtureCrashReporter',
              import: ImportRef.app('core/fixture_crash/fixture_crash.dart'),
            ),
          ),
        ),
      ];
}

/// A module that registers services with every capability of the DI role.
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
  static const _zone = TypeRef('FixtureZone', import: _file);

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
            type: _greeting,
            create: FactoryRef(
              'createSingleGreeting',
              import: _file,
              deps: [ServiceRef(_config)],
            ),
            lifetime: DiLifetime.factory,
            params: [TypeRef('String')],
            instanceName: 'single',
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _zone,
            create: FactoryRef('createUtcZone', import: _file),
            instanceName: 'utc',
          ),
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
