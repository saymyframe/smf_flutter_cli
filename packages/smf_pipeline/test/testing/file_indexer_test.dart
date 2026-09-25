import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import '../support.dart';

const _source = '''
import 'dart:async';
import 'package:flutter/widgets.dart' show StatelessWidget, Widget;
import 'package:my_app/core/di/service_locator.dart' as di hide Unused;

@immutable
class HomeScreen extends StatelessWidget {
  const HomeScreen({@PathParam('id') required this.id, super.key, String? tab});

  factory HomeScreen.fromJson(Map<String, Object?> json) =>
      HomeScreen(id: json['id']! as int);

  final int id;

  Widget build(BuildContext context) {
    context.nav.home.details(id: 5).go();
    return const Text('home');
  }
}

mixin Loud {}

enum Mode { a, b }

extension type const Meters(double value) {
  Meters.zero() : value = 0;
}

extension Twice on int {}

extension on String {}

typedef Callback = void Function(int);

class Mixed = Object with Loud;

final appRouter = createAppRouter();

int get answer => 42;

set answer(int value) {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await (bootstrap());
  runApp(const App());
  final cubit = di.resolve<HomeCubit>();
  final tearOff = di.resolveWith;
  getIt<A>()..reset()..clear();
  (() => 1)();
  handlers[0]();
  callbacks.first();
  value.handler();
  print(cubit.state.value);
  unawaited(Future(() => tearOff));
}

external void noBody(void callback(int value), [int count = 1]);
''';

