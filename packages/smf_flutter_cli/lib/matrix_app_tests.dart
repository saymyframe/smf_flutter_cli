/// The tests that the matrix of CI adds to the apps of the modules of
/// `smf create`, for `tool/matrix.dart` and for the app of several
/// providers of the fixture registry. No library of the binary imports it.
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_auth/smf_firebase_auth.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';
import 'package:smf_onboarding/smf_onboarding.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:smf_sign_in/smf_sign_in.dart';

/// The tests that the matrix of the modules of `smf create` adds to its
/// apps, which the CLI and the packages of its modules keep in their
/// `app_tests`, and the roles whose contract they check with every
/// provider; `tool/matrix.dart` runs them in CI.
///
/// Only that tool, the tests of the CLI and the app of several providers of
/// the fixture registry, which runs them next to other providers of their
/// roles, use them: they name the modules whose app tests they register and
/// the roles whose contract those check, which the binary knows nothing of.
Future<MatrixAppTests> smfAppTests() async {
  final cli = await appTestsDirectoryOf('smf_flutter_cli');
  final firebaseCore = await appTestsDirectoryOf('smf_firebase_core');
  final crashlytics = await appTestsDirectoryOf('smf_firebase_crashlytics');
  final analytics = await appTestsDirectoryOf('smf_firebase_analytics');
  final firebaseAuth = await appTestsDirectoryOf('smf_firebase_auth');
  final home = await appTestsDirectoryOf('smf_home_flutter');
  final onboarding = await appTestsDirectoryOf('smf_onboarding');
  final settings = await appTestsDirectoryOf('smf_settings');
  final sharedPreferences = await appTestsDirectoryOf(
    'smf_shared_preferences',
  );
  final signIn = await appTestsDirectoryOf('smf_sign_in');
  return MatrixAppTests(
    [
      // The app starts and shows its first screen: a check that CI builds
      // as the entry of the app and starts on an Android emulator and on an
      // iOS simulator with .github/scripts/start_app.sh, in the apps that
      // it adds it to with --add-app-tests. It knows no module, only main()
      // of lib/main.dart, which the app entry role puts into every app
      // whichever module provides it, so the CLI keeps it and it applies to
      // every app. In the apps of the matrix it is only analyzed, and
      // flutter test runs the tests that the modules put into each app.
      // Once the first screen settled, it runs the probes of the tests that
      // go into the app with it, which go through the roles of the app,
      // such as the walk of its routes.
      MatrixAppTest(
        '$cli/start',
        appliesTo: (_) => true,
        readsStartProbes: true,
      ),
      // The start-up of the app initializes Firebase, with the options that
      // `flutterfire configure` would write, and the mocks of Firebase Core,
      // which the matrix sets up for the tests of every module of the app.
      MatrixAppTest(
        '$firebaseCore/firebase_core',
        appliesTo: _has(FirebaseCoreModule.id),
        devDependencies: const ['firebase_core_platform_interface'],
        mocks: const MatrixMocks(
          'test/firebase_core_mocks.dart',
          'mockFirebaseCore',
        ),
      ),
      // The crash reporter of the module reaches Crashlytics, and the
      // errors that nothing catches reach it through the handlers that the
      // start-up of the app installs. The tests look only at what reaches
      // Crashlytics, not at the other crash reporters that the app may
      // have.
      MatrixAppTest(
        '$crashlytics/firebase_crashlytics',
        appliesTo: _has(FirebaseCrashlyticsModule.id),
        devDependencies: const ['firebase_crashlytics_platform_interface'],
        mocks: const MatrixMocks(
          'test/firebase_crashlytics_mocks.dart',
          'mockFirebaseCrashlytics',
        ),
      ),
      // The analytics service of the module reaches Firebase Analytics. The
      // test leaves out the other analytics services that the app may have.
      MatrixAppTest(
        '$analytics/firebase_analytics',
        appliesTo: _has(FirebaseAnalyticsModule.id),
        mocks: const MatrixMocks(
          'test/firebase_analytics_mocks.dart',
          'mockFirebaseAnalytics',
        ),
      ),
      // The first screen of an app with a router is logged once, under the
      // name of the screen that the app starts on (see _startScreenOf),
      // whichever module provides the router, which calls the listener of
      // the screen of Firebase Analytics: a test of the router role too, so
      // it finds the apps with a router by their roles.
      MatrixAppTest(
        '$analytics/screen_views',
        appliesTo: (app) =>
            _has(FirebaseAnalyticsModule.id)(app) &&
            app.hook!.presentRoles.contains(routerRole),
        values: (app) => {'start_screen': _startScreenOf(app)},
        roles: {routerRole},
      ),
      // The sign-in service of the module on Firebase Authentication: what
      // each of its calls sends to Firebase; the reason that it gives each
      // code of Firebase, in the form in which Android and iOS send it;
      // the user whom it finds on the device when it is created; a call
      // for a user whose session has ended on the server, which signs that
      // user out; and the language in which it asks Firebase for the
      // message of a password reset, the one that the app is in (see
      // _messageLanguagesOf). The tests use the service of the module, and
      // leave what every provider of the auth role does to the test of the
      // role. The mocks are a backend in memory with no account and nobody
      // signed in, and the matrix sets them up for the tests of every
      // module of the app, since the start-up of the app starts the
      // session of the app on Firebase Authentication. Its probe compares,
      // on a device, the user of the session with the one that the Firebase
      // SDK has there.
      MatrixAppTest(
        '$firebaseAuth/firebase_auth',
        appliesTo: _has(FirebaseAuthModule.id),
        devDependencies: const ['firebase_auth_platform_interface'],
        generatedFiles: _messageLanguagesOf,
        mocks: const MatrixMocks(
          'test/firebase_auth_mocks.dart',
          'mockFirebaseAuth',
        ),
        startProbe: const MatrixStartProbe(
          'integration_test/firebase_auth/probe.dart',
          'probeFirebaseAuth',
        ),
      ),
      // The onboarding of the module: on its first launch, the app shows
      // it in place of the screen that it starts on (see
      // _startScreenFileOf), and the button of its last page or Skip saves
      // that it is finished and shows that screen; an app that finds it
      // finished goes straight there. The onboarding has its texts in each
      // language of the app, as the device asks for it (see
      // _onboardingTextsFileOf). The router
      // leaves the onboarding, whichever module provides it, as the router
      // role says of the guards of the routes: a test of the router role
      // too. The mocks finish the onboarding before the app starts, in
      // memory, and the matrix sets them up for the tests of every module
      // of the app, which expect the screens that the guard of the
      // onboarding would keep them from. Its probe goes through the
      // onboarding on a device, where a first launch finds nothing saved,
      // unless the onboarding is finished there. The test comes before the
      // walk of the routes in this list, whose probe then goes through the
      // routes of an app past its onboarding. For the route of the
      // onboarding, whose flow is over by then, the walk expects the screen
      // that the app starts on, or the target of a guard that does not
      // allow there. So on a device the start check leaves the app with the
      // onboarding finished.
      MatrixAppTest(
        '$onboarding/onboarding',
        appliesTo: _has(OnboardingModule.id),
        generatedFiles: (app, packageName) => {
          ..._startScreenFileOf(app, packageName),
          ..._onboardingTextsFileOf(app),
        },
        roles: {routerRole},
        mocks: const MatrixMocks(
          'test/onboarding_mocks.dart',
          'finishOnboarding',
        ),
        startProbe: const MatrixStartProbe(
          'integration_test/onboarding/probe.dart',
          'probeOnboarding',
        ),
      ),
      // The settings screen of the module. Its title is in the language of
      // the app: the test goes through the languages of the app that the
      // module has its title in, which the matrix writes from the
      // localization role of the app, English alone for an app without the
      // role. Below the title it shows the entries of the app in one
      // group, or, in an app without settings, a note for its developer
      // with the path of the file of the screen, which a tap copies. And
      // it has a back button only on top of another screen, where the
      // button leads back. For these, the matrix writes how many entries
      // the screen has and whether it is a destination of the main
      // navigation, where code cannot push it (see _settingsOfAppOf).
      MatrixAppTest(
        '$settings/settings',
        appliesTo: _has(SettingsModule.id),
        generatedFiles: (app, packageName) => {
          ..._settingsLanguagesOf(app, packageName),
          ..._settingsOfAppOf(app),
        },
      ),
      // The preferences of the module reach shared_preferences, and read
      // what it has when they are opened, lists in the form that each
      // platform returns them in. The mocks keep the platform side of the
      // package in memory, and the matrix sets them up for the tests of
      // every module of the app, since the start-up of the app opens the
      // preferences. Its probe opens the preferences again on a device,
      // where the platform side is the real one, and reads back what it
      // saved.
      MatrixAppTest(
        '$sharedPreferences/shared_preferences',
        appliesTo: _has(SharedPreferencesModule.id),
        devDependencies: const ['shared_preferences_platform_interface'],
        mocks: const MatrixMocks(
          'test/shared_preferences_mocks.dart',
          'mockSharedPreferences',
        ),
        startProbe: const MatrixStartProbe(
          'integration_test/shared_preferences/probe.dart',
          'probeSharedPreferences',
        ),
      ),
      // The start screen of the module, a welcome to the developer of the
      // app, wherever the app starts: it names the app, greets by the time
      // of the day and lists the next steps with their paths, with its
      // texts in each language of the app (see _homeTextsFileOf); a tap on
      // a step copies its path and says so; its parts come in once, at
      // once in an app that asks for less motion; and it fits a small
      // phone with a large text size. The tests go to the route of the
      // module through the navigation of the router role, so they hold in
      // an app that starts on another screen too.
      MatrixAppTest(
        '$home/home',
        appliesTo: _has(HomeModule.id),
        generatedFiles: (app, packageName) => _homeTextsFileOf(app),
      ),
      // The screens of sign-in of the module, in each mode of the auth
      // role, which the app has as a constant: an app that asks for an
      // account shows the sign-in on its first launch in place of the
      // screen that it starts on (see _signInOfAppOf), and an app that
      // everyone may use shows it once code asks for it; a sign-up, a
      // sign-in and a sign-out go through the session of the app, and an
      // anonymous user keeps the id with the account; the forms show what
      // is wrong with an email address and a password, the text of each
      // failure of a call in each language of the app, and that a call is
      // on its way; a password reset tells where the message went; and the
      // screens fit a small phone with a large text size. The screens only
      // change the session: the router shows them and leaves them,
      // whichever module provides it, as the router role says of the
      // guards of the routes, so this is a test of the router role too.
      // The mocks sign a test account up before the app starts, through
      // the session, and the matrix sets them up for the tests of every
      // module of the app, which expect the screens that the guards of the
      // sign-in would keep them from. The test has no probe for the start
      // check: nobody can sign in on a device, and the walk of the routes
      // shows the screens there.
      MatrixAppTest(
        '$signIn/sign_in',
        appliesTo: _has(SignInModule.id),
        generatedFiles: _signInOfAppOf,
        roles: {routerRole},
        mocks: const MatrixMocks(
          'test/sign_in_mocks.dart',
          'signUpTestAccount',
        ),
      ),
      // The services of the apps whose modules register some in the DI
      // container, whichever module provides it.
      await diRoleAppTest(),
      // The events of the apps with the events role, whichever module
      // provides it.
      await eventsRoleAppTest(),
      // The preferences of the apps with the preferences role, whichever
      // module provides it.
      await preferencesRoleAppTest(),
      // The sign-in of the apps with the auth role, whichever module
      // provides it, in the mode that the role chose for each: the service
      // of the provider keeps its contract, and the session of the app
      // does what the mode says.
      await authRoleAppTest(),
      // The routes of the apps with a router, whichever module provides
      // it: the test starts the app and goes to each location that needs
      // no values.
      await routerWalkAppTest(),
      // The settings screen of the apps with the settings screen role,
      // whichever module provides it: the route that the provider names
      // shows the screen, and the screen shows every entry that the
      // modules of the app give the role once, one below the other in the
      // order of the role.
      MatrixAppTest(
        '$cli/settings_screen_role',
        appliesTo: (app) => app.hook!.presentRoles.contains(settingsScreenRole),
        generatedFiles: _settingsOf,
        roles: {settingsScreenRole},
      ),
      // The theme mode of the apps with the theme role, whichever module
      // provides it: the root of the app takes the mode that is chosen, and
      // the screen below it gets the light or the dark theme of the
      // provider; a choice is saved under the key of the role; and the next
      // start has the mode that is saved. A test of the app entry role too,
      // whose provider builds the root.
      await themeRoleAppTest(),
      // The entry of the theme mode on the settings screen, in the apps
      // with the theme role and the settings screen role, whichever modules
      // provide them: the screen shows the entry, which shows the mode of
      // the app, also one that other code chose, and a tap on a mode
      // chooses it.
      MatrixAppTest(
        '$cli/theme_setting',
        appliesTo: (app) => app.hook!.presentRoles
            .containsAll(const [themeRole, settingsScreenRole]),
        values: _themeValuesOf,
        generatedFiles: _themeSettingOf,
        roles: {themeRole},
      ),
      // The languages and the texts of the apps with the localization
      // role, whichever module provides it: the root supports the languages
      // of the app, with a delegate of each kind for each of them, the app
      // and its texts follow the language that the user chose, and the
      // choice is saved and restored. Its probe goes through the languages
      // on a device.
      await localizationRoleAppTest(),
      // The setting of the language on the settings screen of the apps
      // with the localization role and the settings screen role, whichever
      // modules provide them: its sheet chooses a language of the app,
      // which the app is then in and remembers, or the languages of the
      // device.
      await languageSettingAppTest(),
    ],
    // Each provider of the router role gets a test of the listeners of the
    // screen, the fixture registry tests the rest of the role, and each
    // provider of the DI role, of the events role, of the preferences
    // role, of the auth role, of the settings screen role, of the theme
    // role and of the localization role gets the tests of its role. Each
    // provider of the app entry role gets the test of the theme role, which
    // checks that its root rebuilds.
    testedRoles: {
      routerRole,
      diRole,
      eventsRole,
      preferencesRole,
      authRole,
      settingsScreenRole,
      themeRole,
      appEntryRole,
      localizationRole,
    },
  );
}

