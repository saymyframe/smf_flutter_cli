import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/redirects_generator.dart';
import 'package:test/test.dart';

import '../../helpers/dart_code.dart';
import '../../helpers/route_fixtures.dart';

void main() {
  group('RedirectsGenerator.generateCombinedRedirectCode', () {
    Future<List<String>> compile(String redirect) {
      return compileErrors('''
$goRouterStubs
String? authGuard(BuildContext context, GoRouterState state) => null;
String? onboardingGuard(BuildContext context, GoRouterState state) => null;

final GoRouterRedirect redirect = $redirect;
''');
    }

    test('allows navigation when there are no guards', () async {
      final code = RedirectsGenerator.generateCombinedRedirectCode([]);

      expect(code, contains('(context, state)'));
      expect(code, contains('return null;'));
      expect(await compile(code), isEmpty);
    });

    test('returns the first non-null guard redirect in declaration order',
        () async {
      final code = RedirectsGenerator.generateCombinedRedirectCode([
        goRouterGuard('authGuard(context, state)'),
        goRouterGuard('onboardingGuard(context, state)'),
      ]);

      final checks = [
        'final r0 = authGuard(context, state);',
        'if (r0 != null) return r0;',
        'final r1 = onboardingGuard(context, state);',
        'if (r1 != null) return r1;',
        'return null;',
      ];
      final positions = checks.map(code.indexOf).toList();
      expect(positions, everyElement(isNonNegative));
      expect(positions, orderedEquals([...positions]..sort()));
      expect(await compile(code), isEmpty);
    });

    test('trims whitespace around the guard code', () {
      final code = RedirectsGenerator.generateCombinedRedirectCode([
        goRouterGuard('\n  authGuard(context, state)  \n'),
      ]);

      expect(code, contains('final r0 = authGuard(context, state);'));
    });

    test('uses only the go_router binding of a guard', () {
      final code = RedirectsGenerator.generateCombinedRedirectCode([
        RouteGuard(
          bindings: {
            RoutingMode.autoRouter: AutoRouteGuard(
              className: 'AuthGuard',
              code: 'AuthGuard()',
            ),
            RoutingMode.goRouter: GoRouteRedirect(
              code: 'authGuard(context, state)',
            ),
          },
        ),
      ]);

      expect(code, contains('authGuard(context, state)'));
      expect(code, isNot(contains('AuthGuard()')));
    });

    test('throws naming the guard that has no go_router binding', () {
      expect(
        () => RedirectsGenerator.generateCombinedRedirectCode([
          goRouterGuard('authGuard(context, state)'),
          autoRouterOnlyGuard(),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Guard 1 does not have a valid GoRouteRedirect binding',
          ),
        ),
      );
    });
  });
}
