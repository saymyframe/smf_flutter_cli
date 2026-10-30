/// Fake infrastructure modules for the tests of the SMF pipeline. Not
/// modules to use.
library;

import 'package:fake_infra/bundles/fake_analytics_bundle.dart';
import 'package:fake_infra/bundles/fake_auth_bundle.dart';
import 'package:fake_infra/bundles/fake_codegen_bundle.dart';
import 'package:fake_infra/bundles/fake_crash_bundle.dart';
import 'package:fake_infra/bundles/fake_env_bundle.dart';
import 'package:fake_infra/bundles/fake_env_user_bundle.dart';
import 'package:fake_infra/bundles/fake_events_bundle.dart';
import 'package:fake_infra/bundles/fake_l10n_bundle.dart';
import 'package:fake_infra/bundles/fake_notifications_bundle.dart';
import 'package:fake_infra/bundles/fake_parent_bundle.dart';
import 'package:fake_infra/bundles/fake_preferences_bundle.dart';
import 'package:fake_infra/bundles/fake_preferences_user_bundle.dart';
import 'package:fake_infra/bundles/fake_purchases_bundle.dart';
import 'package:fake_infra/bundles/fake_push_bundle.dart';
import 'package:fake_infra/bundles/fake_registrations_bundle.dart';
import 'package:fake_infra/bundles/fake_screen_log_bundle.dart';
import 'package:fake_infra/bundles/fake_screen_log_settings_bundle.dart';
import 'package:fake_infra/bundles/fake_service_log_bundle.dart';
import 'package:fake_infra/bundles/fake_sign_in_method_bundle.dart';
import 'package:fake_infra/bundles/fake_slow_start_bundle.dart';
import 'package:fake_infra/bundles/fake_sockets_bundle.dart';
import 'package:fake_infra/bundles/fake_steps_bundle.dart';
import 'package:fake_infra/bundles/fake_theme_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

const _material = ImportRef('package:flutter/material.dart');
const _foundation = ImportRef('package:flutter/foundation.dart');

/// The delegate of the texts of the Material widgets of Flutter, which are
/// in every language that Flutter's widgets are translated into, so in
/// each language of an app.
const _materialDelegate = Fragment(
  'GlobalMaterialLocalizations.delegate',
  imports: [
    ImportRef('package:flutter_localizations/flutter_localizations.dart'),
  ],
);

/// The section of the README that [FakeSocketsModule] and
/// [FakeOverlapModule] both add.
const _readmeSection = 'The app has something in every socket of its entry, '
    'with `code` and a [link](https://example.com).';

/// The comment of the pattern of `.gitignore` that [FakeSocketsModule] and
/// [FakeOverlapModule] both add.
const _logsComment = 'The logs of the fixture';

/// The note for coding agents that [FakeSocketsModule] and
/// [FakeOverlapModule] both add.
const _agentNote = 'The modules of the fixture fill the sockets of the app '
    'entry, and the tests read what the sockets got.';

/// The note for coding agents of [FakeSocketsModule] alone: its files by
/// their paths, and the directories of the fixtures as a pattern.
const _filesAgentNote = 'The assets of the fixture are in `assets/fixture/`, '
    'such as `assets/fixture/readme.txt`, and the Dart files of the fixtures '
    'in the directories `lib/core/fixture_*/`.';

