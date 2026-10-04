import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import '../support.dart';

const _source = '''
import 'dart:async';
import 'package:flutter/widgets.dart' show StatelessWidget, Widget;
import 'package:my_app/core/di/service_locator.dart' as di hide Unused;

export 'home_state.dart' show HomeState;

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
  final tearOff = di.resolve;
  locator<A>()..reset()..clear();
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

  test('indexes imports and exports with their combinators', () {
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
    expect(
      [
        for (final export in index.exports)
          '${export.uri} ${export.prefix} ${export.show}',
      ],
      ['home_state.dart null [HomeState]'],
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

  test('a function-typed parameter has the whole parameter as its type', () {
    final listen = DartFileIndexer.index('lib/listen.dart', '''
void listen(void onData<T>(T value)?, onDone(), [int retry(int n) = once]) {}
''').declaration('listen')!;
    expect(
      [for (final p in listen.parameters) '${p.name}: ${p.type}'],
      [
        'onData: void onData<T>(T value)?',
        'onDone: onDone()',
        // Without its default value.
        'retry: int retry(int n)',
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

  test('indexes the primary constructors of classes and enums', () {
    // Dart 3.13 lets a class or an enum declare its constructor after its
    // name, as an extension type does.
    final index = DartFileIndexer.index('lib/point.dart', '''
class const Point(final int x, [int y = 0]) {
  const Point.origin() : this(0);
}

class Line.between(this.from) {
  final Point from;
}

enum Tone(final String name) { soft('soft') }
''');

    final point = index.declaration('Point')!;
    expect(
      [for (final c in point.constructors) '${c.name}|${c.isConst}'],
      ['|true', 'origin|true'],
    );
    expect(
      [
        for (final p in point.unnamedConstructor!.parameters)
          '${p.name} ${p.kind.name} ${p.type}',
      ],
      ['x requiredPositional int', 'y optionalPositional int'],
    );
    final line = index.declaration('Line')!;
    expect(line.unnamedConstructor, isNull);
    // this.from takes the type of its field.
    expect(line.constructors.single.parameters.single.type, 'Point');
    expect(
      index.declaration('Tone')!.unnamedConstructor!.parameters.single.type,
      'String',
    );
  });

  test('indexes the members that a class declares', () {
    final shell = DartFileIndexer.index('lib/shell.dart', '''
class Shell {
  Shell(this.index);

  static const limit = 3;
  final int index;
  var first = 0, second = 1;
  late final String _label;

  int get count => 0;
  set count(int value) {}
  void select(int index) {}
  static Shell create() => Shell(0);
  bool operator ==(Object other) => false;
  external int get raw;
}
''').declaration('Shell')!;

    expect(
      [
        for (final m in shell.members)
          '${m.name} ${m.kind.name}${m.isStatic ? ' static' : ''}',
      ],
      [
        'limit field static',
        'index field',
        'first field',
        'second field',
        '_label field',
        'count getter',
        'count setter',
        'select method',
        'create method static',
        '== method',
        'raw getter',
      ],
    );
    // A method, a setter and an operator have their parameters.
    expect(
      [
        for (final m in shell.members)
          if (m.parameters.isNotEmpty)
            '${m.name} ${m.kind.name}: ${[
              for (final p in m.parameters) '${p.type} ${p.name}',
            ].join(', ')}',
      ],
      [
        'count setter: int value',
        'select method: int index',
        '== method: Object other',
      ],
    );
  });

  test('an initializing formal of a field without a type has no type', () {
    final counter = DartFileIndexer.index('lib/counter.dart', '''
class Counter {
  Counter(this.count, this.step);

  var count = 0;
  final int step;
}
''').declaration('Counter')!;

    expect(
      [
        for (final p in counter.unnamedConstructor!.parameters)
          '${p.name} ${p.type}',
      ],
      ['count null', 'step int'],
    );
  });

  test('names the extension around a use, and none for an unnamed one', () {
    final extensions = DartFileIndexer.index('lib/extensions.dart', '''