/// The test of the events role that the CLI keeps in its
/// `app_tests/events_role`, for the apps with the role, whichever module
/// provides it, that [among] accepts, or all of them: once the start-up of
/// the app ran, every listener of a type gets each event of that type once,
/// in the order the events were fired; a listener of another type gets none
/// of them, and no error; an event fired before the stream of `on<T>()` is
/// listened to is not in it, even after `on<T>()` returned the stream; and a
/// cancelled subscription gets no more events.
///
/// The test knows only the role and fires events of its own through
/// `createCommunicationService()` of the role. The matrix of the fixtures
/// runs it too, only in the apps with every module, which run other tests
/// already.
Future<MatrixAppTest> eventsRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/events_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(eventsRole) &&
          (among?.call(app) ?? true),
      roles: {eventsRole},
    );

/// The test of the preferences role that the CLI keeps in its
/// `app_tests/preferences_role`, for the apps with the role, whichever
/// module provides it, that [among] accepts, or all of them: once the
/// start-up of the app opened the preferences, a value of each type is read
/// back as it was saved, and as `null` by the reads of the other types,
/// which do not throw; a key that was removed has no value; a write
/// replaces what its key had, a value of another type too; the preferences
/// keep a copy of a list that they are given, and a read returns a copy of
/// it; and the next start, `initPreferences()` again, reads what was saved
/// and nothing that was removed.
///
/// The test knows only the role, and writes keys of its own. Its probe,
/// `probePreferences()` of `integration_test/preferences_role/probe.dart`,
/// runs the checks of one run on a device for the start check, where the
/// platform side of the provider is the real one, and the test runs the
/// probe too. The matrix of the fixtures runs the test only in its apps
/// with every module, which run other tests already.
Future<MatrixAppTest> preferencesRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/preferences_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(preferencesRole) &&
          (among?.call(app) ?? true),
      roles: {preferencesRole},
      startProbe: const MatrixStartProbe(
        'integration_test/preferences_role/probe.dart',
        'probePreferences',
      ),
    );