/// A module that puts something into every socket of the app entry that no
/// real module uses yet, and into the `flutter:` section of the pubspec.
///
/// It gives the root of the app no theme and no theme mode: each takes one
/// value, which the theme role gives in an app with a provider of it, so a
/// module that set one could not be in such an app.
///
/// The delegate that it gives the root has no texts of the module: a module
/// gives its texts to the localization role, whose provider knows the
/// languages of the app.
///
/// Its entitlements of the iOS app are of those that only a paid team
/// signs, so it lists the step by hand of the role for them,
/// [AppEntryRole.iosAppIdStep], and an app with it has a section of the
/// steps by hand in its README.
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
        const PubspecContribution.flutter(
          assets: ['assets/fixture/'],
          fonts: [
            PubspecFont('FixtureSans', [
              PubspecFontAsset('fonts/FixtureSans.ttf', weight: 400),
            ]),
          ],
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
          'localizationsDelegates',
          _materialDelegate,
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
          AppEntryRole.androidManifestApplicationComponents,
          Fragment(
            '        <receiver\n'
            '            android:name="com.example.fixture.FixtureReceiver"\n'
            '            android:exported="false" />',
          ),
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
        // Only a paid team signs these entitlements, so the app lists the
        // step by hand of its App ID with each.
        ...AppEntryRole.paidTeamEntitlement(
          'aps-environment',
          const PlistString('development'),
        ),
        ...AppEntryRole.paidTeamEntitlement(
          'com.apple.developer.associated-domains',
          const PlistStringArray(['applinks:example.com']),
        ),
        const SocketContribution.code(
          AppEntryRole.iosAppDelegateLaunch,
          Fragment('    application.applicationSupportsShakeToEdit = true'),
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
        AppEntryRole.androidCoreLibraryDesugaring.value('2.1.4'),
        // .gitignore has the patterns in their order, whatever the order of
        // their contributions.
        AppEntryRole.gitignore.entry(
          '/fixture.local',
          'The values of the fixture that each developer keeps',
        ),
        AppEntryRole.gitignore.entry('*.fixture.log', _logsComment),
        AppEntryRole.readmeSections.entry('Fixture', _readmeSection),
        AppEntryRole.agentSections.entry('Fixture', AgentNote(_agentNote)),
        AppEntryRole.agentSections.entry(
          'Fixture',
          AgentNote(_filesAgentNote),
        ),
      ];
}

/// A module that puts into the sockets of the app entry some of the keys
/// and values that [FakeSocketsModule] does, so an app with both merges
/// them: equal permissions, meta-data, plist strings, entitlements,
/// patterns of `.gitignore` and README sections agree, the plist arrays of
/// Info.plist and of the entitlements and the comments of a pattern of
/// `.gitignore` are united, the highest versions win, those of Gradle and of
/// the library of core library desugaring too, the delegate of the
/// localizations appears once, and so do the note for coding agents and the
/// step by hand that both have. It puts nothing into the sockets of code of
/// the native files, such as the components of the Android application,
/// which would have the same code twice.
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
        const PubspecContribution.sdk('flutter_localizations'),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'localizationsDelegates',
          _materialDelegate,
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
        // Only a paid team signs these entitlements, so the app lists the
        // step by hand of its App ID with each.
        ...AppEntryRole.paidTeamEntitlement(
          'aps-environment',
          const PlistString('development'),
        ),
        ...AppEntryRole.paidTeamEntitlement(
          'com.apple.developer.associated-domains',
          const PlistStringArray(['applinks:example.org']),
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
        AppEntryRole.androidCoreLibraryDesugaring.value('2.1.3'),
        AppEntryRole.gitignore.entry('*.fixture.log', _logsComment),
        // The pattern of fake_sockets in other words: .gitignore has both.
        AppEntryRole.gitignore.entry(
          '/fixture.local',
          'What the fixture keeps on one machine',
        ),
        AppEntryRole.readmeSections.entry('Fixture', _readmeSection),
        AppEntryRole.agentSections.entry('Fixture', AgentNote(_agentNote)),
      ];
}

/// A provider of the localization role that keeps the texts of the app in
/// one Dart file, with a delegate written by hand: no tool generates code
/// from its files, as one does from the files of translations of a
/// provider that has them.
///
/// Its render hook writes a getter for each text of the app, which returns
/// the text in the language of the texts, among the languages of the app,
/// or in English.
final class FakeL10nModule extends SmfModule {
  /// Creates the module.
  const FakeL10nModule();

  /// The id of the module.
  static const id = ModuleId('fake_l10n');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'The texts of the app in one Dart file (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [_FakeL10nProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeL10nBundle),
        SocketContribution.arg(
          AppEntryRole.appArgs,
          'localizationsDelegates',
          Fragment(
            'FixtureTexts.delegate',
            imports: [LocalizationRole.appTexts.importRef],
          ),
        ),
      ];
}

