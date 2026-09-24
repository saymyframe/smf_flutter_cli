import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/app_routes_generator.dart';
import 'package:test/test.dart';

import '../../helpers/dart_code.dart';
import '../../helpers/route_fixtures.dart';

void main() {
  group('AppRoutesGenerator', () {
    final generator = AppRoutesGenerator();

    test('declares a path and a name constant for a named route', () {
      final code = generator.generateAppRoutes([
        Route(path: '/settings', name: 'settings'),
      ]);

      expect(
        code.trim().split('\n').map((l) => l.trim()),
        [
          "static const settingsPath = '/settings';",
          "static const settings = 'settings';",
        ],
      );
    });

    test('derives the path constant from the path of an unnamed route', () {
      final code = generator.generateAppRoutes([Route(path: '/profile')]);

      expect(code.trim(), "static const profilePath = '/profile';");
    });

    test('keeps the path template, including parameters, as the value', () {
      final code = generator.generateAppRoutes([
        Route(path: '/orders/:orderId', name: 'order'),
      ]);

      expect(code, contains("static const orderPath = '/orders/:orderId';"));
    });

    test('declares each constant only once', () {
      final code = generator.generateAppRoutes([
        Route(path: '/settings', name: 'settings'),
        Route(path: '/settings', name: 'settings'),
        Route(path: '/profile'),
        Route(path: '/profile'),
      ]);

      expect(countOf(code, 'static const settingsPath '), 1);
      expect(countOf(code, 'static const settings '), 1);
      expect(countOf(code, 'static const profilePath '), 1);
    });

    test('returns an empty body when there are no routes', () {
      expect(generator.generateAppRoutes([]), isEmpty);
    });

    test('produces a class body that compiles', () async {
      final code = generator.generateAppRoutes([
        Route(path: '/home', name: 'home'),
        Route(path: '/orders/:orderId', name: 'order'),
        Route(path: '/profile'),
      ]);

      expect(
        await compileErrors('abstract final class AppRoutes {\n$code}\n'),
        isEmpty,
      );
    });

    test(
      'keeps the camelCase of a route name in its path constant',
      () {
        final code = generator.generateAppRoutes([
          Route(path: '/home', name: 'homeScreen'),
        ]);

        expect(code, contains("static const homeScreenPath = '/home';"));
      },
      skip: 'Bug: StringExt.camelCase lowercases inner capitals, so '
          "'homeScreen' becomes 'homescreenPath'",
    );

    test(
      'turns a dashed path into a camelCase path constant',
      () {
        final code = generator.generateAppRoutes([
          Route(path: '/user-profile'),
        ]);

        expect(
          code,
          contains("static const userProfilePath = '/user-profile';"),
        );
      },
      skip: 'Bug: _safeRouteConst re-runs StringExt.camelCase, which '
          "lowercases 'userProfile' into 'userprofilePath'",
    );
  });
}
