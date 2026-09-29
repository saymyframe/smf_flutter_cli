// The tests that the matrix of CI adds to the apps of the fixture modules
// (fixtureAppTests, which tool/matrix.dart runs). CI runs them only in its
// job with Flutter, which checks that they apply to some app and that they
// check the contract of their roles with every provider only at its end;
// these tests check the same without Flutter.
import 'package:fixture_registry/fixture_registry.dart';
import 'package:fixture_registry/matrix_app_tests.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:test/test.dart';

void main() {
  late MatrixAppTests appTests;
  late List<MatrixApp> apps;

  setUpAll(() async {
    appTests = await fixtureAppTests();
    final (apps: matrix, :failed) = await matrixOf(fixtureModules());
    expect(failed, isEmpty);
    apps = matrix;
  });

  /// The app test whose files are in the directory [name], whose path
  /// joins its names with `\` on Windows, but for the last.
  MatrixAppTest named(String name) => appTests.tests.singleWhere(
        (test) => test.directory.split(RegExp(r'[/\\]')).last == name,
      );

  /// The names of the apps that [test] applies to.
  List<String> appsOf(MatrixAppTest test) => [
        for (final app in apps)
          if (test.appliesTo(app)) app.name,
      ];

  test('each app test applies to an app of the matrix', () {
    expect(appTests.tests, isNotEmpty);
    for (final test in appTests.tests) {
      expect(appsOf(test), isNotEmpty, reason: test.directory);
    }
  });

  test(
      'the app tests check the contract of the router role and of the layout '
      'role with every provider of each, which they tell apart by the roles '
      'of the app only', () {
    expect(appTests.testedRoles, containsAll([routerRole, layoutRole]));
    expect(named('router_screens').roles, {routerRole});
    expect(named('router_fallback').roles, {routerRole});
    expect(named('layout_screens').roles, {routerRole, layoutRole});

    expect(appTests.roleProblems(fixtureModules(), apps), isEmpty);
  });

  test(
      'the tests that use the helpers of router_screens apply only to the '
      'apps that have them', () {
    final routerScreens = appsOf(named('router_screens'));

    for (final name in [
      'layout_screens',
      'go_router_screens',
      'bottom_tabs_screens',
    ]) {
      expect(routerScreens, containsAll(appsOf(named(name))), reason: name);
    }
  });
}