final class _FakeL10nProvider extends RoleProvider<TextsData> {
  const _FakeL10nProvider();

  @override
  Role<TextsData> get role => localizationRole;

  @override
  RoleOutput render(RoleHookInput<TextsData> input) {
    final locales = localizationRole.localesIn(input);
    return RoleOutput(
      vars: {
        'getters': Fragment(
          [
            for (final text in localizationRole.textsIn(input))
              _getterOf(text, locales),
          ].join('\n\n'),
        ),
      },
    );
  }

  /// The getter of [text] in the class of the texts, which returns its
  /// translation into the language of the texts, among [locales], or its
  /// English text.
  String _getterOf(AppText text, List<String> locales) {
    final translations = [
      for (final language in locales)
        if (text.text.translations[language] case final translation?)
          "        '$language' => ${SmfNames.dartString(translation)},",
    ];
    final english = SmfNames.dartString(text.text.en);
    return [
      '  /// The $text.',
      if (translations.isEmpty)
        '  String get ${text.getter} => $english;'
      else ...[
        '  String get ${text.getter} => switch (language) {',
        ...translations,
        '        _ => $english,',
        '      };',
      ],
    ].join('\n');
  }
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
/// with a settings screen, it generates the widget of its settings, two
/// rows that belong together, and gives the role an entry for it. The
/// widget has the class name of the setting of the second fixture feature,
/// `FixtureSetting`, in a file of its own: an app with both analyzes only
/// if the screen imports the file of each with a prefix of its own, as the
/// role asks of every provider.
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
              'FixtureSetting',
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

/// A module with two steps of the onboarding, which it gives the onboarding
/// screen role in an app with that role: `ask`, with the button `later`
/// and a function that says whether the onboarding shows it, and then
/// `confirm`, without either. Their actions note each call. That of `ask`
/// fails when a test says so, and otherwise shows a screen of its own over
/// the onboarding, as a route without a page on the navigator at the root
/// of the app, which it finds from the context of the onboarding screen.
/// It waits until that screen is closed, and then for what a test holds it
/// back with. A test also says whether the onboarding shows `ask`.
///
/// It uses the localization role: the texts of the steps are texts of the
/// module, in English and in Ukrainian, but for the text of `confirm`,
/// which has no translation and reads in English in every language.
final class FakeStepsModule extends SmfModule {
  /// Creates the module.
  const FakeStepsModule();

  /// The id of the module.
  static const id = ModuleId('fake_steps');

  static const _file = ImportRef.app('core/fixture_steps/fixture_steps.dart');

  static const _askTitle = LocalizedText(
    'askTitle',
    en: 'A step that asks',
    translations: {'uk': 'Крок, що питає'},
  );
  static const _askText = LocalizedText(
    'askText',
    en: 'The fixture asks for something here.',
    translations: {'uk': 'Тут фікстура про щось питає.'},
  );
  static const _askAction = LocalizedText(
    'askAction',
    en: 'Ask',
    translations: {'uk': 'Спитати'},
  );
  static const _askLater = LocalizedText(
    'askLater',
    en: 'Not now',
    translations: {'uk': 'Не зараз'},
  );
  static const _confirmTitle = LocalizedText(
    'confirmTitle',
    en: 'A step that confirms',
    translations: {'uk': 'Крок, що підтверджує'},
  );
  static const _confirmText = LocalizedText(
    'confirmText',
    en: 'The fixture confirms something here.',
  );
  static const _confirmAction = LocalizedText(
    'confirmAction',
    en: 'Confirm',
    translations: {'uk': 'Підтвердити'},
  );

