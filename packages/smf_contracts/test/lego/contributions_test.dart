import 'package:mason/mason.dart' show MasonBundle;
import 'package:smf_contracts/lego_core.dart';
import 'package:test/test.dart';

import 'support.dart';

final class _Check extends PreflightCheck {
  const _Check();

  @override
  String get id => 'tool';

  @override
  String get description => 'A tool';

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async =>
      const PreflightPassed();
}

void main() {
  final role = TestRole<String>('router');

  test('contributions apply unconditionally by default', () {
    final contributions = <Contribution>[
      BrickContribution(MasonBundle.fromJson(_bundleJson)),
      SocketContribution.code(
        SocketRef<CodeSocket>.role(role, 'setup', const CodeSocket()),
        const Fragment('a();'),
      ),
      RoleData<String>(role, 'data'),
      const PubspecContribution.hosted('a', '^1.0.0'),
      const CodegenRequest(),
      const Preflight([]),
      const PostGenStep(ToolRef('flutter'), ['pub', 'get']),
    ];

    for (final contribution in contributions) {
      expect(contribution.when, isEmpty, reason: '$contribution');
    }
  });

  test('when lists the roles a contribution needs', () {
    final contribution = PubspecContribution.hosted('a', 'any', when: {role});
    expect(contribution.when, {role});
  });

  test('BrickContribution holds a bundle and its variables', () {
    final bundle = MasonBundle.fromJson(_bundleJson);
    final brick = BrickContribution(bundle, vars: const {'screens': 2});

    expect(brick.bundle, same(bundle));
    expect(brick.vars, {'screens': 2});
  });

  group('SocketContribution', () {
    final socket =
        SocketRef<CodeSocket>.role(role, 'setup', const CodeSocket());

    test('code, wrap and item hold a fragment', () {
      const fragment = Fragment('a();');
      final contribution = SocketContribution.code(socket, fragment);

      expect(contribution.socket, socket);
      expect(contribution.fragment, same(fragment));
      expect(contribution.argName, isNull);
      expect(contribution.entryKey, isNull);
      expect(contribution.entryValue, isNull);
    });

    test('arg holds an argument name', () {
      final args = SocketRef<ArgsSocket>.role(
        role,
        'args',
        const ArgsSocket({'theme': ArgShape.scalar}),
      );
      final contribution =
          SocketContribution.arg(args, 'theme', const Fragment('t'));

      expect(contribution.argName, 'theme');
      expect(contribution.fragment?.code, 't');
    });

    test('entry, key and value hold values of the socket type', () {
      String render(List<MapEntry<String, Object>> entries) => '';
      final keyed = SocketRef<KeyedSocket<String>>.role(
        role,
        'keyed',
        KeyedSocket(policy: const ConflictPolicy(), renderer: render),
      );
      final entry = keyed.entry('k', 'v', when: {role});

      expect(entry.socket, keyed);
      expect(entry.entryKey, 'k');
      expect(entry.entryValue, 'v');
      expect(entry.fragment, isNull);
      expect(entry.argName, isNull);
      expect(entry.when, {role});

      final keys = SocketRef<KeyedSocket<NoValue>>.role(
        role,
        'keys',
        KeyedSocket(policy: const ConflictPolicy(), renderer: render),
      );
      final key = keys.key('k', when: {role});
      expect(key.entryValue, const NoValue());
      expect(key.when, {role});

      final value = SocketRef<ValueSocket<String>>.role(
        role,
        'value',
        ValueSocket(policy: const MaxPolicy(), renderer: (v) => v),
      );
      final contribution = value.value('15.0', when: {role});
      expect(contribution.entryKey, isNull);
      expect(contribution.entryValue, '15.0');
      expect(contribution.when, {role});
    });

    test('gets an origin from the pipeline', () {
      final args = SocketRef<ArgsSocket>.role(
        role,
        'args',
        const ArgsSocket({'theme': ArgShape.scalar}),
      );
      final contribution = SocketContribution.arg(
        args,
        'theme',
        const Fragment('t'),
        when: {role},
      );
      expect(contribution.origin, isNull);

      const origin = ModuleOrigin(ModuleId('home'));
      final stamped = contribution.withOrigin(origin);
      expect(stamped.origin, origin);
      expect(stamped.socket, args);
      expect(stamped.argName, 'theme');
      expect(stamped.fragment?.code, 't');
      expect(stamped.when, {role});
    });
  });

  group('RoleData', () {
    test('holds its role and value, and gets an origin from the pipeline', () {
      final data = RoleData<String>(role, 'routes', when: {role});
      expect(data.role, same(role));
      expect(data.value, 'routes');
      expect(data.origin, isNull);

      const origin = ModuleOrigin(ModuleId('home'));
      final stamped = data.withOrigin(origin);
      expect(stamped.origin, origin);
      expect(stamped.value, 'routes');
      expect(stamped.when, {role});
      expect(stamped.role, same(role));
    });
  });

  group('PubspecContribution', () {
    test('hosted dependency', () {
      const dependency = PubspecContribution.hosted('go_router', '^16.3.0');

      expect(dependency, isA<PubspecDependency>());
      dependency as PubspecDependency;
      expect(dependency.package, 'go_router');
      expect(dependency.source, PubspecSource.hosted);
      expect(dependency.constraint, '^16.3.0');
      expect(dependency.dev, isFalse);
      expect(dependency.sdk, isNull);
    });

    test('dev dependency', () {
      const dependency = PubspecContribution.hosted(
        'build_runner',
        '^2.4.0',
        dev: true,
      ) as PubspecDependency;
      expect(dependency.dev, isTrue);
    });

    test('SDK dependency defaults to the flutter SDK', () {
      const dependency = PubspecContribution.sdk('flutter_test', dev: true)
          as PubspecDependency;

      expect(dependency.source, PubspecSource.sdk);
      expect(dependency.sdk, 'flutter');
      expect(dependency.dev, isTrue);
      expect(dependency.constraint, isNull);
    });

    test('git dependency', () {
      const dependency = PubspecContribution.git(
        'a',
        url: 'https://example.com/a.git',
        ref: 'main',
        path: 'packages/a',
      ) as PubspecDependency;

      expect(dependency.source, PubspecSource.git);
      expect(dependency.gitUrl, 'https://example.com/a.git');
      expect(dependency.gitRef, 'main');
      expect(dependency.gitPath, 'packages/a');
      expect(dependency.localPath, isNull);
    });

    test('path dependency', () {
      const dependency =
          PubspecContribution.path('a', '../a') as PubspecDependency;

      expect(dependency.source, PubspecSource.path);
      expect(dependency.localPath, '../a');
      expect(dependency.gitUrl, isNull);
    });

    test('environment', () {
      const environment = PubspecContribution.environment(
        sdk: '^3.8.1',
        flutter: '>=3.32.0',
      ) as PubspecEnvironment;

      expect(environment.sdk, '^3.8.1');
      expect(environment.flutter, '>=3.32.0');
    });

    test('flutter section', () {
      const defaults = PubspecContribution.flutter() as PubspecFlutter;
      expect(defaults.assets, isEmpty);
      expect(defaults.fonts, isEmpty);
      expect(defaults.generate, isFalse);
      expect(defaults.usesMaterialDesign, isFalse);

      const section = PubspecContribution.flutter(
        assets: ['assets/'],
        fonts: [
          PubspecFont('Inter', [
            PubspecFontAsset('fonts/Inter-Bold.ttf', weight: 700),
            PubspecFontAsset('fonts/Inter-Italic.ttf', style: 'italic'),
          ]),
        ],
        generate: true,
        usesMaterialDesign: true,
      ) as PubspecFlutter;

      expect(section.assets, ['assets/']);
      expect(section.fonts.single.family, 'Inter');
      expect(section.fonts.single.assets.first.weight, 700);
      expect(section.fonts.single.assets.last.style, 'italic');
      expect(section.fonts.single.assets.last.asset, 'fonts/Inter-Italic.ttf');
      expect(section.generate, isTrue);
      expect(section.usesMaterialDesign, isTrue);
    });
  });

  test('CodegenRequest explains why it is needed', () {
    expect(const CodegenRequest().description, isNull);
    expect(
      const CodegenRequest(description: 'auto_route').description,
      'auto_route',
    );
  });

  test('Preflight lists its checks in order', () {
    const preflight = Preflight([_Check()]);
    expect(preflight.checks.single.id, 'tool');
  });

  test('PostGenStep runs a tool with arguments', () {
    const step = PostGenStep(
      ToolRef('dart', prefixArgs: ['pub', 'global', 'run', 'x:x']),
      ['configure'],
      description: 'Configure',
      interactive: true,
      skippable: true,
      external: true,
    );

    expect(step.tool.argumentsFor(step.arguments), [
      'pub',
      'global',
      'run',
      'x:x',
      'configure',
    ]);
    expect(step.description, 'Configure');
    expect(step.interactive, isTrue);
    expect(step.skippable, isTrue);
    expect(step.external, isTrue);

    const plain = PostGenStep(ToolRef('flutter'), ['pub', 'get']);
    expect(plain.interactive, isFalse);
    expect(plain.skippable, isFalse);
    expect(plain.external, isFalse);
  });
}

const _bundleJson = <String, dynamic>{
  'files': <dynamic>[],
  'hooks': <dynamic>[],
  'name': 'test',
  'description': 'A test bundle',
  'version': '0.1.0',
  'environment': {'mason': 'any'},
  'vars': <String, dynamic>{},
};
