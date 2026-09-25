import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support.dart';

void main() {
  const module = FlutterCoreModule();

  group('FlutterCoreModule', () {
    test('is the scaffold that provides the app entry and uses a router', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, FlutterCoreModule.id);
      expect(descriptor.kind, ModuleKinds.scaffold);
      expect(descriptor.provides, {appEntryRole});
      expect(descriptor.uses, {routerRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
    });

    test('forms a valid registry on its own and with other modules', () {
      expect(ModuleRegistry.problemsOf(const [module]), isEmpty);
      expect(ModuleRegistry.problemsOf(testRegistry().modules), isEmpty);
    });

    test('names the Android and iOS projects after the app', () {
      final brick = module
          .contribute(ContractHarness.defaultContext)
          .whereType<BrickContribution>()
          .single;

      expect(brick.vars, {
        'android_namespace': 'com.example.contract_app',
        'android_application_id': 'com.example.contract_app',
        'android_package_path': 'com/example/contract_app',
        'ios_bundle_id': 'com.example.contract-app',
      });
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(testRegistry()).checkAll();
    });

    test('builds the app with and without a router', () {
      expect(
        results.map((result) => result.contractCase.name),
        containsAll(['flutter_core with router', 'flutter_core']),
      );
    });

    test('finds no errors in any app, rendered code included', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });
  });

  group('an app of flutter_core alone', () {
    late Map<String, String> texts;

    setUpAll(() async {
      final result = await renderedApp(const [FlutterCoreModule.id]);
      texts = result.app!.texts;
    });

    test('has the Dart entry point, the root widget and a widget test', () {
      expect(
        texts.keys,
        containsAll(const [
          'lib/main.dart',
          'lib/bootstrap.dart',
          'lib/app.dart',
          'lib/core/app/fallback_start_screen.dart',
          'test/core/app/fallback_start_screen_test.dart',
          'analysis_options.yaml',
          'pubspec.yaml',
          'README.md',
          '.gitignore',
          '.metadata',
        ]),
      );
    });

    test('runs the app after bootstrap() without wrappers', () {
      expect(
        texts['lib/main.dart'],
        allOf(
          contains('WidgetsFlutterBinding.ensureInitialized();\n'
              '  await bootstrap();\n'),
          contains('runApp(\n    const App(),\n  );'),
        ),
      );
    });

    test('has an empty bootstrap() without imports', () {
      final bootstrap = texts['lib/bootstrap.dart']!;

      expect(bootstrap, contains('Future<void> bootstrap() async {'));
      expect(bootstrap, isNot(contains('import ')));
    });

    test('shows the fallback start screen in a MaterialApp', () {
      final app = texts['lib/app.dart']!;

      expect(app, contains("import 'core/app/fallback_start_screen.dart';"));
      expect(app, isNot(contains('app_router.dart')));
      expect(app, contains('MaterialApp(\n'));
      expect(app, contains("title: 'Contract App',"));
      expect(
        app,
        contains('builder: (context, child) =>\n            child!,'),
      );
      expect(app, contains('home: const FallbackStartScreen(),'));
      expect(app, isNot(contains('routerConfig')));
    });

    test('names the app on the fallback start screen and in its test', () {
      expect(
        texts['lib/core/app/fallback_start_screen.dart'],
        contains("Text('Contract App')"),
      );
      final test = texts['test/core/app/fallback_start_screen_test.dart']!;
      expect(
        test,
        contains(
          "import 'package:contract_app/core/app/fallback_start_screen.dart';",
        ),
      );
      expect(test, contains("find.text('Contract App')"));
    });

    test('depends on Flutter 3.44 and the lints of a new Flutter app', () {
      final pubspec = loadYaml(texts['pubspec.yaml']!) as YamlMap;

      expect(pubspec['name'], 'contract_app');
      expect(pubspec['publish_to'], 'none');
      expect(pubspec['environment'], {
        'sdk': '^3.12.0',
        'flutter': '>=3.44.0',
      });
      expect(pubspec['dependencies'], {
        'flutter': {'sdk': 'flutter'},
      });
      expect(pubspec['dev_dependencies'], {
        'flutter_test': {'sdk': 'flutter'},
        'flutter_lints': '^6.0.0',
      });
      expect(pubspec['flutter'], {'uses-material-design': true});
      expect(
        texts['analysis_options.yaml'],
        'include: package:flutter_lints/flutter.yaml\n',
      );
    });

    test('names the app in its README', () {
      expect(texts['README.md'], startsWith('# contract_app\n'));
    });
  });

  group('an app of flutter_core with a router', () {
    test('passes the router to a MaterialApp.router', () async {
      final result = await renderedApp(const [
        FlutterCoreModule.id,
        TestRouterModule.id,
      ]);
      final app = result.app!.texts['lib/app.dart']!;

      expect(app, contains("import 'core/router/app_router.dart';"));
      expect(app, isNot(contains('fallback_start_screen.dart')));
      expect(app, contains('MaterialApp.router(\n'));
      expect(app, contains('routerConfig: appRouter.config,'));
      expect(app, isNot(contains('home:')));
    });
  });

  group('an app with something in every socket', () {
    late Map<String, String> texts;

    setUpAll(() async {
      final result = await renderedApp(const [
        FlutterCoreModule.id,
        EverySocketModule.id,
      ]);
      texts = result.app!.texts;
    });

    test('starts up in the order of the phases of bootstrap()', () {
      final bootstrap = texts['lib/bootstrap.dart']!;
      final offsets = [
        for (final phase in ['early', 'platform', 'di', 'late'])
          bootstrap.indexOf("debugPrint('$phase');"),
      ];

      expect(offsets, everyElement(greaterThan(0)));
      expect(offsets, orderedEquals([...offsets]..sort()));
      expect(
        bootstrap,
        startsWith("import 'package:flutter/foundation.dart';\n\n"
            "@pragma('vm:entry-point')\n"
            'Future<void> onBackgroundMessage() async {}\n'),
      );
    });

    test('wraps the root widget and every route', () {
      expect(
        texts['lib/main.dart'],
        contains('RepaintBoundary(child: const App()),'),
      );
      final app = texts['lib/app.dart']!;
      expect(app, contains("supportedLocales: [Locale('en')],"));
      expect(
        app,
        contains('MediaQuery.withNoTextScaling(child: child!),'),
      );
    });
  });
}