  static const _icons = [ImportRef('package:flutter/material.dart')];

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Two steps of the onboarding (fixture)',
        kind: ModuleKinds.infrastructure,
        uses: {onboardingScreenRole, localizationRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        // Only an app with an onboarding gets the functions of the steps
        // and their texts.
        BrickContribution(
          fakeStepsBundle,
          when: const {onboardingScreenRole},
        ),
        localizationRole.data(
          const TextsData([
            _askTitle,
            _askText,
            _askAction,
            _askLater,
            _confirmTitle,
            _confirmText,
            _confirmAction,
          ]),
          when: const {onboardingScreenRole},
        ),
        onboardingScreenRole.data(
          const OnboardingStep(
            name: 'ask',
            stage: OnboardingStage.permission,
            icon: Fragment('Icons.help_outline', imports: _icons),
            title: _askTitle,
            text: _askText,
            action: _askAction,
            later: _askLater,
            run: FunctionRef('askFixture', import: _file),
            showIf: FunctionRef('showsFixtureAsk', import: _file),
          ),
        ),
        onboardingScreenRole.data(
          const OnboardingStep(
            name: 'confirm',
            stage: OnboardingStage.permission,
            icon: Fragment('Icons.check_circle_outline', imports: _icons),
            title: _confirmTitle,
            text: _confirmText,
            action: _confirmAction,
            run: FunctionRef('confirmFixture', import: _file),
          ),
        ),
      ];
}

/// A provider of the theme role, which has at most one provider, whose look
/// depends on state of its own: its light theme and its dark theme derive
/// their colours from a colour that it keeps and that a test changes. The
/// colour is one of its own at first, so its themes differ from those that
/// Flutter gives an app without a theme.
///
/// The two functions of the themes read the colour from the context of the
/// root of the app, which the role gives them, through an inherited widget
/// that the module puts among the root wrappers: the root rebuilds in the
/// new colours when the colour changes.
///
/// The template of the role does the rest in an app with it: the theme mode
/// that the user selects, which the preferences of the app remember, and
/// the entry of the settings screen that selects it.
final class FakeThemeModule extends SmfModule {
  /// Creates the module.
  const FakeThemeModule();

  /// The id of the module.
  static const id = ModuleId('fake_theme');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A light and a dark theme of a colour that it keeps '
            '(fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(themeRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeThemeBundle),
        SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap(
            'FixtureSeedScope(notifier: fixtureSeed, child: ',
            ')',
            imports: [ThemeRole.createLightTheme.importRef],
          ),
        ),
      ];
}

/// A provider of the auth role, which has at most one provider, whose
/// service opens asynchronously, as one does that reads the storage of the
/// device. It keeps the accounts in memory, where they stand for the server
/// of a provider, and the user who is signed in on the device, whom each
/// start of the app reads anew.
///
/// A start of the app keeps the accounts and that user, and loses that the
/// user signed in a short while ago: the fixture deletes the account of a
/// user whom the start found on the device only once that user has signed
/// in again, as the role lets a provider ask. An anonymous user has nothing
/// to sign in with again, so the fixture deletes one whenever it is asked
/// to.
///
/// It takes a credential of any identity provider whose token is a test
/// token: a JSON Web Token without a signature whose payload has the issuer
/// of the credential, the subject of the identity, maybe its email address
/// and maybe a nonce, the `rawNonce` of the credential, as
/// [FakeSignInMethodModule] gives. It takes a token with a nonce once, as an
/// identity provider that checks a nonce does. It keeps each identity by
/// its issuer and its subject: a link keeps the id of the user, an identity
/// of another user is `credentialInUse`, and one whose address has an
/// account of another user is `accountExistsWithOtherMethod`. A refused
/// link takes the token too, and keeps the identity for the credential
/// object in an `Expando`, which a sign-in with the identical object then
/// takes, as the role asks of a provider.
///
/// The template of the role does the rest in an app with it, whichever
/// module provides the role: the session of the app, and the mode of the
/// app, which the fixture has the same code for.
final class FakeAuthModule extends SmfModule {
  /// Creates the module.
  const FakeAuthModule();

  /// The id of the module.
  static const id = ModuleId('fake_auth');

