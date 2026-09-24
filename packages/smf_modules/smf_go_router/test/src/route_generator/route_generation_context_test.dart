import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/route_generation_context.dart';
import 'package:test/test.dart';

import '../../helpers/route_fixtures.dart';

void main() {
  group('RouteGenerationContext.resolveShell', () {
    const pagesShell = ShellDeclaration(
      id: 'onboarding-pages',
      type: ShellType.pageView,
      screen: RouteScreen('OnboardingPagesShell'),
      widgetFilePath: 'core/widgets/onboarding_pages_shell.dart',
    );

    RouteGenerationContext contextWith(List<ShellDeclaration> shells) {
      return RouteGenerationContext(
        shellDeclarations: shells,
        generateRoute: (_) => '',
        generateImports: (_) => [],
      );
    }

    test('finds a declared shell by id', () {
      final context = contextWith([mainTabsShell, pagesShell]);

      expect(context.resolveShell('onboarding-pages'), same(pagesShell));
      expect(context.resolveShell('main-tabs'), same(mainTabsShell));
    });

    test('throws for a shell id that is not declared', () {
      expect(
        () => contextWith([mainTabsShell]).resolveShell('onboarding-pages'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Unknown shell id: onboarding-pages',
          ),
        ),
      );
    });
  });
}
