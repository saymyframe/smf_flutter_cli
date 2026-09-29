/// The tests that the matrix of CI adds to the apps of the fixture modules,
/// which this package keeps in its `app_tests`, and the roles whose
/// contract they check with every provider; `tool/matrix.dart` runs them.
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// The tests of the apps of the fixture modules, and the roles whose
/// contract they check with every provider: the router role and the layout
/// role, whose providers call the listeners of the screen.
///
/// They select the apps with a provider of a role by the roles of the app,
/// whichever module provides it, and name the fixture modules whose files
/// they use: the fixture features, and the fixture analytics and the
/// fixture screen log, whose listeners of the screen note what they hear.
Future<MatrixAppTests> fixtureAppTests() async {
  final appTests = await appTestsDirectoryOf('fixture_registry');
  return MatrixAppTests(
    [
      // The listeners of the screen, the navigator observers and the back
      // button of the system, whichever module provides the router: the
      // test starts the app with main() and navigates through the
      // navigation facade of the router role.
      MatrixAppTest(
        '$appTests/router_screens',
        appliesTo: _hearsScreens,
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
      // own. The apps it applies to have the tests of router_screens, whose
      // helpers it uses.
      MatrixAppTest(
        '$appTests/layout_screens',
        appliesTo: (app) =>
            _hearsScreens(app) &&
            app.hook!.presentRoles.contains(layoutRole) &&
            app.modules.contains(const ModuleId('fake_second')) &&
            app.modules.contains(const ModuleId('fake_screen_log')),
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
      // What only bottom_tabs does: a tap on a tab of its bar selects the
      // destination. It checks no role, so it names its module, as
      // `tools/app_tests_test.dart` lets it. The apps it applies to have the
      // tests of router_screens, whose helpers it uses, and both fixture
      // features, whose destinations it taps.
      MatrixAppTest(
        '$appTests/bottom_tabs_screens',
        appliesTo: (app) =>
            _hearsScreens(app) &&
            app.modules.contains(const ModuleId('fake_second')) &&
            app.modules.contains(const ModuleId('bottom_tabs')),
      ),
    ],
    testedRoles: {routerRole, layoutRole},
  );
}

/// Whether the tests of the listeners of the screen can hear the screens of
/// [app]: it has a router, whichever module provides it, the fixture
/// feature, whose screens they navigate between, and the fixture
/// analytics, whose listener of the screen notes each.
bool _hearsScreens(MatrixApp app) =>
    app.hook!.presentRoles.contains(routerRole) &&
    app.modules.contains(const ModuleId('fake_feature')) &&
    app.modules.contains(const ModuleId('fake_analytics'));