  static const _file = ImportRef.app('core/fixture_auth/fixture_auth.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Sign-in with accounts in memory (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(authRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeAuthBundle),
        authRole.data(
          const AuthImplementation.async(
            type: TypeRef('FixtureAuth', import: _file),
            init: FactoryRef('openFixtureAuth', import: _file),
          ),
        ),
      ];
}

/// A way to sign in with the identity provider of the fixture, which a
/// module that requires the auth role gives the role: the template of the
/// role lists it in `appSignInMethods` of the app, whichever module
/// provides the role.
///
/// Its function asks no platform: it returns a credential a turn of the
/// event loop later, as a sheet of an identity provider does, and each
/// time of the one identity of the fixture, with a test token that the
/// fixture sign-in takes, a new nonce and a new authorization code. It
/// works on Android and on iOS, the App Store takes it as the equivalent
/// of a login service of a third party, and the deletion of an account
/// that signs in with it asks it for a credential again. Its label is in
/// English and in Ukrainian, a text that it gives the localization role,
/// which it uses.
final class FakeSignInMethodModule extends SmfModule {
  /// Creates the module.
  const FakeSignInMethodModule();

  /// The id of the module.
  static const id = ModuleId('fake_sign_in_method');

  /// The issuer of the tokens of the identity provider of the fixture.
  static const issuer = 'https://accounts.fixture.example.com';

  /// The label of the button of the way to sign in.
  static const label = LocalizedText(
    'label',
    en: 'Continue with the fixture',
    translations: {'uk': 'Продовжити з фікстурою'},
  );

  static const _file = ImportRef.app(
    'core/fixture_sign_in_method/fixture_sign_in_method.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Sign-in with the identity provider of the fixture '
            '(fixture)',
        kind: ModuleKinds.infrastructure,
        requires: {authRole},
        uses: {localizationRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          fakeSignInMethodBundle,
          vars: const {'issuer': issuer},
        ),
        authRole.data(
          const SignInMethod(
            label: label,
            icon: TypeRef('FixtureSignInIcon', import: _file),
            platforms: {AppPlatform.android, AppPlatform.ios},
            credential: FunctionRef('fixtureCredential', import: _file),
            issuer: issuer,
            appStore: AppStoreLogin.privacyFocused,
            revokesOnDeletion: true,
          ),
        ),
        localizationRole.data(const TextsData([label])),
      ];
}

/// A provider of the notifications role, which has at most one provider,
/// whose service opens asynchronously, as one does that asks the system for
/// what it keeps. It keeps in memory whether the app may show notifications
/// and the notifications that are scheduled, where they stand for the
/// settings and the alarms of the system, which each start of the app reads
/// anew.
///
/// Its system has no question for the permission, as Android before 13, so
/// a request opens the settings of the system, where the user of the tests
/// turns the notifications on, as the mocks of a provider grant the
/// permission when the app asks. Through the role, that looks like a
/// question that the user allows. It shows nothing, and tells of no tap.
///
/// The template of the role does the rest in an app with it, whichever
/// module provides the role: `appNotifications`, which remembers in the
/// preferences that the app asked.
final class FakeNotificationsModule extends SmfModule {
  /// Creates the module.
  const FakeNotificationsModule();

  /// The id of the module.
  static const id = ModuleId('fake_notifications');

  static const _file = ImportRef.app(
    'core/fixture_notifications/fixture_notifications.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Notifications in memory (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(notificationsRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeNotificationsBundle),
        notificationsRole.data(
          const RoleImplementation.async(
            type: TypeRef('FixtureNotifications', import: _file),
            init: FactoryRef('openFixtureNotifications', import: _file),
          ),
        ),
      ];
}

/// A provider of the push role, which has at most one provider, whose
/// service opens asynchronously, as one does that asks the system for what
/// it keeps. It keeps the address of the device in memory, where it stands
/// for the registration of the device with the service of push messages,
/// which each start of the app finds as the last one left it: the first
/// start registers the device, which gets its address a while later, as an
/// iPhone gets the token of APNs, and the next starts have the same
/// address.
///
/// The device shows nothing itself, so the app shows a message that
/// arrives in the foreground. No server sends a message and no user taps
/// one, so the service tells of neither.
///
/// The template of the role does the rest in an app with it, whichever
/// module provides the role: `appPush`, which shows a message through the
/// notifications of the app, the role that it requires.
final class FakePushModule extends SmfModule {
  /// Creates the module.
  const FakePushModule();

