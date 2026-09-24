import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('RouteShellLink', () {
    test('toMainTabsShell links to the main-tabs shell', () {
      expect(RouteShellLink.toMainTabsShell().id, 'main-tabs');
    });

    test('toMainTabsShell returns one canonical link', () {
      expect(
        identical(
          RouteShellLink.toMainTabsShell(),
          RouteShellLink.toMainTabsShell(),
        ),
        isTrue,
      );
    });

    test('links with the same id are equal', () {
      // Built at runtime so the constructor call is not canonicalized.
      final id = ['main', 'tabs'].join('-');

      expect(RouteShellLink(id), equals(RouteShellLink.toMainTabsShell()));
      expect(
        RouteShellLink(id).hashCode,
        RouteShellLink.toMainTabsShell().hashCode,
      );
    });

    test('links with different ids are not equal', () {
      expect(
        const RouteShellLink('onboarding-pages'),
        isNot(equals(RouteShellLink.toMainTabsShell())),
      );
    });
  });
}