void main() {
  final index = DartFileIndexer.index('lib/home.dart', _source);

  test('keeps the path and reports no parse errors', () {
    expect(index.path, 'lib/home.dart');
    expect(DartFileIndexer.errorsOf(_source), isEmpty);
    expect(DartFileIndexer.errorsOf('void main( {'), isNotEmpty);
  });

  test('indexes imports with their combinators', () {
    expect(
      [
        for (final import in index.imports)
          '${import.uri} ${import.prefix} ${import.show} ${import.hide}',
      ],
      [
        'dart:async null [] []',
        'package:flutter/widgets.dart null [StatelessWidget, Widget] []',
        'package:my_app/core/di/service_locator.dart di [] [Unused]',
      ],
    );
  });

  test('indexes the top-level declarations', () {
    expect(
      [for (final d in index.declarations) '${d.name}:${d.kind.name}'],
      [
        'HomeScreen:classType',
        'Loud:mixinType',
        'Mode:enumType',
        'Meters:extensionType',
        'Twice:extension',
        'Callback:typedef',
        'Mixed:classType',
        'appRouter:variable',
        'answer:getter',
        'answer:setter',
        'main:function',
        'noBody:function',
      ],
    );
    expect(index.declaration('HomeScreen')!.annotations, ['@immutable']);
    expect(index.declaration('answer')!.type, 'int');
    expect(index.declaration('appRouter')!.type, isNull);
  });

  test('indexes functions', () {
    final main = index.declaration('main')!;
    expect(main.type, 'Future<void>');
    expect(main.isAsync, isTrue);
    final noBody = index.declaration('noBody')!;
    expect(noBody.isAsync, isFalse);
    expect(
      [for (final p in noBody.parameters) '${p.name} ${p.kind.name} ${p.type}'],
      [
        'callback requiredPositional void callback(int value)',
        'count optionalPositional int',
      ],
    );
  });

  test('indexes constructors and their parameters', () {
    final screen = index.declaration('HomeScreen')!;
    expect(
      [
        for (final c in screen.constructors)
          '${c.name}|${c.isConst}|${c.isFactory}',
      ],
      ['|true|false', 'fromJson|false|true'],
    );
    final parameters = screen.unnamedConstructor!.parameters;
    expect(
      [for (final p in parameters) '${p.name} ${p.kind.name} ${p.type}'],
      [
        // this.id takes the type of its field.
        'id requiredNamed int',
        'key optionalNamed null',
        'tab optionalNamed String?',
      ],
    );
    expect(parameters.first.annotations, ["@PathParam('id')"]);

    final meters = index.declaration('Meters')!;
    expect(
      [for (final c in meters.constructors) '${c.name}|${c.isConst}'],
      ['|true', 'zero|false'],
    );
    expect(meters.unnamedConstructor!.parameters.single.type, 'double');
    expect(index.declaration('Mode')!.constructors, isEmpty);
  });

  test('indexes invocations with targets, arguments and awaits', () {
    String describe(IndexedInvocation i) =>
        '${i.target}.${i.name}<${i.typeArguments.join(',')}>'
        '(${i.namedArguments.join(',')})${i.awaited ? ' awaited' : ''}'
        ' in ${i.enclosingDeclaration}';

    expect(
      index.invocations.map(describe),
      containsAllInOrder([
        'null.HomeScreen<>(id) in HomeScreen',
        'context.nav.home.details(id: 5).go<>() in HomeScreen',
        'context.nav.home.details<>(id) in HomeScreen',
        'null.Text<>() in HomeScreen',
        'null.createAppRouter<>() in appRouter',
        'WidgetsFlutterBinding.ensureInitialized<>() in main',
        'null.bootstrap<>() awaited in main',
        'null.runApp<>() in main',
        'null.App<>() in main',
        'di.resolve<HomeCubit>() in main',
        'null.getIt<A>() in main',
        'getIt<A>().reset<>() in main',
        'getIt<A>().clear<>() in main',
        'callbacks.first<>() in main',
        'value.handler<>() in main',
      ]),
    );
    expect(
      index.invocationsOf('bootstrap', within: 'main').single.awaited,
      isTrue,
    );
    expect(index.invocationsOf('runApp', within: 'other'), isEmpty);
    final order = [
      for (final name in ['ensureInitialized', 'bootstrap', 'runApp'])
        index.invocationsOf(name).single.offset,
    ];
    expect(order, orderedEquals([...order]..sort()));
  });

  test('indexes named constructors called with const or new', () {
    final index = DartFileIndexer.index('lib/a.dart', '''
import 'package:flutter/widgets.dart' as w;

final a = const Duration.zero();
final b = new w.EdgeInsets.all(8);
final c = const w.Text('c');
''');

    expect(
      [for (final i in index.invocations) '${i.target}.${i.name}'],
      ['Duration.zero', 'w.EdgeInsets.all', 'w.Text'],
    );
  });

  test('doc comments and annotations are not uses', () {
    final index = DartFileIndexer.index('lib/a.dart', '''
import 'package:my_app/core/di/service_locator.dart';

/// Registers what [resolve] returns; see [context.nav.settings].
@Target({TargetKind.classType})
@Deprecated(createAnalyticsService)
class A {}
''');

    expect(index.references, isEmpty);
    expect(index.memberAccesses, isEmpty);
    expect(index.invocations, isEmpty);
    expect(index.declaration('A')!.annotations, [
      '@Target({TargetKind.classType})',
      '@Deprecated(createAnalyticsService)',
    ]);
  });

  test('parse returns the index and the errors at once', () {
    final result = DartFileIndexer.parse('lib/b.dart', 'void f( {');

    expect(result.index.path, 'lib/b.dart');
    expect(result.index.declaration('f'), isNotNull);
    expect(result.errors, isNotEmpty);
  });

  test('indexes references and member accesses', () {
    expect(
      [for (final r in index.references) r.name],
      [
        'json',
        'context',
        'WidgetsFlutterBinding',
        'di',
        'di',
        'handlers',
        'callbacks',
        'value',
        'cubit',
        'tearOff',
      ],
    );
    expect(
      [for (final a in index.memberAccesses) '${a.target}.${a.name}'],
      containsAll([
        'context.nav',
        'context.nav.home',
        'di.resolveWith',
        'cubit.state',
        'cubit.state.value',
      ]),
    );
    expect(index.uses('resolveWith'), isTrue);
    expect(index.uses('nav'), isTrue);
    expect(index.uses('missing'), isFalse);
    expect(index.importsUri('dart:async'), isTrue);
  });

  group('runs the structural rules of the roles on parsed code', () {
    List<SmfIssue> appEntryIssues(Map<String, String> files) =>
        appEntryRole.checkStructure(
          StructuralRuleRequest(
            hook: const RoleHookRequest(
              data: [],
              presentRoles: {appEntryRole},
              context: testContext,
            ),
            files: {
              for (final MapEntry(key: path, value: text) in files.entries)
                path: DartFileIndexer.index(path, text),
            },
          ),
        );

    test('app entry: a valid main and bootstrap pass', () {
      expect(
        appEntryIssues({
          'lib/main.dart': '''
import 'package:flutter/widgets.dart';
import 'package:my_app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  runApp(const App());
}
''',
          'lib/bootstrap.dart': '''
import 'package:flutter/foundation.dart';

Future<void> bootstrap() async {}
''',
        }),
        isEmpty,
      );
    });

    test('app entry: order, await and design libraries are checked', () {
      final issues = appEntryIssues({
        'lib/main.dart': '''
Future<void> main() async {
  runApp(const App());
  bootstrap();
  WidgetsFlutterBinding.ensureInitialized();
}
''',
        'lib/bootstrap.dart': '''
import 'package:flutter/material.dart';

Future<void> bootstrap() async {}
''',
      });

      expect(
        [for (final issue in issues) issue.message],
        [
          contains('imports package:flutter/material.dart'),
          'main() does not await bootstrap().',
          contains('in this order'),
        ],
      );
    });

    test('app entry: the required symbols are checked', () {
      final files = {
        'lib/main.dart': DartFileIndexer.index(
          'lib/main.dart',
          'Future<void> main() async {}',
        ),
        'lib/bootstrap.dart': DartFileIndexer.index(
          'lib/bootstrap.dart',
          'void bootstrap() {}',
        ),
      };

      expect(
        [
          for (final issue in appEntryRole.interface.checkSymbols(files))
            issue.message,
        ],
        [
          contains('must return Future<void>'),
          contains('is missing'),
        ],
      );
    });

    test('DI: only composition files resolve services', () {
      const home = ModuleOrigin(ModuleId('home'));
      const infra = ModuleOrigin(ModuleId('infra'));
      final issues = diRole.checkStructure(
        StructuralRuleRequest(
          hook: const RoleHookRequest(
            data: [],
            presentRoles: {diRole},
            context: testContext,
          ),
          files: {
            'lib/features/home/home_composition.dart': DartFileIndexer.index(
              'lib/features/home/home_composition.dart',
              '''
import 'package:my_app/core/di/service_locator.dart' as di;

HomeCubit createHomeCubit() => HomeCubit(di.resolve<AnalyticsService>());
''',
            ),
            'lib/core/infra/infra.dart': DartFileIndexer.index(
              'lib/core/infra/infra.dart',
              '''
import '../di/service_locator.dart';

final service = serviceLocator.resolve<Thing>();
''',
            ),
          },
          owners: {
            'lib/features/home/home_composition.dart': home,
            'lib/core/infra/infra.dart': infra,
          },
          modules: [
            TestModule('home', kind: ModuleKinds.feature, requires: {diRole})
                .descriptor,
            TestModule('infra', kind: ModuleKinds.infrastructure).descriptor,
          ],
        ),
      );

      expect(issues.single.origin, infra);
      expect(issues.single.path, 'lib/core/infra/infra.dart');
    });
  });
}