/// The test of the localization role that the CLI keeps in its
/// `app_tests/localization_role`, for the apps with the role, whichever
/// module provides it, that [among] accepts, or all of them: the root of
/// the app supports the languages of the app and no other, and has, for
/// each of them, a delegate of each kind of localizations that supports
/// it; once the user chose a language, the app is in it, and each text of
/// the app reads in it, or in English when it has no translation into it;
/// while the user chose none, the app and its texts are in the language
/// that the device prefers among those of the app; a choice is saved under
/// [LocalizationRole.localeKey], and removed when the app follows the
/// device again; and the next start, `initPreferences()` again, restores
/// the language that was saved.
///
/// The test knows only the role. The matrix writes the languages and the
/// texts of each app for it, from the data of its localization role, into
/// [languagesAndTextsFile], next to the probe of the test in
/// `integration_test/localization_role/probe.dart`, `probeLanguages()`. On
/// a device, for the start check, the probe checks the texts in the
/// language that it finds, goes through the first languages of the app, at
/// most [languagesProbeLimit], and puts back the choice that it found. The
/// matrix of the fixtures runs the test only in its apps with every module,
/// which run other tests already.
Future<MatrixAppTest> localizationRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/localization_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(localizationRole) &&
          (among?.call(app) ?? true),
      generatedFiles: _languagesAndTextsOf,
      roles: {localizationRole},
      startProbe: const MatrixStartProbe(
        'integration_test/localization_role/probe.dart',
        'probeLanguages',
      ),
    );

/// The path in an app of the languages and the texts of the app, which the
/// matrix writes for the test of the localization role: `appLanguages`, the
/// codes of the languages that the role chose, in their order;
/// `probedLanguages`, the first of them, at most [languagesProbeLimit],
/// which the probe of the role goes through on a device;
/// `savedLanguageKey`, the key of the role in the preferences of the app
/// ([LocalizationRole.localeKey]); and `appTextChecks`, the texts of the
/// app in the order of the role ([LocalizationRole.textsIn]), each with its
/// name, such as `text title of the module settings`, a function that reads
/// it through `context.l10n` of the role, and what it reads in each
/// language of the app: its translation, or its English text.
const languagesAndTextsFile = 'integration_test/localization_role/texts.dart';

/// The most languages that the probe of the test of the localization role
/// goes through on a device, the first of the app: for each, the screen
/// settles once, and the probes of an app share a minute.
const languagesProbeLimit = 10;

/// The file at [languagesAndTextsFile] of [app], an app of the matrix with
/// the localization role, whose package is [packageName].
///
/// It imports the file of the texts of the role only in an app with texts,
/// where it reads them.
Map<String, String> _languagesAndTextsOf(MatrixApp app, String packageName) {
  final input = localizationRole.hookInput(app.hook!);
  final languages = localizationRole.localesIn(input);
  final checks = StringBuffer();
  for (final text in localizationRole.textsIn(input)) {
    checks
      ..writeln('  (')
      ..writeln('    name: ${SmfNames.dartString('$text')},')
      ..writeln('    read: (context) => context.l10n.${text.getter},')
      ..writeln('    expected: {');
    for (final language in languages) {
      final expected = text.text.textIn(language) ?? text.text.en;
      checks.writeln(
        "      '$language': ${SmfNames.dartString(expected)},",
      );
    }
    checks
      ..writeln('    },')
      ..writeln('  ),');
  }
  final texts = LocalizationRole.appTexts.importRef.resolveUri(packageName);
  final imports = [
    "import 'package:flutter/widgets.dart';",
    if (checks.isNotEmpty) "import '$texts';",
  ];
  String codesOf(Iterable<String> languages) =>
      [for (final language in languages) "'$language'"].join(', ');
  final key = SmfNames.dartString(LocalizationRole.localeKey);
  final list = checks.isEmpty
      ? 'const List<AppTextCheck> appTextChecks = [];'
      : 'final List<AppTextCheck> appTextChecks = [\n$checks];';
  return {
    languagesAndTextsFile: '''
// The languages and the texts of the app, and the key of the language that
// the user chose, which the matrix of SMF writes from the data of the
// localization role of the app for the tests of the role, in
// test/localization_role, and their probe.
${imports.join('\n')}

/// The codes of the languages of the app, in their order.
const List<String> appLanguages = [${codesOf(languages)}];

/// The codes of the languages that the probe of the role goes through on a
/// device: the first of the app, at most $languagesProbeLimit.
const List<String> probedLanguages = [${codesOf(languages.take(languagesProbeLimit))}];

/// The key of the preferences of the app under which the app saves the
/// language that the user chose, as the localization role has it.
const String savedLanguageKey = $key;

/// A text of the app: its name, a function that reads it at a context below
/// the root of the app, and what it reads in each language of the app, by
/// the code of the language.
typedef AppTextCheck = ({
  String name,
  String Function(BuildContext context) read,
  Map<String, String> expected,
});

/// The texts of the app, in the order of the localization role.
$list
''',
  };
}

/// The test of the setting of the language, the entry that the template of
/// the localization role gives the settings screen, which the CLI keeps in
/// its `app_tests/language_setting`, for the apps with the localization
/// role and the settings screen role, whichever modules provide them. On
/// the settings screen, the setting shows its title and, as the value of
/// its row, the choice of the user, the languages of the device while the
/// user chose none. A tap opens a sheet over the main navigation of the
/// app, with an option for the languages of the device and one for each
/// language of the app, by its name in that language, or its code, with
/// the chosen one selected and checked. A tap on an option closes the
/// sheet: the app and the texts of the setting are in the language of the
/// option, which is saved under [LocalizationRole.localeKey], and the
/// option of the device removes what was saved. On a small phone with a
/// large text size, the choice is below the title of the setting, and the
/// sheet scrolls. A second file of the test starts the app on a device
/// that prefers the last language of the app: the app and the setting
/// follow the device, the setting names a choice of that same language
/// that code makes, the next start restores the language that was saved,
/// and the sheet has no option but those of the app and of the device.
///
/// The test knows only the two roles. The matrix writes the widget of the
/// entry for it into [languageSettingFile], from the entries of the
/// settings screen role of the app, with the labels of the languages of the
/// app and the texts of the setting in each of them, from the localization
/// role. It opens the settings screen with the helper of the tests of the
/// settings screen role that the CLI keeps, which every app with the
/// settings screen role has too.
Future<MatrixAppTest> languageSettingAppTest() async => MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/language_setting',
      appliesTo: (app) => app.hook!.presentRoles
          .containsAll({localizationRole, settingsScreenRole}),
      generatedFiles: _languageSettingOf,
      roles: {localizationRole},
    );

/// The path in an app of what the matrix writes for the test of the setting
/// of the language: `languageSetting`, the type of the widget of the entry
/// that the template of the localization role gives the settings screen
/// role; `savedLanguageKey`, the key of the role in the preferences of the
/// app ([LocalizationRole.localeKey]); `languageLabels`, what the setting
/// shows for each language of the app, by the code of the language, its
/// name in that language ([LocalizationRole.languageNames]) or its code;
/// and `settingTitles` and `deviceOptions`, the title of the setting and
/// its option of the languages of the device in each language of the app.
const languageSettingFile = 'test/language_setting/setting.dart';

