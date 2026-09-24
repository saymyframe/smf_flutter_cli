import 'dart:io';

import 'package:mason/mason.dart' hide GeneratedFile;
import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_go_router/src/smf_go_router_module.dart';
import 'package:test/test.dart';

import '../helpers/dart_code.dart';

/// lib/main.dart as the flutter_core brick generates it.
const _coreMainDart = '''
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
''';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('smf_go_router_module');
  });

  tearDown(() => tempDir.delete(recursive: true));

  group('SmfGoRouterModule', () {
    final module = SmfGoRouterModule();

    test('declares the go_router module and its pub dependency', () {
      final descriptor = module.moduleDescriptor;

      expect(descriptor.name, kGoRouterModule);
      expect(descriptor.pubDependency, [startsWith('go_router:')]);
    });

    test('ships templates with the slots the DSL generator fills', () async {
      final brick = module.brickContributions.single;
      final generator = await MasonGenerator.fromBundle(brick.bundle);
      await generator.generate(
        DirectoryGeneratorTarget(tempDir),
        vars: {'app_name': 'test_app'},
      );

      String read(String relative) => File(
            join(tempDir.path, 'test_app', 'lib', relative),
          ).readAsStringSync();

      final router = read('core/router/app_router.dart');
      expect(router, contains('{{#imports}}'));
      expect(router, contains('{{#router}}'));
      expect(
        router,
        contains("import 'package:test_app/core/router/app_routes.dart';"),
      );
      expect(read('core/router/app_routes.dart'), contains('{{#appRoutes}}'));
      expect(
        read('core/widgets/main_tabs_shell.dart'),
        contains('{{#tabsWidget}}'),
      );
    });

    test('wires the router into MaterialApp in main.dart', () async {
      final mainFile = File(join(tempDir.path, 'lib', 'main.dart'));
      await mainFile.create(recursive: true);
      await mainFile.writeAsString(_coreMainDart);

      await PatchEngine(
        module.sharedFileContributions,
        projectRoot: tempDir.path,
        mustacheVariables: {'app_name': 'test_app'},
      ).applyAll();

      final patched = await mainFile.readAsString();
      expect(
        patched,
        contains("import 'package:test_app/core/router/app_router.dart';"),
      );
      expect(patched, contains('MaterialApp.router(routerConfig: router)'));
      expect(patched, isNot(contains('home:')));
      expect(patched, isNot(contains('const MaterialApp')));
      expect(patched, contains('WidgetsFlutterBinding.ensureInitialized();'));
      expectParses(patched);
    });
  });
}
