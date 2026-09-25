import 'package:smf_contracts/lego_core.dart';
import 'package:test/test.dart';

import 'support.dart';

String _renderPairs(List<MapEntry<String, String>> entries) =>
    entries.map((entry) => '${entry.key}=${entry.value}').join(';');

String _renderKeys(List<MapEntry<String, NoValue>> entries) =>
    entries.map((entry) => entry.key).join(',');

String _renderValue(String value) => 'v$value';

String _renderRaw(List<MapEntry<String, String>> entries) =>
    entries.map((entry) => entry.value).join();

void main() {
  final role = TestRole<String>('router');
  const module = ModuleId('firebase_core');
  const home = ModuleOrigin(ModuleId('home'));
  const settings = ModuleOrigin(ModuleId('settings'));

  final code = SocketRef<CodeSocket>.role(role, 'setup', const CodeSocket());
  final xml = SocketRef<CodeSocket>.role(role, 'xml', const CodeSocket.text());
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
  final minIos = SocketRef<ValueSocket<String>>.role(
    role,
    'min_ios',
    const ValueSocket(policy: MaxPolicy(), renderer: _renderValue),
  );
  final requiredIos = SocketRef<ValueSocket<String>>.role(
    role,
    'required_ios',
    const ValueSocket(
      policy: MaxPolicy(),
      renderer: _renderValue,
      required: true,
    ),
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

    test('compares by owner, name, kind and family key', () {
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
      expect(
        SocketRef<ArgsSocket>.role(role, 'setup', const ArgsSocket({})),
        isNot(code),
        reason: 'a reference of another kind is another socket',
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

      expect(family.ownerName, 'router');
      expect(family.tagPrefix, 'smf_router__screen_annotations__');
      expect(member.familyKey, ['home', 'home_screen']);
      expect(member.tag, 'smf_router__screen_annotations__home__home_screen');
      expect(member.problems(), isEmpty);
      expect(member, family('home_screen'));
      expect(member, isNot(family('details_screen')));
    });

    test('recognizes the tags of its members', () {
      expect(
        family.memberOfTag('smf_router__screen_annotations__home__home_screen'),
        family('home_screen'),
      );
      expect(family.memberOfTag('smf_router__setup'), isNull);
      expect(family.memberOfTag('smf_router__screen_annotations__'), isNull);
      expect(
        family.memberOfTag('smf_router__screen_annotations__Home'),
        isNull,
      );
    });

    test('recognizes both tags of a wrapper member', () {
      final wrappers = SocketFamily<String, WrapperSocket>.role(
        role,
        'screen_wrappers',
        const WrapperSocket(),
        keyOf: (screen) => [screen],
      );

      expect(
        wrappers.memberOfTag('smf_router__screen_wrappers__home_open'),
        wrappers('home'),
      );
      expect(
        wrappers.memberOfTag('smf_router__screen_wrappers__home_close'),
        wrappers('home'),
      );
      expect(wrappers('home').tags, [
        'smf_router__screen_wrappers__home_open',
        'smf_router__screen_wrappers__home_close',
      ]);
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
      expect(moduleFamily.module, module);
      expect(moduleFamily.name, 'options');
      expect(moduleFamily.kind, const CodeSocket());
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
        (xml, SocketContribution.code(xml, const Fragment('<a/>'))),
        (
          wrapper,
          SocketContribution.wrap(wrapper, const Fragment.wrap('A(', ')')),
        ),
        (
          factories,
          SocketContribution.item(factories, const Fragment('A.new')),
        ),
        (args, SocketContribution.arg(args, 'theme', const Fragment('t'))),
        (keyed, keyed.entry('a', '1.0')),
        (keysOnly, keysOnly.key('INTERNET')),
        (minIos, minIos.value('15.0')),
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

    test('rejects a contribution for a socket of another kind', () {
      final forged =
          SocketRef<ArgsSocket>.role(role, 'setup', const ArgsSocket({}));
      final problems = code.problemsWith(
        SocketContribution.arg(forged, 'theme', const Fragment('t')),
      );

      expect(problems.first, contains('is for the socket router.setup'));
      expect(
        problems,
        contains('socket router.setup takes no argument names.'),
      );
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

    test('rejects imports in a text socket', () {
      expect(
        xml.problemsWith(
          SocketContribution.code(
            xml,
            const Fragment('<a/>', imports: [ImportRef('dart:io')]),
          ),
        ),
        ['socket router.xml is not Dart code and takes no imports.'],
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
      // The value type comes from the static type of the socket, so a
      // wrong value compiles only through an upcast of the socket.
      final wideKeyed = keyed as SocketRef<KeyedSocket<Object>>;
      expect(
        keyed.problemsWith(wideKeyed.entry('a', 1)).single,
        'socket router.plugins takes values of type String, not 1.',
      );

      final wideValue = minIos as SocketRef<ValueSocket<Object>>;
      expect(
        minIos.problemsWith(wideValue.value(15)).single,
        'socket router.min_ios takes values of type String, not 15.',
      );
    });

    test('rejects values the merge policy cannot use', () {
      expect(
        keyed.problemsWith(keyed.entry('a', 'latest')).single,
        contains('"latest" of "a" cannot be compared'),
      );
      expect(
        minIos.problemsWith(minIos.value('x')).single,
        contains('"x" of "smf_router__min_ios" cannot be compared'),
      );
    });

    test('rejects payloads of another kind', () {
      final forged =
          SocketRef<KeyedSocket<String>>.role(role, 'setup', keyed.kind);
      expect(
        code.problemsWith(forged.entry('a', '1.0')),
        contains('socket router.setup takes no keyed entries or values.'),
      );
      expect(
        minIos.problemsWith(keyed.entry('a', '1.0')),
        contains('socket router.min_ios takes a single value.'),
      );
      expect(
        keyed.problemsWith(minIos.value('15.0')),
        contains('socket router.plugins takes keyed entries.'),
      );
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
      expect(code.render(const []), {'smf_router__setup': ''});
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
      expect(args.render(const []), {'smf_router__args': ''});
    });

    test('names both contributors of two values of a scalar argument', () {
      expect(
        () => args.render([
          SocketContribution.arg(args, 'theme', const Fragment('a'))
              .withOrigin(home),
          SocketContribution.arg(args, 'theme', const Fragment('b'))
              .withOrigin(settings),
        ]),
        throwsA(
          isA<MergeConflict>()
              .having((c) => c.existingOrigin, 'existing', home)
              .having((c) => c.incomingOrigin, 'incoming', settings),
        ),
      );
    });

    test('merges keyed entries with the policy, keeping key order', () {
      expect(
        keyed.render([
          keyed.entry('b', '1.0'),
          keyed.entry('a', '2.0'),
          keyed.entry('b', '1.2'),
        ]),
        {'smf_router__plugins': 'b=1.2;a=2.0'},
      );
      expect(
        keysOnly.render([
          keysOnly.key('INTERNET'),
          keysOnly.key('CAMERA'),
          keysOnly.key('INTERNET'),
        ]),
        {'smf_router__permissions': 'INTERNET,CAMERA'},
      );
    });

    test('names the contributors of conflicting keyed entries', () {
      final strict = SocketRef<KeyedSocket<String>>.role(
        role,
        'strict',
        const KeyedSocket(policy: ConflictPolicy(), renderer: _renderPairs),
      );
      expect(
        () => strict.render([
          strict.entry('a', 'x').withOrigin(home),
          strict.entry('a', 'y').withOrigin(settings),
        ]),
        throwsA(
          isA<MergeConflict>()
              .having((c) => c.key, 'key', 'a')
              .having((c) => c.existingOrigin, 'existing', home)
              .having((c) => c.incomingOrigin, 'incoming', settings),
        ),
      );
    });

    test('blames the contributor of the value that won so far', () {
      const third = ModuleOrigin(ModuleId('third'));

      expect(
        () => keyed.render([
          keyed.entry('a', '1.0-jre').withOrigin(home),
          keyed.entry('a', '2.0-jre').withOrigin(settings),
          keyed.entry('a', '2.0-android').withOrigin(third),
        ]),
        throwsA(
          isA<MergeConflict>()
              .having((c) => c.existingOrigin, 'existing', settings)
              .having((c) => c.incomingOrigin, 'incoming', third),
        ),
      );
      expect(
        () => minIos.render([
          minIos.value('13.0-a').withOrigin(home),
          minIos.value('15.0-a').withOrigin(settings),
          minIos.value('15.0-b').withOrigin(third),
        ]),
        throwsA(
          isA<MergeConflict>()
              .having((c) => c.existingOrigin, 'existing', settings)
              .having((c) => c.incomingOrigin, 'incoming', third),
        ),
      );
    });

    test('merges values with the policy', () {
      expect(
        minIos.render([minIos.value('13.0'), minIos.value('15.0')]),
        {'smf_router__min_ios': 'v15.0'},
      );
      expect(minIos.render(const []), {'smf_router__min_ios': ''});
    });

    test('a required value socket needs a contribution', () {
      expect(
        requiredIos.render([requiredIos.value('13.0')]),
        {'smf_router__required_ios': 'v13.0'},
      );
      expect(() => requiredIos.render(const []), throwsStateError);
    });

    test('rejects contributions the socket does not take', () {
      expect(
        () => code.render([
          SocketContribution.code(code, const Fragment.wrap('A(', ')')),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects rendered text that mason would change', () {
      final raw = SocketRef<KeyedSocket<String>>.role(
        role,
        'raw',
        const KeyedSocket(policy: ConflictPolicy(), renderer: _renderRaw),
      );
      expect(() => raw.render([raw.entry('a', r'x\é')]), throwsArgumentError);
    });
  });

  group('socket kinds', () {
    test('only kinds for Dart code carry imports', () {
      expect(const CodeSocket().carriesImports, isTrue);
      expect(const CodeSocket.text().carriesImports, isFalse);
      expect(const WrapperSocket().carriesImports, isTrue);
      expect(const FactoryListSocket().carriesImports, isTrue);
      expect(const ArgsSocket({}).carriesImports, isTrue);
      expect(keyed.kind.carriesImports, isFalse);
      expect(minIos.kind.carriesImports, isFalse);
    });

    test('keyed and value sockets check the type of their values', () {
      final wideKeyed = keyed as SocketRef<KeyedSocket<Object>>;
      final wideValue = minIos as SocketRef<ValueSocket<Object>>;

      expect(keyed.kind.accepts('1.0'), isTrue);
      expect(keyed.kind.accepts(1), isFalse);
      expect(minIos.kind.accepts('15.0'), isTrue);
      expect(minIos.kind.accepts(null), isFalse);
      expect(
        () => keyed.kind.merge([wideKeyed.entry('a', 1)]),
        throwsArgumentError,
      );
      expect(
        () => keyed.kind.merge([minIos.value('15.0')]),
        throwsArgumentError,
      );
      expect(
        () => minIos.kind.merge([wideValue.value(1)], key: 'v'),
        throwsArgumentError,
      );
    });

    test('merge returns the merged entries and value', () {
      expect(
        keyed.kind
            .merge([keyed.entry('a', '1.0'), keyed.entry('a', '1.1')])
            .single
            .value,
        '1.1',
      );
      expect(
        minIos.kind.merge([minIos.value('15'), minIos.value('15.0')], key: 'v'),
        '15',
      );
      expect(minIos.kind.merge(const [], key: 'v'), isNull);
      expect(requiredIos.kind.required, isTrue);
      expect(minIos.kind.required, isFalse);
    });

    test('NoValue is a single value', () {
      expect(const NoValue(), const NoValue());
      expect(const NoValue().hashCode, const NoValue().hashCode);
      expect('${const NoValue()}', 'NoValue');
    });
  });
}