/// The file at [languageSettingFile] of [app], an app of the matrix with
/// the localization role and the settings screen role, whose package is
/// [packageName].
///
/// It imports the file of the entry with the prefix `entry`. The entry is
/// the one of the settings screen role whose widget is in
/// [LocalizationRole.languageSettingFile]. Throws a [StateError] if the
/// role has no such entry, which the template of the localization role
/// gives it in every app with both roles.
Map<String, String> _languageSettingOf(MatrixApp app, String packageName) {
  final languages =
      localizationRole.localesIn(localizationRole.hookInput(app.hook!));
  final entries = [
    for (final entry in settingsScreenRole
        .entriesIn(settingsScreenRole.hookInput(app.hook!)))
      if (entry.file == LocalizationRole.languageSettingFile) entry,
  ];
  if (entries.length != 1) {
    throw StateError(
      'The settings screen of ${app.name} has ${entries.length} entries in '
      '${LocalizationRole.languageSettingFile}, the file of the setting of '
      'the language, rather than one.',
    );
  }
  final widget = entries.single.widget;
  String byLanguage(String Function(String language) text) => [
        for (final language in languages)
          "  '$language': ${SmfNames.dartString(text(language))},\n",
      ].join();
  String Function(String language) textOf(LocalizedText text) =>
      (language) => text.textIn(language) ?? text.en;
  final key = SmfNames.dartString(LocalizationRole.localeKey);
  final labels = byLanguage(
    (language) => LocalizationRole.languageNames[language] ?? language,
  );
  final titles = byLanguage(textOf(LocalizationRole.languageSettingTitle));
  final ofDevice = byLanguage(textOf(LocalizationRole.languageOfDevice));
  return {
    languageSettingFile: '''
// The setting of the language of the app, which the matrix of SMF writes
// from the data of the settings screen role and of the localization role
// of the app for the test of the setting, language_setting_test.dart.
import '${widget.import!.resolveUri(packageName)}' as entry;

/// The type of the widget of the setting, an entry of the settings screen.
const Type languageSetting = ${widget.codeWith('entry')};

/// The key of the preferences of the app under which the app saves the
/// language that the user chose, as the localization role has it.
const String savedLanguageKey = $key;

/// What the setting shows for each language of the app, by the code of the
/// language: its name in that language, or its code.
const Map<String, String> languageLabels = {
$labels};

/// The title of the setting in each language of the app, by the code of
/// the language.
const Map<String, String> settingTitles = {
$titles};

/// The option of the setting with which the app follows the languages of
/// the device, in each language of the app, by the code of the language.
const Map<String, String> deviceOptions = {
$ofDevice};
''',
  };
}

/// The test of the auth role that the CLI keeps in its
/// `app_tests/auth_role`, for the apps with the role, whichever module
/// provides it, in each mode of the role. Each of its four files runs the
/// start-up of the app once, with `bootstrap()`:
/// - the service of the provider keeps the contract of `AuthService`, the
///   same in every mode. When a call completes, the user of the service is
///   its result; signing up creates an account, whose user has the same id
///   each time; a wrong password and an address without an account fail
///   alike; a call that fails leaves whoever is signed in; the user of a
///   call replaces the user who was signed in; each anonymous user has an
///   id of its own, and keeps it with an account; deleting removes the
///   account; a call for the user who is signed in fails when nobody is;
///   and the stream of the changes tells every listener of each change,
///   once the user has changed;
/// - the session of the app does what the mode of the app says: the app is
///   in the mode that the role chose, and without an account nobody uses it
///   in the modes `required` and `guest`, and an anonymous user in the mode
///   `anonymous`, who keeps the id with an account. The session follows a
///   change that none of its calls made, and only an app in the mode
///   `anonymous` signs a user in when the user comes back to it;
/// - the next start, `initAuth()` again, has the user of the device as soon
///   as it is over, after a sign-up, a sign-in and a link, and so has a
///   session of the test that never had a user; a start that finds nobody
///   has nobody, and in the mode `anonymous` a new anonymous user, also
///   after a deletion; and the account of a user whom a start found can be
///   deleted, at the latest once the user has signed in again;
/// - an account that is signed up before the app starts is signed in when
///   the start-up is over, as the mocks of a module with a guard that asks
///   for an account rely on.
///
/// The test knows only the role. The matrix fills in the mode of each app,
/// which the test expects the app to be in: the choice of the role
/// ([AuthRole.modeIn]), which an app that got no value of
/// [AuthRole.modeOption] has too. So the same files hold in an app of every
/// mode, and the test applies to every app with the role. No file expects
/// anything of who is signed in right after the start-up, since the mocks
/// of a module of the app may have signed a user up before it: each test
/// signs out first and uses email addresses of its own. It has no probe for
/// the start check: nobody can sign in on a device.
Future<MatrixAppTest> authRoleAppTest() async => MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/auth_role',
      appliesTo: (app) => app.hook!.presentRoles.contains(authRole),
      values: (app) => {
        'auth_mode': authRole.modeIn(authRole.hookInput(app.hook!)).name,
      },
      roles: {authRole},
    );

/// The test of the theme role that the CLI keeps in its
/// `app_tests/theme_role`, for the apps with the role, whichever module
/// provides it, that [among] accepts, or all of them. Once the app started
/// with `main()`, it follows the device; a choice of a mode with
/// `appThemeMode.choose()` reaches the root `MaterialApp`, which takes the
/// mode, and the screen below it gets the light theme of the provider in
/// the light mode and its dark theme in the dark mode, the same colour
/// schemes that `createLightTheme()` and `createDarkTheme()` return for the
/// context of the root. A choice is saved under the key of the role, as
/// the name of the mode, and the next start, `initPreferences()` again,
/// has the mode whose name the test wrote under that key.
///
/// It is a test of the app entry role too. The root gets the mode from an
/// inherited widget around it, which its arguments read from its context,
/// so the test fails on a provider of the app entry whose root does not
/// rebuild when that widget notifies.
///
/// The test knows only the roles. The matrix fills in the key, which the
/// role publishes ([ThemeRole.modeKey]). It has no probe for the start
/// check: on a device the mode is the same Dart state as in a test, and the
/// platform side of the preferences, which does differ there, has the
/// probes of the preferences role and of its provider. The matrix of the
/// fixtures runs the test only in its apps with every module, which run
/// other tests already.
Future<MatrixAppTest> themeRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/theme_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(themeRole) &&
          (among?.call(app) ?? true),
      values: _themeValuesOf,
      roles: {themeRole, appEntryRole},
    );

/// The values of the files of the tests of the theme role, the same in
/// every app: `mode_key`, the key of the theme mode in the preferences, as
/// the role publishes it.
Map<String, String> _themeValuesOf(MatrixApp app) =>
    const {'mode_key': ThemeRole.modeKey};

/// The path in an app of what the matrix writes for the test of the entry
/// of the theme mode that the CLI keeps in its `app_tests/theme_setting`:
/// `settingsLocation`, the location of the route that the provider of the
/// settings screen role names as the settings screen
/// ([SettingsScreenRole.screenIn]), created as `const` from its class of
/// the navigation of the router role, and `themeModeEntry`, the type of the
/// widget of the entry that the template of the theme role gives the
/// settings screen.
const themeSettingFile = 'test/theme_setting/theme_setting.dart';

/// The file at [themeSettingFile] of [app], an app of the matrix with the
/// theme role and the settings screen role, whose package is [packageName].
///
/// It imports the navigation of the router role without a prefix, and the
/// file of the entry with the prefix `entry`. Throws a [StateError] if the
/// provider of the settings screen role names no route of its own, or if
/// the template of the theme role gives the settings screen no entry or
/// more than one: the test taps the modes of one entry.
Map<String, String> _themeSettingOf(MatrixApp app, String packageName) {
  final input = settingsScreenRole.hookInput(app.hook!);
  final route = _settingsRouteOf(app, input);
  final entries = [
    for (final RoleData(:value, :origin) in input.data)
      if (value is SettingsEntry &&
          origin == const RoleTemplateOrigin(themeRole))
        value,
  ];
  if (entries.length != 1) {
    throw StateError(
      'The template of the $themeRole gives the settings screen of '
      '${app.name} ${entries.length} entries, rather than the entry of the '
      'theme mode alone.',
    );
  }
  final widget = entries.single.widget;
  // The template of the settings screen role rejects an entry whose widget
  // is not in a file of the app, so it has an import.
  final entry = widget.import!.resolveUri(packageName);
  return {
    themeSettingFile: '''
// The settings screen of the app and the entry of the theme mode, which the
// matrix of SMF writes from the data of the settings screen role of the app
// for the test of the entry, theme_setting_test.dart.
import '${_navigationOf(packageName)}';
import '$entry' as entry;

/// The location of the route that shows the settings screen.
const AppLocation settingsLocation = ${route.locationClass}();

/// The type of the widget of the entry of the theme mode on the settings
/// screen.
const Type themeModeEntry = ${widget.codeWith('entry')};
''',
  };
}

