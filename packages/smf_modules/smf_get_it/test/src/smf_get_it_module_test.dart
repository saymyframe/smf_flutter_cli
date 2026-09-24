import 'dart:io';

import 'package:mason/mason.dart';
import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_get_it/src/smf_get_it_module.dart';
import 'package:test/test.dart';

import '../helpers/dart_code.dart';
import '../helpers/project.dart';

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
    tempDir = await Directory.systemTemp.createTemp('smf_get_it_module');
  });

  tearDown(() => tempDir.delete(recursive: true));

  group('SmfGetItModule', () {
    final module = SmfGetItModule();

    test('declares the get_it module and its pub dependency', () {
      final descriptor = module.moduleDescriptor;

      expect(descriptor.name, kGetItModule);
      expect(descriptor.pubDependency, [startsWith('get_it:')]);
    });

    test('ships the getIt instance and a core DI template with DSL slots',
        () async {
      final generator = await MasonGenerator.fromBundle(
        module.brickContributions.single.bundle,
      );
      await generator.generate(
        DirectoryGeneratorTarget(tempDir),
        vars: {'app_name': appName},
      );
      final projectRoot = join(tempDir.path, appName);

      final typedef = File(join(projectRoot, 'lib', 'core', 'typedef.dart'));
      expect(
        typedef.readAsStringSync(),
        contains('final getIt = GetIt.instance;'),
      );

      final coreDi = File(
        join(projectRoot, 'lib', 'core', 'di', 'core_di.dart'),
      ).readAsStringSync();
      expect(coreDi, contains("import 'package:test_app/core/typedef.dart';"));
      expect(coreDi, contains('{{#imports}}'));
      expect(coreDi, contains('{{#di}}'));
      expect(coreDi, contains('void setUpCoreDI()'));
    });

    test('sets up core DI in main() right after binding initialization',
        () async {
      final mainFile = File(join(tempDir.path, 'lib', 'main.dart'));
      await mainFile.create(recursive: true);
      await mainFile.writeAsString(_coreMainDart);

      await PatchEngine(
        module.sharedFileContributions,
        projectRoot: tempDir.path,
        mustacheVariables: {'app_name': appName},
      ).applyAll();

      final patched = await mainFile.readAsString();
      expect(
        patched,
        contains("import 'package:test_app/core/di/core_di.dart';"),
      );
      expect('setUpCoreDI();'.allMatches(patched), hasLength(1));
      final setUp = patched.indexOf('setUpCoreDI();');
      expect(
        patched.indexOf('WidgetsFlutterBinding.ensureInitialized();'),
        lessThan(setUp),
      );
      expect(setUp, lessThan(patched.indexOf('runApp(')));
      expectParses(patched);
    });
  });
}