  /// The id of the module.
  static const id = ModuleId('fake_push');

  static const _file = ImportRef.app('core/fixture_push/fixture_push.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Push messages in memory (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(pushRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakePushBundle),
        pushRole.data(
          const RoleImplementation.async(
            type: TypeRef('FixturePush', import: _file),
            init: FactoryRef('openFixturePush', import: _file),
          ),
        ),
      ];
}

/// A provider of the purchases role, which has at most one provider, whose
/// service opens asynchronously, as one does that asks the store for what
/// it keeps, and each of whose calls takes a turn of the event loop. Its
/// offer has three plans: one that renews each month, with a free week for
/// a user who never bought it, one that renews each year, and one that the
/// user pays for once. A purchase by a user without premium access
/// completes at once and succeeds.
///
/// It keeps in memory what each user of the app bought, and the user whom
/// the device has, where they stand for the backend of a provider and the
/// storage of the device, which each start of the app finds as the last
/// one left them. It keeps the purchases of each user as the role says,
/// with the user of the device: `identify(null)` after another user starts
/// a new user of the device with nothing bought, a user that no
/// identification named before takes over the purchases of the user of the
/// device, and a restore gives the user who is identified what was bought
/// on the device.
///
/// The template of the role does the rest in an app with it, whichever
/// module provides the role: `appPurchases`, which follows the session of
/// an app with sign-in.
final class FakePurchasesModule extends SmfModule {
  /// Creates the module.
  const FakePurchasesModule();

  /// The id of the module.
  static const id = ModuleId('fake_purchases');

  static const _file = ImportRef.app(
    'core/fixture_purchases/fixture_purchases.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Purchases in memory (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(purchasesRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakePurchasesBundle),
        purchasesRole.data(
          const RoleImplementation.async(
            type: TypeRef('FixturePurchases', import: _file),
            init: FactoryRef('openFixturePurchases', import: _file),
          ),
        ),
      ];
}

/// A provider of the env role with code of its own: `AppEnv` keeps in a
/// constant map what a command of the `flutter` tool read from `.env`,
/// given `--dart-define-from-file .env` (the flag and the path as two
/// arguments, which it gives the role), and a static getter of each key
/// returns its value from the map, or `null` while it is empty or missing.
///
/// Its render hook writes the getters and the map for the keys of the app,
/// and an app without keys has the class without members. The template of
/// the role does the rest, whichever module provides it: `.env`,
/// `.env.example` and the entry of `.env` in `.gitignore`.
final class FakeEnvModule extends SmfModule {
  /// Creates the module.
  const FakeEnvModule();

  /// The id of the module.
  static const id = ModuleId('fake_env');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'The values of .env in a constant map (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [_FakeEnvProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeEnvBundle),
        envRole.data(
          const EnvToolArguments([
            '--dart-define-from-file',
            EnvRole.dotEnvFile,
          ]),
        ),
      ];
}

/// Renders the members of `AppEnv` of [FakeEnvModule] for the keys of the
/// app.
final class _FakeEnvProvider extends RoleProvider<EnvData> {
  const _FakeEnvProvider();

  @override
  Role<EnvData> get role => envRole;

  @override
  RoleOutput render(RoleHookInput<EnvData> input) {
    final keys = envRole.keysIn(input);
    return RoleOutput(
      vars: {
        'fixture_env_members': Fragment(
          keys.isEmpty
              ? ''
              : [
                  for (final key in keys) _getterOf(key),
                  _valuesOf(keys),
                  _valueOf,
                ].join('\n\n'),
        ),
      },
    );
  }

  /// The getter of [key], which reads its value from the map.
  static String _getterOf(AppEnvKey key) {
    final name = SmfNames.dartString(key.name);
    return '  /// The value of `${key.name}`.\n'
        '  static String? get ${key.getter} => _valueOf($name);';
  }