/// The test of the router role that the CLI keeps in its
/// `app_tests/router_walk`, for the apps with the role, whichever module
/// provides it, that [among] accepts, or all of them: it starts the app
/// with `main()` and goes to each location of the app that needs no
/// values, at most [routerWalkLimit], with `go()` of the navigator of the
/// role. Each must show the page named after its route on top of the
/// innermost navigator on the screen, and the screen of the route, without
/// an `ErrorWidget` on the screen or an error that Flutter reports.
///
/// In an app with guards of the routes, the walk expects what the role
/// says. For a location that a guard keeps the user from, that is the page
/// and the screen of the target of that guard (`redirectOf()` of the
/// role): every location outside the flow of a gate, and for a guard that
/// stands for a condition, only the locations of the routes that ask for
/// the condition. The target of a gate takes the place of the stack, and
/// that of a guard of a condition opens over the page that the walk is on:
/// either way it is the page on top, which the walk looks at. For any other
/// location in a flow that is over, it is the screen that the app starts on
/// (`flowIsOver()` of the role). So its probe, `probeRoutes()`, which the
/// start check runs on a device, holds whichever guards allow there, where
/// no test can open one, such as a guard that asks for a signed-in user.
/// The test itself first fails on each guard that does not allow, by its
/// name, a guard of a condition too: under `flutter test`, the module of a
/// guard opens it for the tests of the app, in the mocks of its app test
/// ([MatrixAppTest.mocks]), so that the walk reaches every route outside
/// the flows and the tests of the other modules see the screens that they
/// expect. The screens of a flow are then for the tests of its module,
/// since the router shows them only while the guard does not allow.
///
/// The test knows only the role. The matrix writes the locations of each
/// app for it, from the routes and the guards of its router role, into
/// [routerWalkFile], next to the walk in
/// `integration_test/router_walk/walk.dart`. The matrix of the fixtures
/// runs it too, only in the apps with every module, which run other tests
/// already.
Future<MatrixAppTest> routerWalkAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/router_walk',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(routerRole) &&
          (among?.call(app) ?? true),
      generatedFiles: _walkedLocationsOf,
      roles: {routerRole},
      startProbe: const MatrixStartProbe(
        'integration_test/router_walk/walk.dart',
        'probeRoutes',
      ),
    );

/// The path in an app of the locations that the walk of the test of the
/// router role goes to, which the matrix writes: `walkedLocations`, the
/// locations of the routes that need no values, each with the full name of
/// its route ([FacadeRoute.fullName]), the location, created as `const`
/// from its class of the navigation of the role, and the type of the screen
/// that the route shows. They are in the order of the routes of the app
/// ([RouterFacade.routes]).
///
/// The file also says what the router shows for each of them, with two
/// functions that every app gets, so that the walk is the same in an app
/// with guards of the routes ([RouterFacade.guards]) and in one without,
/// which has nothing of what the role generates for them:
/// - `shownFor(walked)`, the full name of the route and the type of the
///   screen that the router shows when it is asked to show `walked`, a
///   `ShownScreen`. In an app without guards, those are the ones of
///   `walked`. In an app with guards, they are the ones of the target of
///   the guard that keeps the user from `walked`, as `redirectOf()` of the
///   role says; else `startOfApp` for a location in a flow that is over,
///   as `flowIsOver()` of the role says; else the ones of `walked`. The
///   targets are in `guardTargets`, in the order of the guards, those of
///   the gates first and then those of the guards that stand for a
///   condition, each once, also those that are not among the first
///   [routerWalkLimit] locations.
///   `startOfApp` is the screen that the app starts on: that of the route
///   that the role chose ([RouterRole.startIn]), with the name of that
///   route, or the fallback start screen of the app entry role
///   ([AppEntryRole.fallbackStartScreen]) without the name of a route, in
///   an app that no route can start;
/// - `closedGuards()`, the full names of the guards that do not allow, in
///   the order of `routeGuards` of the role, a guard whose condition does
///   not hold among them; none in an app without guards.
const routerWalkFile = 'integration_test/router_walk/locations.dart';

/// The most locations that the walk of the test of the router role goes
/// to, the first of [routerWalkFile].
const routerWalkLimit = 20;

/// The file at [routerWalkFile] of [app], an app of the matrix with the
/// router role, whose package is [packageName].
///
/// It imports the navigation of the role without a prefix, since the names
/// of its classes differ from those of the file, and the file of every
/// screen once, with a prefix of its own, `screen0`, `screen1`, ..., so
/// that no name clashes. In an app with guards it imports the file of the
/// role that has them too, without a prefix either.
Map<String, String> _walkedLocationsOf(MatrixApp app, String packageName) {
  final input = routerRole.hookInput(app.hook!);
  final facade = routerRole.facadeOf(input);
  final routes = [
    for (final route in facade.routes)
      if (!route.hasRequiredParams) route,
  ].take(routerWalkLimit);
  final screens = <String, String>{};
  String prefixOf(ImportRef import) => screens.putIfAbsent(
        import.resolveUri(packageName),
        () => 'screen${screens.length}',
      );
  String walked(FacadeRoute route) {
    final screen = route.route.screen;
    return '  (\n'
        '    route: ${SmfNames.dartString(route.fullName)},\n'
        '    location: ${route.locationClass}(),\n'
        '    screen: ${prefixOf(screen.import)}.${screen.className},\n'
        '  ),\n';
  }

  final locations = routes.map(walked).join();
  // Each target once: two guards may show the same one, such as a gate and
  // a guard that stands for a condition.
  final targets = {for (final guard in facade.guards) guard.target};
  const fallback = AppEntryRole.fallbackStartScreen;
  final guards = targets.isEmpty
      ? _withoutGuards
      : _withGuards(
          targets: targets.map(walked).join(),
          start: switch (routerRole.startIn(input)) {
            final start? => (
                route: SmfNames.dartString(start.fullName),
                screen: '${prefixOf(start.route.screen.import)}.'
                    '${start.route.screen.className}',
              ),
            null => (
                route: 'null',
                screen: '${prefixOf(fallback.importRef)}.${fallback.name}',
              ),
          },
        );
  String ofRole(String file) =>
      ImportRef.app(file.substring('lib/'.length)).resolveUri(packageName);
  final imports = [
    "import '${ofRole(RouterRole.navigationFile)}';",
    if (targets.isNotEmpty) "import '${ofRole(RouterRole.appRouterFile)}';",
    for (final MapEntry(key: uri, value: prefix) in screens.entries)
      "import '$uri' as $prefix;",
  ]..sort();
  return {
    routerWalkFile: '''
// The locations of the app that need no values, at most $routerWalkLimit,
// and what the router shows for each, which the matrix of SMF writes from
// the data of the router role of the app for the walk of its routes,
// walk.dart.
${imports.join('\n')}

/// A location of the app that needs no values: the full name of its route,
/// the location, and the type of the screen that the route shows.
typedef WalkedLocation = ({String route, AppLocation location, Type screen});

/// What the router shows for a location: the full name of the route of the
/// page on top, or `null` for a screen that is no route of a module, and
/// the type of the screen.
typedef ShownScreen = ({String? route, Type screen});

/// The locations of the app that need no values, in the order of the
/// routes of the app.
const List<WalkedLocation> walkedLocations = [
$locations];
$guards''',
  };
}