extension Twice on int {
  int twice() => double(this);
}

extension on String {
  String loud() => shout(this);
}
''');

    expect(
      [
        for (final i in extensions.invocations)
          '${i.name} in ${i.enclosingDeclaration}',
      ],
      ['double in Twice', 'shout in null'],
    );
  });

  test(
      'names the method, getter or setter around an invocation, and none '
      'outside the methods of a declaration', () {
    final index = DartFileIndexer.index('lib/panel.dart', '''
class Panel {
  Panel() : created = stamp();

  final Object created;
  final label = describe();

  Widget build(BuildContext context) => Builder(builder: (context) => text());
  int get size => measure();
  set size(int value) => resize(value);
  static Panel create() => const Panel();
}

mixin Loud {
  void shout() => print('loud');
}

extension Twice on int {
  int twice() => double(this);
}

final panel = Panel.create();

void main() => run();
''');

    expect(
      [
        for (final i in index.invocations)
          '${i.name} in ${i.enclosingDeclaration}, ${i.enclosingMember}',
      ],
      [
        // In a constructor and in the initializer of a field.
        'stamp in Panel, null',
        'describe in Panel, null',
        // In a method, also in a closure of it.
        'Builder in Panel, build',
        'text in Panel, build',
        'measure in Panel, size',
        'resize in Panel, size',
        'Panel in Panel, create',
        'print in Loud, shout',
        'double in Twice, twice',
        // In a top-level variable and in a top-level function.
        'create in panel, null',
        'run in main, null',
      ],
    );
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
        'null.locator<A>() in main',
        'locator<A>().reset<>() in main',
        'locator<A>().clear<>() in main',
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
final d = const Box<int>.empty();
''');

    // Without the types resolved, `Duration.zero` may be a type of the
    // import prefix Duration, which type arguments tell apart.
    expect(
      [for (final i in index.invocations) '${i.target}.${i.name}'],
      ['Duration.zero', 'w.EdgeInsets.all', 'w.Text', 'Box.empty'],
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
        'di.resolve',
        'cubit.state',
        'cubit.state.value',
      ]),
    );
    expect(index.uses('resolve'), isTrue);
    expect(index.uses('nav'), isTrue);
    expect(index.uses('missing'), isFalse);
    expect(index.importsUri('dart:async'), isTrue);
  });

  group('runs the structural rules of the roles on parsed code', () {
    List<SmfIssue> appEntryIssues(
      Map<String, String> files, {
      Map<String, ContributionOrigin> owners = const {},
      List<ModuleDescriptor> modules = const [],
    }) =>
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
            owners: owners,
            modules: modules,
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

    test('app entry: the root is a MaterialApp, with or without const', () {
      const provider = ModuleOrigin(ModuleId('scaffold'));
      List<SmfIssue> issuesOf(String root) => appEntryIssues(
            {
              'lib/app.dart': '''
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => $root(title: 'My App');
}
''',
            },
            owners: const {'lib/app.dart': provider},
            modules: [scaffold().descriptor],
          );

      for (final root in [
        'MaterialApp',
        'const MaterialApp',
        'MaterialApp.router',
        'const MaterialApp.router',
      ]) {
        expect(issuesOf(root), isEmpty, reason: root);
      }
      for (final root in ['CupertinoApp', 'CupertinoApp.router']) {
        final issues = issuesOf(root);
        expect(
          issues.map((issue) => issue.message),
          [contains('must be a MaterialApp')],
          reason: root,
        );
        expect(issues.single.origin, provider, reason: root);
      }
    });

    test(
        'app entry: the root MaterialApp is created in a method '
        'build(BuildContext context) of a class', () {
      const provider = ModuleOrigin(ModuleId('scaffold'));
      const outside = 'lib/app.dart creates the root MaterialApp outside a '
          'method build(BuildContext context) of a class, so the arguments '
          'that the modules give the root cannot read its context.';
      List<SmfIssue> issuesOf(String app) => appEntryIssues(
            {'lib/app.dart': "import 'package:flutter/material.dart';\n\n$app"},
            owners: const {'lib/app.dart': provider},
            modules: [scaffold().descriptor],
          );

      for (final app in [
        // In the build() of a widget.
        '''
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(title: 'My App');
}
''',
        // In a closure of it, whose own context rebuilds too.
        '''
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) => const MaterialApp(title: 'My App'));
  }
}
''',
        // In the build() of the state of a widget.
        '''
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  Widget build(BuildContext context) => MaterialApp(title: 'My App');
}
''',
      ]) {
        expect(issuesOf(app), isEmpty, reason: app);
      }

      for (final app in [
        // In another method of the widget, which has no context.
        '''
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => _root();

  Widget _root() => MaterialApp(title: 'My App');
}
''',
        // In a function, a variable or a field, outside any widget.
        "Widget createApp() => MaterialApp(title: 'My App');\n",
        "final app = MaterialApp.router(title: 'My App');\n",
        '''
class App {
  final root = const MaterialApp(title: 'My App');
}
''',
        // In a build() whose context has another name, or none.
        '''
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext ctx) => MaterialApp(title: 'My App');
}
''',
        '''
class App {
  Widget build() => MaterialApp(title: 'My App');
}
''',
        // In such a build(), next to the build(BuildContext context) of
        // another class of the file.
        '''
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => const _Root().build();
}

class _Root {
  const _Root();

  Widget build() => MaterialApp(title: 'My App');
}
''',
        // In a function, next to the root in the build() of a widget: every
        // MaterialApp of the provider counts.
        '''
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(title: 'My App');
}

Widget preview() => MaterialApp(title: 'Preview');
''',
      ]) {
        final issues = issuesOf(app);
        expect(issues.map((issue) => issue.message), [outside], reason: app);
        expect(issues.single.origin, provider, reason: app);
        expect(issues.single.path, 'lib/app.dart', reason: app);
      }
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

    test('layout: the app shell keeps public what code of the role reads', () {
      List<String> problemsOf(String shell) => [
            for (final issue in LayoutRole.appShell.checkIn({
              LayoutRole.appShellFile:
                  DartFileIndexer.index(LayoutRole.appShellFile, shell),
            }))
              issue.message,
          ];

      // Public fields, as the shell of bottom_tabs has.
      expect(
        problemsOf('''
class AppShell extends StatelessWidget {
  const AppShell({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.body,
    super.key,
  });

  final List<Destination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
}
'''),
        isEmpty,
      );
      // Getters of private fields. The body, which the shell only shows,
      // may stay private.
      expect(
        problemsOf('''
class AppShell extends StatelessWidget {
  const AppShell({
    required List<Destination> destinations,
    required int currentIndex,
    required ValueChanged<int> onSelect,
    required Widget body,
    super.key,
  })  : _destinations = destinations,
        _currentIndex = currentIndex,
        _onSelect = onSelect,
        _body = body;

  final List<Destination> _destinations;
  final int _currentIndex;
  final ValueChanged<int> _onSelect;
  final Widget _body;

  List<Destination> get destinations => _destinations;
  int get currentIndex => _currentIndex;
  ValueChanged<int> get onSelect => _onSelect;
}
'''),
        isEmpty,
      );
      // Private fields alone, which code outside the library cannot read,
      // although the constructor takes what the router passes.
      const prefix = 'class AppShell in lib/core/layout/app_shell.dart must';
      expect(
        problemsOf('''
class AppShell extends StatelessWidget {
  const AppShell({
    required List<Destination> destinations,
    required int currentIndex,
    required ValueChanged<int> onSelect,
    required Widget body,
    super.key,
  })  : _destinations = destinations,
        _currentIndex = currentIndex,
        _onSelect = onSelect,
        _body = body;

  final List<Destination> _destinations;
  final int _currentIndex;
  final ValueChanged<int> _onSelect;
  final Widget _body;
}
'''),
        [
          for (final getter in ['destinations', 'currentIndex', 'onSelect'])
            '$prefix declare the public instance field or getter $getter.',
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
