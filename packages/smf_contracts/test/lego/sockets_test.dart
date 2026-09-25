import 'package:smf_contracts/lego_core.dart';
import 'package:test/test.dart';

import 'support.dart';

String _renderPairs(List<MapEntry<String, String>> entries) =>
    entries.map((entry) => '${entry.key}=${entry.value}').join(';');

String _renderKeys(List<MapEntry<String, NoValue>> entries) =>
    entries.map((entry) => entry.key).join(',');

String _renderValue(String value) => 'v$value';

void main() {
  final role = TestRole<String>('router');
  const module = ModuleId('firebase_core');

  final code = SocketRef<CodeSocket>.role(role, 'setup', const CodeSocket());
  final wrapper =
      SocketRef<WrapperSocket>.role(role, 'wrappers', const WrapperSocket());
  final factories = SocketRef<FactoryListSocket>.role(
    role,
    'observers',
    const FactoryListSocket(),
  );
  final args = SocketRef<ArgsSocket>.role(
    role,
    'args',
    const ArgsSocket({'theme': ArgShape.scalar, 'locales': ArgShape.list}),
  );
  final keyed = SocketRef<KeyedSocket<String>>.role(
    role,
    'plugins',
    const KeyedSocket(policy: MaxPolicy(), renderer: _renderPairs),
  );
  final keysOnly = SocketRef<KeyedSocket<NoValue>>.role(
    role,
    'permissions',
    const KeyedSocket(policy: ConflictPolicy(), renderer: _renderKeys),
  );
  final value = SocketRef<ValueSocket<String>>.role(
    role,
    'min_ios',
    const ValueSocket(policy: MaxPolicy(), renderer: _renderValue),
  );

  group('SocketRef', () {
    test('names tags after the owner and the socket', () {
      expect(code.tag, 'smf_router__setup');
      expect(code.tags, ['smf_router__setup']);
      expect(
        const SocketRef<CodeSocket>.module(module, 'after_init', CodeSocket())
            .tag,
        'smf_firebase_core__after_init',
      );
      expect(
        PipelineSockets.pubspecDependencies.tag,
        'smf_pubspec_dependencies',
      );
    });

    test('a wrapper socket has an opening and a closing tag', () {
      expect(
        wrapper.tags,
        ['smf_router__wrappers_open', 'smf_router__wrappers_close'],
      );
    });

    test('knows its owner', () {
      expect(code.role, same(role));
      expect(code.module, isNull);
      expect(code.ownerName, 'router');
      expect(code.isPipeline, isFalse);

      const moduleSocket =
          SocketRef<CodeSocket>.module(module, 'after_init', CodeSocket());
      expect(moduleSocket.role, isNull);
      expect(moduleSocket.module, module);
      expect(moduleSocket.ownerName, 'firebase_core');

      const pipeline = PipelineSockets.pubspecFlutter;
      expect(pipeline.isPipeline, isTrue);
      expect(pipeline.ownerName, 'pipeline');
      expect(pipeline.kind.carriesImports, isFalse);
    });

    test('compares by owner, name and family key, not by kind', () {
      expect(
        SocketRef<CodeSocket>.role(role, 'setup', const CodeSocket()),
        code,
      );
      expect(
        SocketRef<CodeSocket>.role(role, 'setup', const CodeSocket()).hashCode,
        code.hashCode,
      );
      expect(
        SocketRef<CodeSocket>.role(
          TestRole<String>('router'),
          'setup',
          const CodeSocket(),
        ),
        isNot(code),
        reason: 'roles compare by identity',
      );
      expect(
        const SocketRef<CodeSocket>.module(module, 'setup', CodeSocket()),
        isNot(code),
      );
    });

    test('reports names that are not lower snake_case', () {
      expect(code.problems(), isEmpty);
      final bad = SocketRef<CodeSocket>.role(role, 'Setup', const CodeSocket());
      expect(bad.problems().single, contains('"Setup"'));
    });

    test('describes itself', () {
      expect('$code', 'socket router.setup');
    });
  });

  group('SocketFamily', () {
    final family = SocketFamily<String, CodeSocket>.role(
      role,
      'screen_annotations',
      const CodeSocket(),
      keyOf: (screen) => ['home', screen],
    );

    test('creates members whose tags end with the key', () {
      final member = family('home_screen');

      expect(member.familyKey, ['home', 'home_screen']);
      expect(member.tag, 'smf_router__screen_annotations__home__home_screen');
      expect(member.problems(), isEmpty);
      expect(member, family('home_screen'));
      expect(member, isNot(family('details_screen')));
    });

    test('module families belong to the module', () {
      final moduleFamily = SocketFamily<int, CodeSocket>.module(
        module,
        'options',
        const CodeSocket(),
        keyOf: (i) => ['n$i'],
      );
      expect(moduleFamily(1).tag, 'smf_firebase_core__options__n1');
      expect(moduleFamily.role, isNull);
    });

    test('rejects keys that are empty or not lower snake_case', () {
      final bad = SocketFamily<List<String>, CodeSocket>.role(
        role,
        'bad',
        const CodeSocket(),
        keyOf: (key) => key,
      );

      expect(() => bad(const []), throwsArgumentError);
      expect(() => bad(const ['HomeScreen']), throwsArgumentError);
    });
  });

  group('PipelineSockets', () {
    test('lists the pubspec sections', () {
      expect(PipelineSockets.all.map((s) => s.tag), [
        'smf_pubspec_environment',
        'smf_pubspec_dependencies',
        'smf_pubspec_dev_dependencies',
        'smf_pubspec_flutter',
      ]);
    });

    test('take no contributions', () {
      final contribution = SocketContribution.code(
        code,
        const Fragment('x'),
      );
      expect(
        PipelineSockets.pubspecDependencies.problemsWith(contribution).last,
        contains('filled by the pipeline'),
      );
      expect(
        () => PipelineSockets.pubspecDependencies.render(const []),
        throwsStateError,
      );
    });
  });

  group('SocketRef.problemsWith', () {
    test('accepts contributions made for the socket', () {
      final valid = [
        (code, SocketContribution.code(code, const Fragment('a();'))),
        (
          wrapper,
          SocketContribution.wrap(wrapper, const Fragment.wrap('A(', ')')),
        ),
        (
          factories,
          SocketContribution.item(factories, const Fragment('A.new'))
        ),
        (args, SocketContribution.arg(args, 'theme', const Fragment('t'))),
        (keyed, SocketContribution.entry(keyed, 'a', '1.0')),
        (keysOnly, SocketContribution.key(keysOnly, 'INTERNET')),
        (value, SocketContribution.value(value, '15.0')),
      ];
      for (final (socket, contribution) in valid) {
        expect(socket.problemsWith(contribution), isEmpty, reason: '$socket');
      }
    });

    test('rejects a contribution for another socket', () {
      final problems = code.problemsWith(
        SocketContribution.code(
          SocketRef<CodeSocket>.role(role, 'other', const CodeSocket()),
          const Fragment('a();'),
        ),
      );
      expect(problems.single, contains('socket router.other'));
    });

    test('rejects fragments of the wrong shape', () {
      expect(
        code.problemsWith(
          SocketContribution.code(code, const Fragment.wrap('A(', ')')),
        ),
        ['socket router.setup takes a Fragment of code.'],
      );
      expect(
        wrapper.problemsWith(
          SocketContribution.wrap(wrapper, const Fragment('A()')),
        ),
        ['socket router.wrappers takes a Fragment.wrap.'],
      );
      expect(
        args.problemsWith(
          SocketContribution.arg(args, 'theme', const Fragment.wrap('A(', ')')),
        ),
        ['socket router.args takes a Fragment of code.'],
      );
    });

    test('rejects an unknown argument', () {
      final problems = args.problemsWith(
        SocketContribution.arg(args, 'darkTeme', const Fragment('t')),
      );
      expect(
        problems.single,
        'socket router.args has no argument "darkTeme"; '
        'expected one of theme, locales.',
      );
    });

    test('rejects values of the wrong type', () {
      // A contribution can reach a socket of another value type only
      // through an upcast, which the static factories cannot prevent.
      final wrongKeyed = SocketContribution.entry<Object>(
        keyed as SocketRef<KeyedSocket<Object>>,
        'a',
        1,
      );
      expect(keyed.problemsWith(wrongKeyed).single, contains('right type'));

      final wrongValue = SocketContribution.value<Object>(
        value as SocketRef<ValueSocket<Object>>,
        15,
      );
      expect(value.problemsWith(wrongValue).single, contains('right type'));
    });

    test('reports the problems of the fragment', () {
      expect(
        code
            .problemsWith(
              SocketContribution.code(code, const Fragment('a \\\nb')),
            )
            .single,
        contains('backslash'),
      );
    });
  });

  group('SocketRef.render', () {
    test('renders code fragments one per line', () {
      expect(
        code.render([
          SocketContribution.code(code, const Fragment('a();')),
          SocketContribution.code(code, const Fragment('b();')),
        ]),
        {'smf_router__setup': 'a();\nb();'},
      );
    });

    test('nests wrappers, the first one outermost', () {
      expect(
        wrapper.render([
          SocketContribution.wrap(
            wrapper,
            const Fragment.wrap('A(child: ', ')'),
          ),
          SocketContribution.wrap(
            wrapper,
            const Fragment.wrap('B(child: ', ']'),
          ),
        ]),
        {
          'smf_router__wrappers_open': 'A(child: B(child: ',
          'smf_router__wrappers_close': '])',
        },
      );
    });

    test('renders factories as list items', () {
      expect(
        factories.render([
          SocketContribution.item(factories, const Fragment('() => A()')),
          SocketContribution.item(factories, const Fragment('() => B()')),
        ]),
        {'smf_router__observers': '() => A(),\n() => B(),'},
      );
    });

    test('renders arguments in declaration order and unites lists', () {
      expect(
        args.render([
          SocketContribution.arg(
            args,
            'locales',
            const Fragment("Locale('en')"),
          ),
          SocketContribution.arg(args, 'theme', const Fragment('t')),
          SocketContribution.arg(
            args,
            'locales',
            const Fragment("Locale('uk')"),
          ),
          SocketContribution.arg(
            args,
            'locales',
            const Fragment("Locale('en')"),
          ),
          SocketContribution.arg(args, 'theme', const Fragment('t')),
        ]),
        {
          'smf_router__args':
              "theme: t,\nlocales: [Locale('en'), Locale('uk')],",
        },
      );
    });

    test('renders no arguments as an empty string', () {
      expect(args.render(const []), {'smf_router__args': ''});
    });

    test('rejects two values of a scalar argument', () {
      expect(
        () => args.render([
          SocketContribution.arg(args, 'theme', const Fragment('a')),
          SocketContribution.arg(args, 'theme', const Fragment('b')),
        ]),
        throwsA(isA<MergeConflict>()),
      );
    });

    test('merges keyed entries with the policy, keeping key order', () {
      expect(
        keyed.render([
          SocketContribution.entry(keyed, 'b', '1.0'),
          SocketContribution.entry(keyed, 'a', '2.0'),
          SocketContribution.entry(keyed, 'b', '1.2'),
        ]),
        {'smf_router__plugins': 'b=1.2;a=2.0'},
      );
      expect(
        keysOnly.render([
          SocketContribution.key(keysOnly, 'INTERNET'),
          SocketContribution.key(keysOnly, 'CAMERA'),
          SocketContribution.key(keysOnly, 'INTERNET'),
        ]),
        {'smf_router__permissions': 'INTERNET,CAMERA'},
      );
    });

    test('merges values with the policy', () {
      expect(
        value.render([
          SocketContribution.value(value, '13.0'),
          SocketContribution.value(value, '15.0'),
        ]),
        {'smf_router__min_ios': 'v15.0'},
      );
      expect(value.render(const []), {'smf_router__min_ios': ''});
    });

    test('rejects contributions the socket does not take', () {
      expect(
        () => code.render([
          SocketContribution.code(code, const Fragment.wrap('A(', ')')),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('socket kinds', () {
    test('only fragment kinds carry imports', () {
      expect(const CodeSocket().carriesImports, isTrue);
      expect(const WrapperSocket().carriesImports, isTrue);
      expect(const FactoryListSocket().carriesImports, isTrue);
      expect(const ArgsSocket({}).carriesImports, isTrue);
      expect(keyed.kind.carriesImports, isFalse);
      expect(value.kind.carriesImports, isFalse);
    });

    test('keyed and value sockets check the type of their values', () {
      expect(keyed.kind.accepts('1.0'), isTrue);
      expect(keyed.kind.accepts(1), isFalse);
      expect(value.kind.accepts('15.0'), isTrue);
      expect(value.kind.accepts(null), isFalse);
      expect(() => keyed.kind.merge([('a', 1)]), throwsArgumentError);
      expect(() => value.kind.merge([1], key: 'v'), throwsArgumentError);
    });

    test('an args socket rejects an unknown argument when rendering', () {
      expect(
        () => const ArgsSocket({}).render([('theme', const Fragment('t'))]),
        throwsArgumentError,
      );
    });

    test('NoValue is a single value', () {
      expect(const NoValue(), const NoValue());
      expect(const NoValue().hashCode, const NoValue().hashCode);
      expect('${const NoValue()}', 'NoValue');
    });
  });
}
