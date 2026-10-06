/// The tests that the matrix of CI adds to the apps of the fixture modules,
/// which this package keeps in its `app_tests`, and the roles whose
/// contract they check with every provider; `tool/matrix.dart` runs them.
/// And those of the app of several providers, which
/// `tool/several_providers_matrix.dart` runs.
library;

import 'package:fake_infra/fake_infra.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/matrix_app_tests.dart';

/// The tests of the apps of the fixture modules, and the roles whose
/// contract they check with every provider: the router role and the layout
/// role, whose providers call the listeners of the screen, the DI role, the
/// events role, the preferences role, the localization role, the theme
/// role, and the app entry role, whose provider builds the root that
/// follows the theme mode.
///
/// They select the apps with a provider of a role by the roles of the app,
/// whichever module provides it, and name the fixture modules whose files
/// they use: the fixture features, the fixture analytics and the fixture
/// screen log, whose listeners of the screen note what they hear, the
/// fixture setting, whose restorers note what they read, and the fixture
/// theme, whose colour a test changes.
/// The tests of each role must fail on the providers of the role with a
/// known bug of `brokenProviders`, first on the expectation that the bug
/// breaks, whose message has the reason that the registry gives, such as
/// the `reason:` of the expectation.
Future<MatrixAppTests> fixtureAppTests() async {
  final appTests = await appTestsDirectoryOf('fixture_registry');
  return MatrixAppTests(
    [
      // The platform side of the fixture providers of crash reporting and
      // analytics, which their start-up and services reach, for the tests
      // of every module of the apps with them.
      ...await _fixtureMocks(),
      // The listeners of the screen, the navigator observers, the back
      // button of the system and the configuration of the router, which it
      // creates once, whichever module provides the router: the tests start
      // the app with main() and navigate through the navigation facade of
      // the router role.
      MatrixAppTest(
        '$appTests/router_screens',
        appliesTo: _hearsScreens,
        roles: {routerRole},
      ),
      // The listeners of the screen, which the router calls each on its
      // own, whichever module provides it: a listener that throws keeps no
      // other from hearing the screen. The apps it applies to have two
      // listeners, those of the fixture analytics and of the fixture screen
      // log, and the tests of router_screens, whose helpers it uses.
      MatrixAppTest(
        '$appTests/router_listeners',
        appliesTo: (app) =>
            _hearsScreens(app) &&
            app.modules.contains(const ModuleId('fake_screen_log')),
        roles: {routerRole},
      ),
      // The guards of the routes, which the router asks about every location
      // before it shows it, and tells of its pages when one of them starts
      // or stops allowing, whichever module provides the router: the tests
      // close and open the gates of the fixture gates, whose guards then
      // keep the user from the screens of the fixture feature. The apps it
      // applies to have the tests of router_screens, whose helpers it uses.
      MatrixAppTest(
        '$appTests/router_guards',
        appliesTo: (app) =>
            _hearsScreens(app) &&
            app.modules.contains(const ModuleId('fake_gate')),
        roles: {routerRole},
      ),
      // The guards over the fallback screen of the app entry, the location
      // `/`, which is no route of a module, whichever module provides the
      // router: in the apps with the fixture gates in which no route starts
      // the app, as the router role chose it.
      MatrixAppTest(
        '$appTests/router_guards_fallback',
        appliesTo: (app) =>
            app.hook!.presentRoles.contains(routerRole) &&
            routerRole.startIn(routerRole.hookInput(app.hook!)) == null &&
            app.modules.contains(const ModuleId('fake_gate')),
        roles: {routerRole},
      ),
      // The guards with a page shown over the main navigation, whichever
      // modules provide the router and the layout: once a guard allows
      // again, the user is back in the main navigation, on the destination
      // that the page of the second fixture feature was pushed from. The
      // apps it applies to have the tests of router_screens and of
      // router_guards, whose helpers it uses.
      MatrixAppTest(
        '$appTests/layout_guards',
        appliesTo: (app) =>
            _hearsScreens(app) &&
            app.hook!.presentRoles.contains(layoutRole) &&
            app.modules.contains(const ModuleId('fake_second')) &&
            app.modules.contains(const ModuleId('fake_gate')),
        roles: {routerRole},
      ),
      // The fallback screen of the app entry, which the router shows when
      // no route starts the app, as the router role chose it, whichever
      // module provides the router, and which the listener of the fixture
      // screen log hears of.
      MatrixAppTest(
        '$appTests/router_fallback',
        appliesTo: (app) =>
            app.hook!.presentRoles.contains(routerRole) &&
            routerRole.startIn(routerRole.hookInput(app.hook!)) == null &&
            app.modules.contains(const ModuleId('fake_screen_log')),
        roles: {routerRole},
      ),
      // The listeners of the screen as the user switches between the
      // destinations of the two fixture features, whichever modules provide
      // the router and the layout: the test selects a destination through
      // the AppShell of the layout role. Every listener of the app hears of
      // each switch, those of the fixture analytics and of the fixture
      // screen log, and each navigator of a branch has observers of its
      // own. And the router refuses to push a location in the main
      // navigation from the page outside it of the second fixture feature,
      // shown over it, or to replace that page with one. And the labels of
      // the destinations follow the language of the app: the matrix writes
      // them for the test in each language of the app, from the data of the
      // layout role and of the localization role, or in English alone for
      // an app without texts. The apps they apply to have the tests of
      // router_screens, whose helpers they use.
      MatrixAppTest(
        '$appTests/layout_screens',
        appliesTo: (app) =>
            _hearsScreens(app) &&
            app.hook!.presentRoles.contains(layoutRole) &&
            app.modules.contains(const ModuleId('fake_second')) &&
            app.modules.contains(const ModuleId('fake_screen_log')),
        generatedFiles: _destinationLabelsOf,
        roles: {routerRole, layoutRole},
      ),
      // What only go_router does: notifications of its delegate that leave
      // the page on top as it is, such as a refresh of its routes, which
      // the listeners of the screen do not hear of, and a push() that still
      // completes with the value of its page after a refresh. It checks no
      // role, so it names its module, as `tools/app_tests_test.dart` lets
      // it. The apps it applies to have the tests of router_screens, whose
      // helpers it uses.
      MatrixAppTest(
        '$appTests/go_router_screens',
        appliesTo: (app) =>
            _hearsScreens(app) &&
            app.modules.contains(const ModuleId('go_router')),
      ),
      // What only bottom_tabs does: its bar shows a tab with the label of
      // each destination, in the language of the app, and a tap on a tab
      // selects the destination. It checks no role, so it names its module,
      // as `tools/app_tests_test.dart` lets it. The apps it applies to have
      // the tests of router_screens, whose helpers it uses, those of
      // layout_screens, whose labels of the destinations it reads, and both
      // fixture features, whose destinations it taps.
      MatrixAppTest(
        '$appTests/bottom_tabs_screens',
        appliesTo: (app) =>
            _hearsScreens(app) &&
            app.modules.contains(const ModuleId('fake_second')) &&
            app.modules.contains(const ModuleId('fake_screen_log')) &&
            app.modules.contains(const ModuleId('bottom_tabs')),
      ),
      // The services of the apps with the DI role, whichever module provides
      // it, the test that the CLI keeps: only in the apps whose services
      // have every lifetime, those of the fixture services, so that it runs
      // flutter test in a few apps.
      await diRoleAppTest(lifetimes: DiLifetime.values.toSet()),
      // The fixture services, whichever module provides the DI role:
      // resetDependencies() disposes of those that the container created,
      // in the reverse order of their registration, and creates no lazy
      // singleton only to dispose of it. The functions of the fixture
      // services note what they do.
      MatrixAppTest(
        '$appTests/di_disposal',
        appliesTo: (app) =>
            app.hook!.presentRoles.contains(diRole) &&
            app.modules.contains(FakeRegistrationsModule.id),
        roles: {diRole},
      ),
      // The events of the apps with the events role, whichever module
      // provides it, the test that the CLI keeps: only in the apps with
      // every module, which run flutter test for other tests already.
      await eventsRoleAppTest(among: (app) => app.everyModuleWith != null),
      // The preferences of the apps with the preferences role, whichever
      // module provides it, the test that the CLI keeps: only in the apps
      // with every module, which run flutter test for other tests already.
      // There the fixture preferences provide the role.
      await preferencesRoleAppTest(
        among: (app) => app.everyModuleWith != null,
      ),
      // The restorers of the fixture setting, whichever module provides the
      // preferences role: the start-up gives each the preferences, the next
      // start what the setting saved, and one that throws keeps no other
      // from restoring. Only in the apps with every module, which run
      // flutter test for other tests already.
      MatrixAppTest(
        '$appTests/preferences_restorers',
        appliesTo: (app) =>
            app.everyModuleWith != null &&
            app.hook!.presentRoles.contains(preferencesRole) &&
            app.modules.contains(FakePreferencesUserModule.id),
        roles: {preferencesRole},
      ),
      // The languages and the texts of the apps with the localization
      // role, whichever module provides it, the test that the CLI keeps:
      // only in the apps with every module, which run flutter test for
      // other tests already, and whose second fixture feature has texts in
      // two languages of the app.
      await localizationRoleAppTest(
        among: (app) => app.everyModuleWith != null,
      ),
      // The routes of the apps with a router, whichever module provides it,
      // the test that the CLI keeps: only in the apps with every module,
      // which run flutter test for other tests already, and whose layout
      // shows the destinations of both fixture features.
      await routerWalkAppTest(among: (app) => app.everyModuleWith != null),
      // That walk of the routes while a guard keeps the user out, as on a
      // device, where no test opens a guard: with a gate of the fixture
      // gates closed, the walk expects the target of its guard in place of
      // each location outside its flow, as the router role says, whichever
      // module provides the router. The apps it applies to have the walk,
      // and the tests of router_screens, whose helpers it uses.
      MatrixAppTest(
        '$appTests/router_walk_guards',
        appliesTo: (app) =>
            app.everyModuleWith != null &&
            _hearsScreens(app) &&
            app.modules.contains(const ModuleId('fake_gate')),
        roles: {routerRole},
      ),
      // The theme mode of the apps with the theme role, whichever module
      // provides it, the test that the CLI keeps, which is a test of the
      // app entry role too: only in the apps with every module, which run
      // flutter test for other tests already. There the fixture theme
      // provides the role, whose themes read a colour from the context of
      // the root.
      await themeRoleAppTest(among: (app) => app.everyModuleWith != null),
      // The look of the fixture theme, whose themes read a colour from the
      // context of the root, through a widget that the fixture puts around
      // the root: when the test changes the colour, the screens get the
      // themes of the new colour. A test of the app entry role, whose
      // provider builds the root: the root rebuilds when an inherited widget
      // that its arguments read notifies. Only in the apps with every
      // module, which run flutter test for other tests already.
      MatrixAppTest(
        '$appTests/theme_look',
        appliesTo: (app) =>
            app.everyModuleWith != null &&
            app.modules.contains(FakeThemeModule.id),
        roles: {appEntryRole},
      ),
    ],
    testedRoles: {
      routerRole,
      layoutRole,
      diRole,
      eventsRole,
      preferencesRole,
      localizationRole,
      themeRole,
      appEntryRole,
    },
  );
}

