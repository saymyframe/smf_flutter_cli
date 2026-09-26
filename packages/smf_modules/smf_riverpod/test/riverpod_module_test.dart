import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_riverpod/smf_riverpod.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The modules of the tests: this one, and flutter_core, which creates the
/// app it becomes a part of.
const List<SmfModule> _modules = [FlutterCoreModule(), RiverpodModule()];

const _widgets = ImportRef('package:flutter/widgets.dart');

/// A module that requires the state management role and wraps the root
/// widget, as a module with variants for the providers of the role may do.
/// Its id comes before `riverpod`.
final class _StateUser extends SmfModule {
  const _StateUser();

  static const id = ModuleId('a_state_user');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Uses the state management',
        kind: ModuleKinds.infrastructure,
        requires: {stateManagementRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => const [
        SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap('RepaintBoundary(child: ', ')', imports: [_widgets]),
        ),
      ];
}

/// A module that depends on this one and wraps the root widget. Its id
/// comes before `riverpod`.
final class _RiverpodUser extends SmfModule {
  const _RiverpodUser();

  static const id = ModuleId('a_riverpod_user');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Uses Riverpod',
        kind: ModuleKinds.infrastructure,
        dependsOn: {RiverpodModule.id},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => const [
        SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap('KeyedSubtree(child: ', ')', imports: [_widgets]),
        ),
      ];
}

/// The app of [modules] among [registry] that the contract harness renders,
/// which has no errors.
Future<RenderedApp> _appOf(
  List<ModuleId> modules, {
  List<SmfModule> registry = _modules,
}) async {
  final result = await ContractHarness(ModuleRegistry(registry)).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  final app = result.app;
  if (result.errors.isNotEmpty || app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return app;
}

/// The pubspec of [app] as plain maps and lists.
Map<String, Object?> _pubspecOf(RenderedApp app) {
  Object? plain(Object? node) => switch (node) {
        final YamlMap map => {
            for (final MapEntry(:key, :value) in map.entries)
              '$key': plain(value),
          },
        final YamlList list => [for (final item in list) plain(item)],
        _ => node,
      };
  return plain(loadYaml(app.files['pubspec.yaml']!.text))!
      as Map<String, Object?>;
}

/// The widgets that `main()` of [app] passes to `runApp()`, from the
/// outermost to the root widget, each the `child` of the one before.
List<String> _rootWidgetsOf(RenderedApp app) {
  final unit = parseString(
    content: app.files[AppEntryRole.mainFile]!.text,
  ).unit;
  final finder = _RunAppFinder();
  unit.declarations
      .whereType<FunctionDeclaration>()
      .singleWhere((declaration) => declaration.name.lexeme == 'main')
      .accept(finder);
  final widgets = <String>[];
  Expression? widget = finder.runApp!.argumentList.arguments.single;
  while (widget != null) {
    final (name, arguments) = switch (widget) {
      MethodInvocation(target: null, :final methodName, :final argumentList) =>
        (methodName.name, argumentList),
      InstanceCreationExpression(:final constructorName, :final argumentList) =>
        (constructorName.type.name.lexeme, argumentList),
      _ => throw StateError('runApp() gets ${widget.toSource()}'),
    };
    widgets.add(name);
    widget = [
      for (final argument in arguments.arguments)
        if (argument case NamedExpression(:final name, :final expression)
            when name.label.name == 'child')
          expression,
    ].firstOrNull;
  }
  return widgets;
}

final class _RunAppFinder extends RecursiveAstVisitor<void> {
  MethodInvocation? runApp;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'runApp') runApp = node;
    super.visitMethodInvocation(node);
  }
}

void main() {
  const module = RiverpodModule();

  group('RiverpodModule', () {
    test('is infrastructure that provides the state management', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('riverpod'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {stateManagementRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the provider of the app entry', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test('asks for the Dart that flutter_riverpod 3.4 needs', () {
      final environment = module
          .contribute(ContractHarness.defaultContext)
          .whereType<PubspecEnvironment>()
          .single;

      expect(environment.sdk, '^3.12.0');
      expect(environment.flutter, isNull);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test('builds the app with Riverpod and the app without it', () {
      expect(
        results.map((result) => result.contractCase.name),
        containsAll(['flutter_core', 'riverpod']),
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

  group('an app with Riverpod', () {
    late RenderedApp withRiverpod;
    late RenderedApp without;

    setUpAll(() async {
      withRiverpod = await _appOf(const [RiverpodModule.id]);
      without = await _appOf(const [FlutterCoreModule.id]);
    });

    test('runs the app inside a ProviderScope', () {
      expect(_rootWidgetsOf(withRiverpod), ['ProviderScope', 'App']);
      expect(_rootWidgetsOf(without), ['App']);

      final main = withRiverpod.files[AppEntryRole.mainFile]!;
      final imports = DartFileIndexer.index(main.path, main.text).imports;
      final riverpod = imports.singleWhere(
        (import) =>
            import.uri == 'package:flutter_riverpod/flutter_riverpod.dart',
      );
      expect(riverpod.show, ['ProviderScope']);
      expect(riverpod.prefix, isNull);
    });

    test('depends on flutter_riverpod 3', () {
      expect(_pubspecOf(withRiverpod)['dependencies'], {
        'flutter': {'sdk': 'flutter'},
        'flutter_riverpod': '^3.4.3',
      });
    });

    test('is the app without Riverpod but for the scope and dependency', () {
      expect(withRiverpod.files.keys, orderedEquals(without.files.keys));
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        if (path == 'pubspec.yaml' || path == AppEntryRole.mainFile) continue;
        expect(withRiverpod.files[path]!.bytes, file.bytes, reason: path);
        expect(withRiverpod.files[path]!.owner, file.owner, reason: path);
      }

      final pubspec = _pubspecOf(withRiverpod);
      final dependencies = {
        ...pubspec['dependencies']! as Map<String, Object?>,
      }..remove('flutter_riverpod');
      expect(
        {...pubspec, 'dependencies': dependencies},
        _pubspecOf(without),
      );
    });

    test(
        'has the root wrappers of modules that can use Riverpod inside the '
        'ProviderScope', () async {
      final app = await _appOf(
        const [_StateUser.id, _RiverpodUser.id],
        registry: const [..._modules, _StateUser(), _RiverpodUser()],
      );

      expect(
        _rootWidgetsOf(app),
        ['ProviderScope', 'KeyedSubtree', 'RepaintBoundary', 'App'],
      );
    });
  });
}