/// What [routerWalkFile] says of the guards in an app without guards, which
/// has none of `redirectOf()`, `flowIsOver()` and `routeGuards` of the
/// router role.
const _withoutGuards = '''

/// What the router shows when it is asked to show [walked]: the page and
/// the screen of [walked] itself, since no module of the app has a guard of
/// the routes.
ShownScreen shownFor(WalkedLocation walked) =>
    (route: walked.route, screen: walked.screen);

/// The full names of the guards of the routes that do not allow: none,
/// since no module of the app has a guard.
List<String> closedGuards() => const [];
''';

/// What [routerWalkFile] says of the guards in an app with guards, whose
/// targets are [targets], each as a location of the walk, and which starts
/// on the screen [start]: the code of the full name of its route, or of
/// `null` for the fallback start screen, and the code of the type of the
/// screen.
String _withGuards({
  required String targets,
  required ({String route, String screen}) start,
}) =>
    '''

/// The targets of the guards of the routes of the app, in the order of the
/// guards: the location that the router shows while a guard does not
/// allow.
const List<WalkedLocation> guardTargets = [
$targets];

/// The screen that the app starts on, which the router shows in place of a
/// location in a flow that is over: that of the route that starts the app,
/// or the fallback start screen of the app entry, which is no route, in an
/// app that no route can start.
const ShownScreen startOfApp = (
  route: ${start.route},
  screen: ${start.screen},
);

/// What the router shows on top when it is asked to show [walked], as the
/// router role says: the target of the guard that keeps the user from it
/// (redirectOf()), in place of the stack for a gate, and over the page that
/// the user is on for a guard of a condition that [walked] asks for; or
/// else the screen that the app starts on if the flow of [walked] is over
/// (flowIsOver()), or else the page and the screen of [walked] itself.
ShownScreen shownFor(WalkedLocation walked) {
  final target = ${RouterRole.redirectOf}(walked.route);
  if (target != null) {
    final shown = guardTargets.firstWhere(
      (shown) => shown.route == target.routeName,
    );
    return (route: shown.route, screen: shown.screen);
  }
  if (${RouterRole.flowIsOver}(walked.route)) return startOfApp;
  return (route: walked.route, screen: walked.screen);
}

/// The full names of the guards of the routes that do not allow, in the
/// order of the guards.
List<String> closedGuards() => [
  for (final guard in ${RouterRole.routeGuards})
    if (!guard.allows.value) guard.name,
];
''';

/// The path in an app of what the matrix writes for the tests of the
/// settings screen role that the CLI keeps in its
/// `app_tests/settings_screen_role`: `settingsLocation`, the location of the
/// route that the provider of the role names as the settings screen
/// ([SettingsScreenRole.screenIn]), created as `const` from its class of
/// the navigation of the router role, `settingsScreen`, the type of the
/// screen that the route shows, and `settingsEntries`, the types of the
/// widgets of the entries of the screen, in the order of the role
/// ([SettingsScreenRole.entriesIn]).
const settingsScreenFile = 'test/settings_screen_role/settings.dart';

/// The file at [settingsScreenFile] of [app], an app of the matrix with
/// the settings screen role, whose package is [packageName].
///
/// It imports the navigation of the router role without a prefix, since the
/// names of its classes differ from those of the file, the file of the
/// screen with the prefix `screen`, and the file of every entry once, with a
/// prefix of its own, `entry0`, `entry1`, ..., so that no name clashes.
/// Throws a [StateError] if the provider of the role names no route of its
/// own, which the rules of the role report in an app of the matrix.
Map<String, String> _settingsOf(MatrixApp app, String packageName) {
  final input = settingsScreenRole.hookInput(app.hook!);
  final route = _settingsRouteOf(app, input);
  final screen = route.route.screen;
  final prefixes = {screen.import.resolveUri(packageName): 'screen'};
  final entries = StringBuffer();
  for (final entry in settingsScreenRole.entriesIn(input)) {
    final widget = entry.widget;
    // The template of the role rejects an entry whose widget is not in a
    // file of the app, so each has an import.
    final prefix = prefixes.putIfAbsent(
      widget.import!.resolveUri(packageName),
      () => 'entry${prefixes.length - 1}',
    );
    entries.writeln('  ${widget.codeWith(prefix)},');
  }
  final imports = [
    "import '${_navigationOf(packageName)}';",
    for (final MapEntry(key: uri, value: prefix) in prefixes.entries)
      "import '$uri' as $prefix;",
  ]..sort();
  return {
    settingsScreenFile: '''
// The settings screen of the app and its entries, which the matrix of SMF
// writes from the data of the settings screen role of the app for the
// tests of the role, settings_screen_test.dart and
// settings_entries_test.dart.
${imports.join('\n')}

/// The location of the route that shows the settings screen.
const AppLocation settingsLocation = ${route.locationClass}();

/// The type of the settings screen.
const Type settingsScreen = screen.${screen.className};

/// The types of the widgets of the entries of the settings screen, in the
/// order in which the screen shows them.
const List<Type> settingsEntries = [
$entries];
''',
  };
}

/// The route that the provider of the settings screen role names as the
/// settings screen in [input], the input of the role in [app]. Throws a
/// [StateError] if it names no route of its own, which the rules of the
/// role report in an app of the matrix.
FacadeRoute _settingsRouteOf(
  MatrixApp app,
  RoleHookInput<SettingsData> input,
) {
  final route = settingsScreenRole.screenIn(input);
  if (route == null) {
    throw StateError(
      'No module of ${app.name} names a route of its own as the settings '
      'screen.',
    );
  }
  return route;
}

/// The URI of the navigation of the router role in the app whose package
/// is [packageName], which has the classes of the locations of the app.
String _navigationOf(String packageName) => ImportRef.app(
      RouterRole.navigationFile.substring('lib/'.length),
    ).resolveUri(packageName);

/// The path in an app of what the matrix writes for the test of the
/// language of the settings screen that the settings module keeps in its
/// `app_tests/settings`: `appLanguages`, the codes of the languages of the
/// app ([LocalizationRole.localesIn]), and `chooseLanguage()`, which
/// chooses one of them for the app as its user does and completes once the
/// app saved the choice.
const settingsLanguagesFile = 'test/settings_languages.dart';

/// The file at [settingsLanguagesFile] of [app], an app of the matrix whose
/// package is [packageName].
///
/// In an app with the localization role, the languages are those of the
/// role, and choosing one goes through `appLocale` of the file of the role,
/// which the root of the app follows and which saves the choice in the
/// preferences of the app. An app without the role is in English, and has
/// no language to choose.
Map<String, String> _settingsLanguagesOf(MatrixApp app, String packageName) {
  const about = '''
// The languages of the app, which the matrix of SMF writes from the
// localization role of the app for the test of the language of the
// settings screen, settings_language_test.dart.''';
  final hook = app.hook!;
  if (!hook.presentRoles.contains(localizationRole)) {
    return {
      settingsLanguagesFile: '''
$about

/// The codes of the languages of the app: it has no texts in other
/// languages, so it is in English.
const List<String> appLanguages = ['en'];

/// The app has one language, so there is none to choose.
Future<void> chooseLanguage(String language) async {}
''',
    };
  }
  final languages = [
    for (final language
        in localizationRole.localesIn(localizationRole.hookInput(hook)))
      SmfNames.dartString(language),
  ];
  final appLocale = ImportRef.app(
    LocalizationRole.appLocaleFile.substring('lib/'.length),
  ).resolveUri(packageName);
  return {
    settingsLanguagesFile: '''
$about
import 'dart:ui';

import '$appLocale';

/// The codes of the languages of the app, the first of which the app is in
/// when the device asks for none of them.
const List<String> appLanguages = [${languages.join(', ')}];

/// Chooses [language], one of [appLanguages], as the language of the app,
/// as its user does. The app saves the choice in its preferences, and the
/// future completes once it did.
Future<void> chooseLanguage(String language) =>
    appLocale.choose(Locale(language));
''',
  };
}