/// The path in an app of what the matrix writes for the tests of the labels
/// of the destinations of the main navigation: `labelLanguages`, the codes
/// of the languages that the tests read the labels in, those of the app in
/// their order ([LocalizationRole.localesIn]), or English alone for an app
/// without the localization role, whose labels are in English;
/// `destinationLabels`, the labels of the destinations in the order of the
/// main navigation ([LayoutRole.destinationsIn]) in each of these languages,
/// by its code; and `chooseLanguage()` and `followDevice()`, which put the
/// app into one of these languages and let it follow the device again, and
/// do nothing in an app without the localization role, which has nothing of
/// what that role generates.
const destinationLabelsFile = 'test/destination_labels.dart';

/// The file at [destinationLabelsFile] of [app], an app of the matrix with
/// the layout role, whose package is [packageName].
///
/// A destination has the label that the app shows for it in a language:
/// the text of its module in that language, or in English when the text has
/// no translation into it, if the module gave the localization role the
/// text ([LocalizationRole.appTextOf]); and its English text otherwise, as
/// for a module that does not list that role.
Map<String, String> _destinationLabelsOf(MatrixApp app, String packageName) {
  final hook = app.hook!;
  final input = layoutRole.hookInput(hook);
  final localized = hook.presentRoles.contains(localizationRole);
  final languages = localized
      ? localizationRole.localesIn(localizationRole.hookInput(hook))
      : const ['en'];
  String labelOf(FacadeRoute route, String language) {
    final label = route.route.destination!.label;
    final text = localizationRole
        .appTextOf(input, ModuleOrigin(route.feature.module), label)
        ?.text;
    return text?.textIn(language) ?? label.en;
  }

  final labels = StringBuffer();
  for (final language in languages) {
    labels.writeln("  '$language': [");
    for (final route in layoutRole.destinationsIn(input)) {
      labels.writeln('    ${SmfNames.dartString(labelOf(route, language))},');
    }
    labels.writeln('  ],');
  }
  final codes = [for (final language in languages) "'$language'"].join(', ');
  // The file of the language of the app, which only an app with the
  // localization role has.
  final appLocale =
      ImportRef.app(LocalizationRole.appLocaleFile.substring('lib/'.length))
          .resolveUri(packageName);
  final directives = [
    "import 'package:flutter/widgets.dart';",
    "import '$appLocale';",
  ]..sort();
  final imports = localized ? '${directives.join('\n')}\n\n' : '';
  return {
    destinationLabelsFile: '''
// The labels of the destinations of the main navigation of the app in each
// of its languages, which the matrix of SMF writes from the data of the
// layout role and of the localization role of the app for the tests of the
// labels, destination_labels_test.dart.
$imports/// The codes of the languages that the tests read the labels in: those of
/// the app, in their order, or English alone for an app without the
/// localization role.
const List<String> labelLanguages = [$codes];

/// The labels of the destinations, in the order of the main navigation, in
/// each language of [labelLanguages], by the code of the language.
const Map<String, List<String>> destinationLabels = {
$labels};
${localized ? _withLanguages : _withoutLanguages}''',
  };
}

