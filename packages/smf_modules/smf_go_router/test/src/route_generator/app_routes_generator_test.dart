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
        const Route(path: '/settings', name: 'settings'),
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
      final code = generator.generateAppRoutes([const Route(path: '/profile')]);

      expect(code.trim(), "static const profilePath = '/profile';");
    });

    test('treats an empty name like no name, as the router does', () {
      final code = generator.generateAppRoutes([
        const Route(path: '/about', name: ''),
      ]);

      expect(code.trim(), "static const aboutPath = '/about';");
    });

    test('keeps the path template, including parameters, as the value', () {
      final code = generator.generateAppRoutes([
        const Route(path: '/orders/:orderId', name: 'order'),
      ]);

      expect(code, contains("static const orderPath = '/orders/:orderId';"));
    });

    test('declares each constant only once', () {
      final code = generator.generateAppRoutes([
        const Route(path: '/settings', name: 'settings'),
        const Route(path: '/settings', name: 'settings'),
        const Route(path: '/profile'),
        const Route(path: '/profile'),
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
        const Route(path: '/home', name: 'home'),
        const Route(path: '/orders/:orderId', name: 'order'),
        const Route(path: '/profile'),
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
          const Route(path: '/home', name: 'homeScreen'),
        ]);

        expect(code, contains("static const homeScreenPath = '/home';"));
      },
    );

    test(
      'turns a dashed path into a camelCase path constant',
      () {
        final code = generator.generateAppRoutes([
          const Route(path: '/user-profile'),
        ]);

        expect(
          code,
          contains("static const userProfilePath = '/user-profile';"),
        );
      },
    );

    test('camelCases every segment of a nested path', () {
      final code = generator.generateAppRoutes([
        const Route(path: '/orders/:orderId/tracking-info'),
      ]);

      expect(
        code,
        contains(
          'static const ordersOrderIdTrackingInfoPath = '
          "'/orders/:orderId/tracking-info';",
        ),
      );
    });
  });
}
