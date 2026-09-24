import 'package:mason/mason.dart' show Logger;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

// Values come from loops so the constructors run at test time instead of
// being evaluated as constants.
void main() {
  test('GeneratedFile keeps its path and content', () {
    for (final path in ['lib/main.dart', 'lib/core/di/core_di.dart']) {
      final file = GeneratedFile(path, '// $path');

      expect(file.path, path);
      expect(file.content, '// $path');
    }
  });

  test('DslContext has no DI groups, route groups or shells by default', () {
    for (final initialRoute in ['/home', '/noModules']) {
      final context = DslContext(
        projectRootPath: '/tmp/app',
        mustacheVariables: {'app_name': 'app'},
        logger: Logger(),
        initialRoute: initialRoute,
      );

      expect(context.initialRoute, initialRoute);
      expect(context.diGroups, isEmpty);
      expect(context.routeGroups, isEmpty);
      expect(context.shellDeclarations, isEmpty);
    }
  });
}