/// The path in an app of what the matrix writes for the tests of the home
/// module: `homeTexts`, the texts of the screen of the module
/// ([HomeModule.texts]), each by its name, in each language of the app, by
/// the code of the language. The languages are those of the localization
/// role of the app ([LocalizationRole.localesIn]), in its order, and English
/// alone in an app without the role, whose screen has the English texts.
const homeTextsFile = 'test/home/texts.dart';

/// The file at [homeTextsFile] of [app], an app of the matrix.
///
/// A text of the module without a translation into a language of the app
/// is the English one there, as the localization role says of the texts of
/// an app.
Map<String, String> _homeTextsFileOf(MatrixApp app) {
  final texts = _textsByLanguageOf(app, HomeModule.texts);
  return {
    homeTextsFile: '''
// The texts of the start screen of the home module in each language of the
// app, which the matrix of SMF writes from the texts of the module and the
// languages of the localization role of the app for the tests of the
// module, in test/home.

/// The texts of the screen by the code of each language of the app, the
/// first of which the app uses when the device asks for none of them: each
/// text by its name in the module. An app without the localization role
/// has the English texts alone.
const Map<String, Map<String, String>> homeTexts = {
$texts};
''',
  };
}

/// The path in an app of what the matrix writes for the tests of the group
/// and of the back button of the settings screen that the settings module
/// keeps in its `app_tests/settings`: `settingsEntryCount`, how many
/// entries the screen has, and `settingsInMainNavigation`, whether the
/// screen is a destination of the main navigation of the app.
const settingsOfAppFile = 'test/settings_of_app.dart';

/// The file at [settingsOfAppFile] of [app], an app of the matrix with the
/// settings screen role.
///
/// The entries are those of the role ([SettingsScreenRole.entriesIn]). An
/// app without any has the note of the module for its developer on the
/// screen. The screen is a destination when the app has the layout role and
/// the route of the settings screen ([SettingsScreenRole.screenIn]) is one
/// of the destinations of that role ([LayoutRole.destinationsIn]). The
/// router role refuses to push a location of the main navigation over it,
/// so the test of the back button pushes the screen only where it is no
/// destination.
Map<String, String> _settingsOfAppOf(MatrixApp app) {
  final hook = app.hook!;
  final input = settingsScreenRole.hookInput(hook);
  final screen = settingsScreenRole.screenIn(input);
  final destination = hook.presentRoles.contains(layoutRole) &&
      layoutRole
          .destinationsIn(layoutRole.hookInput(hook))
          .any((route) => route.fullName == screen?.fullName);
  return {
    settingsOfAppFile: '''
// What the settings screen has in the app and where it is, which the matrix
// of SMF writes from the settings screen role and the layout role of the
// app for the tests of the settings module, settings_group_test.dart and
// settings_back_test.dart.

/// How many entries the settings screen has: the settings of the modules
/// of the app. Without any, the screen has a note for the developer of the
/// app.
const int settingsEntryCount = ${settingsScreenRole.entriesIn(input).length};

/// Whether the settings screen is a destination of the main navigation of
/// the app. Code cannot push such a screen on top of another one.
const bool settingsInMainNavigation = $destination;
''',
  };
}

