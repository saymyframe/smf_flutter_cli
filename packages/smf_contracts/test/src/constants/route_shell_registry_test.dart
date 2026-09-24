import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('ShellRegistry', () {
    test('resolves the main tabs shell', () {
      final shell = ShellRegistry.resolve('main-tabs');

      expect(shell, isNotNull);
      expect(shell!.id, 'main-tabs');
      expect(shell.type, ShellType.tabBar);
      expect(shell.screen.className, 'MainTabsShell');
      expect(shell.widgetFilePath, 'core/widgets/main_tabs_shell.dart');
    });

    test('resolves the id produced by RouteShellLink.toMainTabsShell', () {
      final link = RouteShellLink.toMainTabsShell();

      expect(ShellRegistry.resolve(link.id)?.id, link.id);
    });

    test('returns null for an unknown id', () {
      expect(ShellRegistry.resolve('unknown-shell'), isNull);
      expect(ShellRegistry.resolve(''), isNull);
    });

    test('returns the same declaration instance on every lookup', () {
      // Generators group routes in maps keyed by ShellDeclaration, which has
      // no value equality, so lookups must be stable.
      expect(
        identical(
          ShellRegistry.resolve('main-tabs'),
          ShellRegistry.resolve('main-tabs'),
        ),
        isTrue,
      );
    });

    test('widget file paths are relative to lib/', () {
      final shell = ShellRegistry.resolve('main-tabs')!;

      expect(shell.widgetFilePath, isNot(startsWith('lib/')));
      expect(shell.widgetFilePath, isNot(startsWith('/')));
      expect(shell.widgetFilePath, endsWith('.dart'));
    });
  });
}
