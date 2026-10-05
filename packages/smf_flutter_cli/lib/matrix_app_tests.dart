/// The tests that the matrix of CI adds to the apps of the modules of
/// `smf create`, for `tool/matrix.dart` and for the app of several
/// providers of the fixture registry. No library of the binary imports it.
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';

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
  final settings = await appTestsDirectoryOf('smf_settings');
  final sharedPreferences = await appTestsDirectoryOf(
    'smf_shared_preferences',
  );
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
      // The last row of the settings screen of the module, which tells
      // what the app is: it opens the about dialog of Flutter with the name
      // of the app, and the dialog the licenses of its packages.
      MatrixAppTest('$settings/settings', appliesTo: _has(SettingsModule.id)),
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
      // The services of the apps whose modules register some in the DI
      // container, whichever module provides it.
      await diRoleAppTest(),
      // The events of the apps with the events role, whichever module
      // provides it.
      await eventsRoleAppTest(),
      // The preferences of the apps with the preferences role, whichever
      // module provides it.
      await preferencesRoleAppTest(),
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
      // The languages and the texts of the apps with the localization
      // role, whichever module provides it: the root supports the languages
      // of the app, with a delegate of each kind for each of them, the app
      // and its texts follow the language that the user chose, and the
      // choice is saved and restored. Its probe goes through the languages
      // on a device.
      await localizationRoleAppTest(),
      // The setting of the language on the settings screen of the apps
      // with the localization role and the settings screen role, whichever
      // modules provide them: its dialog chooses a language of the app,
      // which the app is then in and remembers, or the languages of the
      // device.
      await languageSettingAppTest(),
    ],
    // Each provider of the router role gets a test of the listeners of the
    // screen, the fixture registry tests the rest of the role, and each
    // provider of the DI role, of the events role, of the preferences
    // role, of the settings screen role and of the localization role gets
    // the tests of its role.
    testedRoles: {
      routerRole,
      diRole,
      eventsRole,
      preferencesRole,
      settingsScreenRole,
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
/// the settings screen, the setting shows its title and the choice of the
/// user, the languages of the device while the user chose none. A tap opens
/// a dialog with an option for the languages of the device and one for each
/// language of the app, by its name in that language, or its code, with
/// the chosen one selected and checked. A tap on an option closes the
/// dialog: the app and the texts of the setting are in the language of the
/// option, which is saved under [LocalizationRole.localeKey], and the
/// option of the device removes what was saved.
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
/// says: for a location that a guard keeps the user from, the page and the
/// screen of the target of that guard (`redirectOf()` of the role). So its
/// probe, `probeRoutes()`, which the start check runs on a device, holds
/// whichever guards allow there, where no test can open one, such as a
/// guard that asks for a signed-in user. The test itself first fails on
/// each guard that does not allow, by its name: under `flutter test`, the
/// module of a guard opens it for the tests of the app, in the mocks of its
/// app test ([MatrixAppTest.mocks]), so that the walk reaches every route
/// and the tests of the other modules see the screens that they expect.
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
/// locations of the routes that need no values, in the order of the routes
/// of the app ([RouterFacade.routes]), each with the full name of its route
/// ([FacadeRoute.fullName]), the location, created as `const` from its
/// class of the navigation of the role, and the type of the screen that the
/// route shows.
///
/// The file also says what the guards of the routes of the app
/// ([RouterFacade.guards]) do to the walk, with two functions that every
/// app gets, so that the walk is the same in an app with guards and in one
/// without, which has nothing of what the role generates for them:
/// - `shownFor(walked)`, the location that the router shows when it is
///   asked to show `walked`: `walked` itself, or the target of the guard
///   that keeps the user from it, as `redirectOf()` of the role says. In an
///   app without guards it returns `walked`. The targets are in
///   `guardTargets`, in the order of the guards, also those that are not
///   among the first [routerWalkLimit] locations;
/// - `closedGuards()`, the full names of the guards that do not allow, in
///   the order of `routeGuards` of the role; none in an app without guards.
const routerWalkFile = 'integration_test/router_walk/locations.dart';

/// The most locations that the walk of the test of the router role goes
/// to, the first of the app.
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
  final facade = routerRole.facadeOf(routerRole.hookInput(app.hook!));
  final routes = [
    for (final route in facade.routes)
      if (!route.hasRequiredParams) route,
  ].take(routerWalkLimit);
  final screens = <String, String>{};
  String walked(FacadeRoute route) {
    final screen = route.route.screen;
    final prefix = screens.putIfAbsent(
      screen.import.resolveUri(packageName),
      () => 'screen${screens.length}',
    );
    return '  (\n'
        '    route: ${SmfNames.dartString(route.fullName)},\n'
        '    location: ${route.locationClass}(),\n'
        '    screen: $prefix.${screen.className},\n'
        '  ),\n';
  }

  final locations = routes.map(walked).join();
  // Each target once: two guards may show the same one.
  final targets = {for (final guard in facade.guards) guard.target};
  final guards = targets.isEmpty
      ? _withoutGuards
      : _withGuards(targets.map(walked).join());
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
// and what the guards of its routes show in their place, which the matrix
// of SMF writes from the data of the router role of the app for the walk of
// its routes, walk.dart.
${imports.join('\n')}

/// A location of the app that needs no values: the full name of its route,
/// the location, and the type of the screen that the route shows.
typedef WalkedLocation = ({String route, AppLocation location, Type screen});

/// The locations of the app that need no values, in the order of the
/// routes of the app.
const List<WalkedLocation> walkedLocations = [
$locations];
$guards''',
  };
}

/// What [routerWalkFile] says of the guards in an app without guards, which
/// has neither `redirectOf()` nor `routeGuards` of the router role.
const _withoutGuards = '''

/// The location that the router shows when it is asked to show [walked]:
/// [walked] itself, since no module of the app has a guard of the routes.
WalkedLocation shownFor(WalkedLocation walked) => walked;

/// The full names of the guards of the routes that do not allow: none,
/// since no module of the app has a guard.
List<String> closedGuards() => const [];
''';

/// What [routerWalkFile] says of the guards in an app with guards, whose
/// targets are [targets], each as a location of the walk.
String _withGuards(String targets) => '''

/// The targets of the guards of the routes of the app, in the order of the
/// guards: the location that the router shows while a guard does not
/// allow.
const List<WalkedLocation> guardTargets = [
$targets];

/// The location that the router shows when it is asked to show [walked]:
/// [walked] itself, or the target of the guard that keeps the user from it,
/// as redirectOf() of the router role says.
WalkedLocation shownFor(WalkedLocation walked) {
  final target = ${RouterRole.redirectOf}(walked.route);
  if (target == null) return walked;
  return guardTargets.firstWhere(
    (shown) => shown.route == target.routeName,
  );
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
  final route = settingsScreenRole.screenIn(input);
  if (route == null) {
    throw StateError(
      'No module of ${app.name} names a route of its own as the settings '
      'screen.',
    );
  }
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
  final navigation = ImportRef.app(
    RouterRole.navigationFile.substring('lib/'.length),
  ).resolveUri(packageName);
  final imports = [
    "import '$navigation';",
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

/// The name under which the listener of Firebase Analytics logs the
/// screen that [app] starts on: the full name of the route that the router
/// role chose for it, such as `home.home`, or `/` for the fallback start
/// screen of its app entry, when no route of its modules can start it.
String _startScreenOf(MatrixApp app) =>
    routerRole.startIn(routerRole.hookInput(app.hook!))?.fullName ?? '/';

/// Whether an app of the matrix has the module [id].
bool Function(MatrixApp app) _has(ModuleId id) =>
    (app) => app.modules.contains(id);