/// The test of the DI role that the CLI keeps in its `app_tests/di_role`,
/// for the apps with the role, whichever module provides it, whose modules
/// register services, at least one of each of [lifetimes]: once the
/// start-up of the app ran, every service resolves, a singleton and a lazy
/// singleton to one instance; `resetDependencies()` removes them all, and
/// `registerDependencies()` registers them again.
///
/// The test knows only the role. The matrix writes the services of each
/// app for it, from the registrations of its DI role, into
/// [registeredServicesFile]. The matrix of the fixtures runs it too, in the
/// apps whose services have every lifetime. Its probe, `probeServices()` of
/// `integration_test/di_role/probe.dart`, resolves each service on a device
/// for the start check, a singleton and a lazy singleton twice, without
/// calling it or resetting the container.
Future<MatrixAppTest> diRoleAppTest({
  Set<DiLifetime> lifetimes = const {},
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/di_role',
      appliesTo: (app) {
        if (!app.hook!.presentRoles.contains(diRole)) return false;
        final registered = {
          for (final registration in _servicesOf(app)) registration.lifetime,
        };
        return registered.isNotEmpty && registered.containsAll(lifetimes);
      },
      generatedFiles: _registeredServicesOf,
      roles: {diRole},
      startProbe: const MatrixStartProbe(
        'integration_test/di_role/probe.dart',
        'probeServices',
      ),
    );

/// The path in an app of the services that its modules register, which the
/// matrix writes for the test of the DI role: `registeredServices`, the
/// services in the order of their registration ([DiGraph.ordered]), each
/// with its name, such as `FixtureZone "utc"`, its lifetime, such as
/// `lazySingleton`, and a function that resolves it with `resolve()` of the
/// service locator of the role, by its type and its instance name.
const registeredServicesFile =
    'integration_test/di_role/registered_services.dart';

/// The file at [registeredServicesFile] of [app], an app of the matrix with
/// the DI role, whose package is [packageName].
///
/// It imports the service locator with the prefix `locator`, and the file
/// of every type of a service once, with a prefix of its own, `di0`, `di1`,
/// ..., so that no name clashes.
Map<String, String> _registeredServicesOf(
  MatrixApp app,
  String packageName,
) {
  final locator = ImportRef.app(
    DiRole.serviceLocatorFile.substring('lib/'.length),
  ).resolveUri(packageName);
  final prefixes = <String, String>{locator: 'locator'};
  String typeOf(TypeRef type) => switch (type.import) {
        null => type.name,
        final import => type.codeWith(
            prefixes.putIfAbsent(
              import.resolveUri(packageName),
              () => 'di${prefixes.length - 1}',
            ),
          ),
      };
  final services = StringBuffer();
  for (final registration in _servicesOf(app)) {
    final name = switch (registration.instanceName) {
      null => '',
      final name => 'instanceName: ${SmfNames.dartString(name)}',
    };
    services
      ..writeln('  (')
      ..writeln('    name: ${SmfNames.dartString('${registration.key}')},')
      ..writeln("    lifetime: '${registration.lifetime.name}',")
      ..writeln(
        '    resolve: () => '
        'locator.resolve<${typeOf(registration.type)}>($name),',
      )
      ..writeln('  ),');
  }
  final imports = [
    for (final MapEntry(key: uri, value: prefix) in prefixes.entries)
      "import '$uri' as $prefix;",
  ]..sort();
  return {
    registeredServicesFile: '''
// The services that the modules of the app register in its DI container,
// which the matrix of SMF writes from the data of the DI role of the app
// for the test of the role, di_role_test.dart.
${imports.join('\n')}

/// A service that the modules of the app register: its name, its lifetime,
/// and a function that resolves it with resolve() of the service locator.
typedef RegisteredService = ({
  String name,
  String lifetime,
  Object Function() resolve,
});

/// The services that the modules of the app register, in the order of
/// their registration.
final List<RegisteredService> registeredServices = [
$services];
''',
  };
}

/// The registrations of the DI role of [app], in the order of their
/// registration.
List<DiRegistration> _servicesOf(MatrixApp app) =>
    diRole.graphOf(diRole.hookInput(app.hook!)).ordered;

/// The path in an app of what the matrix writes for the tests of the
/// onboarding module: `startScreen`, the type of the screen that the app
/// starts on, which the app shows once the onboarding is finished.
const onboardingStartScreenFile = 'test/onboarding/start_screen.dart';

/// The file at [onboardingStartScreenFile] of [app], an app of the matrix
/// with the router role, whose package is [packageName]: the screen of the
/// route that the router role chose to start the app on, or the fallback
/// start screen of the app entry role when no route of its modules can
/// start it.
///
/// It imports the file of the screen with the prefix `screen`.
Map<String, String> _startScreenFileOf(MatrixApp app, String packageName) {
  final (import, screen) = _startScreenClassOf(app);
  return {
    onboardingStartScreenFile: '''
// The screen that the app starts on, which the matrix of SMF writes from
// the data of the router role of the app for the tests of the onboarding
// module, first_launch_test.dart and later_launch_test.dart.
import '${import.resolveUri(packageName)}' as screen;

/// The type of the screen that the app starts on: that of the route that
/// the router role chose, or the fallback start screen of the app entry
/// role in an app that no route can start.
const Type startScreen = screen.$screen;
''',
  };
}

/// The path in an app of what the matrix writes for the test of the first
/// launch of the onboarding module: `onboardingTexts`, the texts of the
/// module ([OnboardingModule.texts]), each by its name, in each language of
/// the app, by the code of the language. The languages are those of the
/// localization role of the app ([LocalizationRole.localesIn]), in its
/// order, and English alone in an app without the role, whose onboarding
/// has the English texts.
const onboardingTextsFile = 'test/onboarding/texts.dart';

/// The file at [onboardingTextsFile] of [app], an app of the matrix.
///
/// A text of the module without a translation into a language of the app
/// is the English one there, as the localization role says of the texts of
/// an app.
Map<String, String> _onboardingTextsFileOf(MatrixApp app) {
  final texts = _textsByLanguageOf(app, OnboardingModule.texts);
  return {
    onboardingTextsFile: '''
// The texts of the onboarding in each language of the app, which the
// matrix of SMF writes from the texts of the onboarding module and the
// languages of the localization role of the app for the test of the
// module, first_launch_test.dart.

/// The texts of the onboarding by the code of each language of the app,
/// the first of which the app uses when the device asks for none of them:
/// each text by its name in the module. An app without the localization
/// role has the English texts alone.
const Map<String, Map<String, String>> onboardingTexts = {
$texts};
''',
  };
}

/// The path in an app of what the matrix writes for the test of the
/// language of the messages of Firebase Authentication that the
/// firebase_auth module keeps in its `app_tests/firebase_auth`:
/// `messageLanguages`, the codes of the languages in which the app asks
/// Firebase for its messages, those of the app
/// ([LocalizationRole.localesIn]), and `chooseLanguage()`, which chooses
/// one of them for the app as its user does, or lets the app follow the
/// device again.
const messageLanguagesFile = 'test/firebase_auth/languages.dart';

/// The file at [messageLanguagesFile] of [app], an app of the matrix whose
/// package is [packageName].
///
/// In an app with the localization role, the languages are those of the
/// role, and choosing one goes through `appLocale` of the file of the role.
/// An app without the role asks Firebase for no language, so the file has
/// none, and nothing to choose.
Map<String, String> _messageLanguagesOf(MatrixApp app, String packageName) {
  const about = '''
// The languages in which the app asks Firebase Authentication for its
// messages, which the matrix of SMF writes from the localization role of
// the app for the test of the calls of the firebase_auth module,
// calls_test.dart.''';
  final hook = app.hook!;
  if (!hook.presentRoles.contains(localizationRole)) {
    return {
      messageLanguagesFile: '''
$about

/// The codes of the languages in which the app asks for the messages: the
/// app has no languages of its own, so it asks for none, and Firebase sends
/// each message in the language of its template.
const List<String> messageLanguages = [];

/// The app has no language to choose.
Future<void> chooseLanguage(String? language) async {}
''',
    };
  }
  final languages = [
    for (final language
        in localizationRole.localesIn(localizationRole.hookInput(hook)))
      SmfNames.dartString(language),
  ];
  final appLocale = ImportRef.app(
    LocalizationRole.appLocaleFile.substring('lib/'.length),
  ).resolveUri(packageName);
  return {
    messageLanguagesFile: '''
$about
import 'dart:ui';

import '$appLocale';

/// The codes of the languages in which the app asks for the messages:
/// those of the app, the first of which the app is in when the device asks
/// for none of them.
const List<String> messageLanguages = [${languages.join(', ')}];

/// Chooses [language], one of [messageLanguages], as the language of the
/// app, as its user does, or with `null` lets the app follow the languages
/// of the device again.
Future<void> chooseLanguage(String? language) =>
    appLocale.choose(language == null ? null : Locale(language));
''',
  };
}

/// The path in an app of what the matrix writes for the tests of the
/// sign-in module: `startScreen`, the type of the screen that the app
/// starts on, which the app shows once its user may see it, and
/// `signInTexts`, the texts of the module ([SignInModule.texts]), each by
/// its name, in each language of the app, by the code of the language. The
/// languages are those of the localization role of the app
/// ([LocalizationRole.localesIn]), in its order, and English alone in an
/// app without the role, whose screens have the English texts.
const signInOfAppFile = 'test/sign_in/of_app.dart';

/// The file at [signInOfAppFile] of [app], an app of the matrix with the
/// router role, whose package is [packageName].
///
/// The screen is that of the route that the router role chose to start the
/// app on, or the fallback start screen of the app entry role when no route
/// of its modules can start it; the file imports its file with the prefix
/// `screen`. A text of the module without a translation into a language of
/// the app is the English one there, as the localization role says of the
/// texts of an app.
Map<String, String> _signInOfAppOf(MatrixApp app, String packageName) {
  final (import, screen) = _startScreenClassOf(app);
  final texts = _textsByLanguageOf(app, SignInModule.texts);
  return {
    signInOfAppFile: '''
// What the tests of the sign-in module, in test/sign_in, need to know of
// the app, which the matrix of SMF writes from the data of the router role
// of the app, from the texts of the module and from the languages of the
// localization role of the app.
import '${import.resolveUri(packageName)}' as screen;

/// The type of the screen that the app starts on: that of the route that
/// the router role chose, or the fallback start screen of the app entry
/// role in an app that no route can start.
const Type startScreen = screen.$screen;

/// The texts of the screens of sign-in by the code of each language of the
/// app, the first of which the app uses when the device asks for none of
/// them: each text by its name in the module. An app without the
/// localization role has the English texts alone.
const Map<String, Map<String, String>> signInTexts = {
$texts};
''',
  };
}

/// The file and the name of the class of the screen that [app], an app of
/// the matrix with the router role, starts on: the screen of the route
/// that the role chose to start the app on, or the fallback start screen of
/// the app entry role when no route of its modules can start it.
(ImportRef, String) _startScreenClassOf(MatrixApp app) {
  final start = routerRole.startIn(routerRole.hookInput(app.hook!))?.route;
  return switch (start?.screen) {
    final screen? => (screen.import, screen.className),
    null => (
        AppEntryRole.fallbackStartScreen.importRef,
        AppEntryRole.fallbackStartScreen.name,
      ),
  };
}

/// The entries of a Dart map of the [texts] of a module in each language
/// of [app], an app of the matrix: for the code of each language, each
/// text by its name. The languages are those of the localization role of
/// the app, in its order, or English alone in an app without the role. A
/// text without a translation into a language is the English one there.
String _textsByLanguageOf(MatrixApp app, TextsData texts) {
  final hook = app.hook!;
  final languages = hook.presentRoles.contains(localizationRole)
      ? localizationRole.localesIn(localizationRole.hookInput(hook))
      : const ['en'];
  final entries = StringBuffer();
  for (final language in languages) {
    entries.writeln('  ${SmfNames.dartString(language)}: {');
    for (final text in texts.texts) {
      final name = SmfNames.dartString(text.name);
      final shown = SmfNames.dartString(text.textIn(language) ?? text.en);
      entries.writeln('    $name: $shown,');
    }
    entries.writeln('  },');
  }
  return '$entries';
}

/// The name under which the listener of Firebase Analytics logs the
/// screen that [app] starts on: the full name of the route that the router
/// role chose for it, such as `home.home`, or `/` for the fallback start
/// screen of its app entry, when no route of its modules can start it.
String _startScreenOf(MatrixApp app) =>
    routerRole.startIn(routerRole.hookInput(app.hook!))?.fullName ?? '/';

/// Whether an app of the matrix has the module [id].
bool Function(MatrixApp app) _has(ModuleId id) =>
    (app) => app.modules.contains(id);
