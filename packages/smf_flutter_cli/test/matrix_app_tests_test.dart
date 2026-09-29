// The tests that the matrix of CI adds to the apps of the modules of
// `smf create` (smfAppTests, which tool/matrix.dart runs). CI runs them
// only in its job with Flutter, which checks that they apply to some app
// and that they check the contract of their roles with every provider
// only at its end; these tests check the same without Flutter.
import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/matrix_app_tests.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:test/test.dart';

void main() {
  late MatrixAppTests appTests;
  late List<MatrixApp> apps;

  setUpAll(() async {
    appTests = await smfAppTests();
    final (apps: matrix, :failed) = await matrixOf(smfModules);
    expect(failed, isEmpty);
    apps = matrix;
  });

  /// The app test whose files are in the directory [name].
  MatrixAppTest named(String name) =>
      appTests.tests.singleWhere((test) => p.basename(test.directory) == name);

  test('each app test applies to an app of the matrix', () {
    expect(appTests.tests, isNotEmpty);
    for (final test in appTests.tests) {
      expect(apps.where(test.appliesTo), isNotEmpty, reason: test.directory);
    }
  });

  test(
      'the app tests check the contract of the router role with every '
      'provider of it, which they tell apart by the roles of the app only', () {
    expect(appTests.testedRoles, contains(routerRole));
    expect(named('screen_views').roles, contains(routerRole));

    expect(appTests.roleProblems(smfModules, apps), isEmpty);
  });

  test(
      'the test of the screen views expects the screen that the router role '
      'chose for the app to start on', () {
    final screenViews = named('screen_views');

    expect(
      {
        for (final app in apps)
          if (screenViews.appliesTo(app))
            app.name: screenViews.values!(app)['start_screen'],
      },
      {
        // The fallback screen of the app entry, without a route that can
        // start the app.
        'firebase_analytics with di, router': '/',
        'firebase_analytics with router': '/',
        // The start screen of home.
        'every module (bloc)': 'home.home',
        'every module (riverpod)': 'home.home',
      },
    );
  });
}