/// What [destinationLabelsFile] has in an app with the localization role,
/// to put the app into a language.
const _withLanguages = '''

/// Puts the app into [language], one of [labelLanguages], as a choice of
/// the user does.
Future<void> chooseLanguage(String language) =>
    appLocale.choose(Locale(language));

/// Lets the app follow the languages of the device again.
Future<void> followDevice() => appLocale.choose(null);
''';

/// What [destinationLabelsFile] has in an app without the localization
/// role, which is in English, the one language of `labelLanguages`.
const _withoutLanguages = '''

/// Does nothing: the app has no localization role, so its labels are in
/// English, the one language of [labelLanguages].
Future<void> chooseLanguage(String language) async {}

/// Does nothing: the app has no localization role, so no language was
/// chosen.
Future<void> followDevice() async {}
''';

/// Whether the tests of the listeners of the screen can hear the screens of
/// [app]: it has a router, whichever module provides it, the fixture
/// feature, whose screens they navigate between, and the fixture
/// analytics, whose listener of the screen notes each.
bool _hearsScreens(MatrixApp app) =>
    app.hook!.presentRoles.contains(routerRole) &&
    app.modules.contains(const ModuleId('fake_feature')) &&
    app.modules.contains(const ModuleId('fake_analytics'));

/// The tests of the app with every module of the registry of several
/// providers (`severalProvidersModules`): those that the modules of the CLI
/// keep for the apps they are in (`smfAppTests`), which must pass next to
/// the fixture providers of their roles and whatever else the start-up of
/// the app does, with the mocks of the platform side of those fixtures; and
/// the tests of the roles that an app can have several providers of, the
/// analytics role and the crash reporting role, whose contract they check
/// with every provider. The two tests of the localization role that the
/// CLI keeps are among the first: that app has the fixture texts and the
/// settings module of the CLI, so the role and the setting of the language
/// are checked with a second provider of the role there.
///
/// A test of such a role checks that each call of the service of the role
/// reaches every provider once, whatever the other providers do with it. So
/// it runs only in the app with every module of the registry, whichever
/// modules provide the role there, and looks only at the fixture providers
/// of the role: the service log of the fixtures, which notes each call and
/// which that app has (`test/fixture_registry_test.dart` makes sure), and
/// the platform side of the other fixture providers.
Future<MatrixAppTests> severalProvidersAppTests() async {
  final appTests = await appTestsDirectoryOf('fixture_registry');
  return MatrixAppTests(
    [
      ...(await smfAppTests()).tests,
      ...await _fixtureMocks(),
      // Each call of the analytics service of the app reaches every
      // analytics service once. A service that fails, or that changes the
      // parameters it gets, keeps no other from the call, and one whose
      // factory or start fails is left out.
      MatrixAppTest(
        '$appTests/analytics_role',
        appliesTo: (app) => _withEveryModule(app, analyticsRole),
        roles: {analyticsRole},
      ),
      // Each call of the crash reporter of the app, and each error that
      // nothing catches, reaches every crash reporter once. A crash
      // reporter that fails keeps no other from it and is not reported to
      // again, and one whose factory or start fails is left out.
      MatrixAppTest(
        '$appTests/crash_reporting_role',
        appliesTo: (app) => _withEveryModule(app, crashReportingRole),
        roles: {crashReportingRole},
      ),
    ],
    testedRoles: {analyticsRole, crashReportingRole},
  );
}

/// Whether [app] is an app with every module of its registry, as the app
/// of several providers is, and has [role], whichever modules provide it.
bool _withEveryModule(MatrixApp app, Role role) =>
    app.everyModuleWith != null && app.hook!.presentRoles.contains(role);

/// The mocks of the platform side of the fixture providers of crash
/// reporting and analytics, which their start-up and services reach, in the
/// directory `app_tests` of their package: the matrix sets them up for the
/// tests of every module of the apps with them (`MatrixAppTest.mocks`).
Future<List<MatrixAppTest>> _fixtureMocks() async {
  final appTests = await appTestsDirectoryOf('fake_infra');
  return [
    MatrixAppTest(
      '$appTests/fake_crash',
      appliesTo: (app) => app.modules.contains(FakeCrashModule.id),
      mocks:
          const MatrixMocks('test/fake_crash_mocks.dart', 'mockFixtureCrash'),
    ),
    MatrixAppTest(
      '$appTests/fake_analytics',
      appliesTo: (app) => app.modules.contains(FakeAnalyticsModule.id),
      mocks: const MatrixMocks(
        'test/fake_analytics_mocks.dart',
        'mockFixtureAnalytics',
      ),
    ),
  ];
}
