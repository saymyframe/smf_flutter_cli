import 'package:smf_flutter_cli/prompts/prompt.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:test/test.dart';

import '../../helpers/mock_logger.dart';
import '../../helpers/test_modules.dart';

void main() {
  group('CliContext', () {
    test('exposes the values it was created with', () {
      final logger = MockLogger();
      const resolver = ModuleDependencyResolver();
      final modules = [TestModule('a')];

      final context = CliContext(
        name: 'demo',
        selectedModules: modules,
        outputDirectory: '/out',
        logger: logger,
        strictMode: StrictMode.strict,
        moduleResolver: resolver,
        packageName: 'com.acme',
        initialRoute: '/home',
      );

      expect(context.name, 'demo');
      expect(context.selectedModules, same(modules));
      expect(context.outputDirectory, '/out');
      expect(context.logger, same(logger));
      expect(context.strictMode, StrictMode.strict);
      expect(context.moduleResolver, same(resolver));
      expect(context.packageName, 'com.acme');
      expect(context.initialRoute, '/home');
    });

    test('leaves package name and initial route unset by default', () {
      final context = CliContext(
        name: 'demo',
        selectedModules: const [],
        outputDirectory: '/out',
        logger: MockLogger(),
        strictMode: StrictMode.lenient,
        moduleResolver: const ModuleDependencyResolver(),
      );

      expect(context.packageName, isNull);
      expect(context.initialRoute, isNull);
    });
  });
}