  /// The map of what the command that built the app read from `.env` for
  /// [keys]: an empty value as an empty text, and no entry for a key that
  /// `.env` lacks, which the command did not define.
  static String _valuesOf(List<AppEnvKey> keys) => [
        _valuesDoc,
        '  static const Map<String, String> _values = {',
        for (final name in [
          for (final key in keys) SmfNames.dartString(key.name),
        ]) ...[
          '    if (bool.hasEnvironment($name))',
          '      $name: String.fromEnvironment($name),',
        ],
        '  };',
      ].join('\n');

  /// The doc of the map of the values.
  static const _valuesDoc = '''
  /// What the command that built the app read from `.env`, by the keys of
  /// the app: an empty value as an empty text, and no entry for a key that
  /// `.env` lacks.''';

  /// The function that the getters read their values with.
  static const _valueOf = '''
  /// The value of [key], or `null` while `.env` leaves it empty or lacks
  /// it.
  static String? _valueOf(String key) {
    final value = _values[key];
    return value == null || value.isEmpty ? null : value;
  }''';
}

/// A provider of the CI role in a format of its own, which no host reads: the
/// file [file], with a block for each environment that has the name of the
/// environment in its commands, and a line for each key.
///
/// It shows that the role needs no host. The template of the role does the
/// rest, whichever module provides it: the script that writes `.env`, and the
/// section of the role in the README.
final class FakeCiModule extends SmfModule {
  /// Creates the module.
  const FakeCiModule();

  /// The id of the module.
  static const id = ModuleId('fake_ci');

  /// The path of the file of the module.
  static const file = 'ci/pipeline.conf';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'CI in a format of its own (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [_FakeCiProvider()],
      );
}

/// Writes the pipeline of the app for [FakeCiModule].
final class _FakeCiProvider extends RoleProvider<NoDsl> {
  const _FakeCiProvider();

  @override
  Role<NoDsl> get role => ciRole;

  @override
  RoleOutput render(RoleHookInput<NoDsl> input) {
    final pipeline = ciRole.pipelineIn(input);
    final build = pipeline.build;
    return RoleOutput(
      files: {
        FakeCiModule.file: [
          '# The CI of a fixture.',
          'on push',
          for (final check in pipeline.checks) _run(check),
          for (final environment in build.environments) ...[
            'on request $environment',
            for (final key in build.keys) '  variable $key',
            for (final command in build.prepare) _run(command),
            '  run ${build.name} = ${build.command.of(environment)}',
            '  keep ${build.artifact.of(environment)}',
          ],
          '',
        ].join('\n'),
      },
    );
  }

  /// The line of [command].
  static String _run(CiCommand command) =>
      '  run ${command.name} = ${command.command}';
}

/// A module that reads three values of `.env`, which it gives the env role
/// as keys in an app with that role: `FAKE_ENV_USER_FIRST`,
/// `FAKE_ENV_USER_SECOND` and `FAKE_ENV_USER_THIRD`. Its brick reads each
/// through the variable of its key ([EnvRole.varsOf]), so it reads `null`
/// in an app without the role.
final class FakeEnvUserModule extends SmfModule {
  /// Creates the module.
  const FakeEnvUserModule();

  /// The id of the module.
  static const id = ModuleId('fake_env_user');

  /// The keys of the module, in their order.
  static const keys = [
    EnvKey(
      'FAKE_ENV_USER_FIRST',
      description: 'The first value of the fixture',
    ),
    EnvKey(
      'FAKE_ENV_USER_SECOND',
      description: 'The second value of the fixture',
    ),
    EnvKey(
      'FAKE_ENV_USER_THIRD',
      description: 'The third value of the fixture',
    ),
  ];

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Three values of .env (fixture)',
        kind: ModuleKinds.infrastructure,
        uses: {envRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          fakeEnvUserBundle,
          vars: envRole.varsOf(id, keys),
        ),
        for (final key in keys) envRole.data(key),
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
