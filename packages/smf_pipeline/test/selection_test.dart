import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final nav = TestRole<NoDsl>('nav');
  final shell = TestRole<NoDsl>('shell', requires: {nav});
  final tracking = TestRole<NoDsl>(
    'tracking',
    cardinality: RoleCardinality.many,
  );
  final registry = ModuleRegistry([
    scaffold(),
    TestModule('home', requires: {nav}),
    TestModule('about'),
    TestModule(
      'firebase',
      kind: const ModuleKind(id: 'infra', label: 'Infrastructure'),
    ),
    TestModule('go', providers: [RoleProvider.plain(nav)]),
    TestModule('auto', providers: [RoleProvider.plain(nav)]),
    TestModule('tabs', providers: [RoleProvider.plain(shell)]),
    TestModule('a1', providers: [RoleProvider.plain(tracking)]),
    TestModule('a2', providers: [RoleProvider.plain(tracking)]),
  ]);

  List<String> ids(Selection selection) =>
      selection.requested.map((id) => id.value).toList();

  group('without a terminal', () {
    test('needs the app name', () {
      final host = FakeHost();

      expect(
        select(const CreateRequest(), registry, host.environment()),
        throwsA(isA<SmfUsageException>()),
      );
    });

    test('takes the modules of -m and the default organization', () async {
      final host = FakeHost();
      final selection = await select(
        const CreateRequest(
          appName: 'My App',
          modules: [ModuleId('home'), ModuleId('go')],
        ),
        registry,
        host.environment(),
      );

      expect(selection.appName, 'My App');
      expect(selection.org, 'com.example');
      expect(ids(selection), ['home', 'go']);
      expect(selection.declined, isEmpty);
      expect(selection.target.path, '/work/my_app');
      expect(selection.target.replaceExisting, isFalse);
      expect(selection.target.conflict, isFalse);
    });

    test('without -m asks for no modules', () async {
      final host = FakeHost();
      final selection = await select(
        const CreateRequest(appName: 'app', org: 'org.acme'),
        registry,
        host.environment(),
      );

      expect(selection.requested, isEmpty);
      expect(selection.org, 'org.acme');
      expect(host.logger.infos.single, contains('No modules were given'));
    });

    test('rejects unknown modules with a suggestion', () {
      expect(
        select(
          const CreateRequest(appName: 'app', modules: [ModuleId('hme')]),
          registry,
          FakeHost().environment(),
        ),
        throwsA(
          isA<SmfUsageException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Did you mean home?'), contains('Modules: ')),
          ),
        ),
      );
      expect(
        select(
          const CreateRequest(appName: 'app', modules: [ModuleId('abot')]),
          registry,
          FakeHost().environment(),
        ),
        throwsA(
          isA<SmfUsageException>().having(
            (e) => e.message,
            'message',
            contains('Did you mean about?'),
          ),
        ),
      );
      expect(
        select(
          const CreateRequest(appName: 'app', modules: [ModuleId('zzzzzz')]),
          registry,
          FakeHost().environment(),
        ),
        throwsA(
          isA<SmfUsageException>().having(
            (e) => e.message,
            'message',
            isNot(contains('Did you mean')),
          ),
        ),
      );
    });

    test('rejects an invalid organization', () {
      expect(
        select(
          const CreateRequest(appName: 'app', org: '1.2'),
          registry,
          FakeHost().environment(),
        ),
        throwsA(isA<SmfUsageException>()),
      );
    });
  });

  group('the target directory', () {
    Future<TargetDecision> decide(
      FakeHost host, {
      OnConflict onConflict = OnConflict.prompt,
      bool explain = false,
      bool interactive = false,
    }) async =>
        (await select(
          CreateRequest(
            appName: 'app',
            org: 'com.example',
            outputDirectory: 'out',
            onConflict: onConflict,
            explain: explain,
            modules: const [],
          ),
          registry,
          host.environment(interactive: interactive),
        ))
            .target;

    FakeHost withExisting() {
      final host = FakeHost();
      host.fileSystem
          .file('/work/out/app/lib/main.dart')
          .createSync(recursive: true);
      return host;
    }

    test('an empty directory is no conflict', () async {
      final host = FakeHost();
      host.fileSystem.directory('/work/out/app').createSync(recursive: true);

      final target = await decide(host);

      expect(target.path, '/work/out/app');
      expect(target.conflict, isFalse);
    });

    test('a file is in the way', () {
      final host = FakeHost();
      host.fileSystem.file('/work/out/app').createSync(recursive: true);

      expect(decide(host), throwsA(isA<SmfUsageException>()));
    });

    test('--explain only reports the conflict', () async {
      final target = await decide(withExisting(), explain: true);

      expect(target.conflict, isTrue);
      expect(target.replaceExisting, isFalse);
    });

    test('replace replaces it after generation', () async {
      final host = withExisting();
      final target = await decide(host, onConflict: OnConflict.replace);

      expect(target.path, '/work/out/app');
      expect(target.replaceExisting, isTrue);
      expect(host.logger.warnings.single, contains('will be replaced'));
      expect(
        host.fileSystem.file('/work/out/app/lib/main.dart').existsSync(),
        isTrue,
      );
    });

    test('copy picks a free directory next to it', () async {
      final host = withExisting();
      expect(
        (await decide(host, onConflict: OnConflict.copy)).path,
        '/work/out/app copy',
      );
      host.fileSystem.directory('/work/out/app copy').createSync();
      host.fileSystem.file('/work/out/app copy 2').createSync();
      expect(
        (await decide(host, onConflict: OnConflict.copy)).path,
        '/work/out/app copy 3',
      );
    });

    test('cancel stops generation', () {
      expect(
        decide(withExisting(), onConflict: OnConflict.cancel),
        throwsA(isA<GenerationFailedException>()),
      );
    });

    test('prompt needs a terminal', () {
      expect(
        decide(withExisting()),
        throwsA(
          isA<SmfUsageException>().having(
            (e) => e.message,
            'message',
            contains('--on-conflict'),
          ),
        ),
      );
    });

    test('prompt asks the user', () async {
      final replace = FakeHost(answers: ['Replace']);
      replace.fileSystem.file('/work/out/app/a').createSync(recursive: true);

      final target = await decide(replace, interactive: true);

      expect(target.replaceExisting, isTrue);
      expect(replace.prompter.asked.single.shown, [
        'Replace it with the new app',
        'Keep it and create the app next to it',
        'Cancel',
      ]);

      final cancel = FakeHost(answers: ['Cancel']);
      cancel.fileSystem.file('/work/out/app/a').createSync(recursive: true);
      expect(
        decide(cancel, interactive: true),
        throwsA(isA<GenerationFailedException>()),
      );
    });
  });

  group('in a terminal', () {
    Future<(Selection, FakeHost)> run(List<Object?> answers) async {
      final host = FakeHost(answers: answers, terminal: true);
      final selection = await select(
        const CreateRequest(),
        registry,
        host.environment(),
      );
      expect(host.prompter.done, isTrue);
      return (selection, host);
    }

    test('asks for everything', () async {
      final (selection, host) = await run([
        'Cool App', // name
        null, // organization: the default
        ['home'], // plain modules
        ['firebase'], // infrastructure
        'tabs', // shell
        'go', // nav, required by home and the shell
        ['a1'], // tracking
      ]);

      expect(selection.appName, 'Cool App');
      expect(selection.org, 'com.example');
      expect(selection.target.path, '/work/cool_app');
      expect(
        ids(selection),
        ['home', 'firebase', 'scaffold', 'tabs', 'go', 'a1'],
      );
      expect(selection.declined, isEmpty);

      final asked = host.prompter.asked;
      expect(asked.map((p) => p.kind), [
        'input',
        'input',
        'multiSelect',
        'multiSelect',
        'select',
        'select',
        'multiSelect',
      ]);
      expect(asked[2].message, startsWith('Plain modules'));
      expect(asked[2].shown, [
        'home — The module home',
        'about — The module about',
      ]);
      expect(asked[3].message, startsWith('Infrastructure'));
      expect(asked[4].shown, contains('None'));
      expect(asked[5].shown, isNot(contains('None')));
      expect(
        host.logger.infos,
        contains('Adding scaffold: every app needs the app_entry.'),
      );
    });

    test('takes the only provider of a required role', () async {
      final nav = TestRole<NoDsl>('nav');
      final registry = ModuleRegistry([
        scaffold(),
        TestModule('home', requires: {nav}),
        TestModule('go', providers: [RoleProvider.plain(nav)]),
      ]);
      final host = FakeHost(
        answers: [
          ['home'],
        ],
        terminal: true,
      );

      final selection = await select(
        const CreateRequest(appName: 'app', org: 'com.example'),
        registry,
        host.environment(),
      );

      expect(ids(selection), ['home', 'scaffold', 'go']);
      expect(
        host.logger.infos,
        contains('Adding go: home requires the nav.'),
      );
    });

    test('records roles declined with "None"', () async {
      final (selection, _) = await run([
        'app',
        'com.example',
        <String>[],
        <String>[],
        'None', // shell
        'None', // nav, not required now
        <String>[], // tracking
      ]);

      expect(ids(selection), ['scaffold']);
      expect(selection.declined, {shell, nav, tracking});
    });

    test('a required role with many providers needs one', () {
      final tracking = TestRole<NoDsl>(
        'tracking',
        cardinality: RoleCardinality.many,
      );
      final registry = ModuleRegistry([
        scaffold(),
        TestModule('home', requires: {tracking}),
        TestModule('a1', providers: [RoleProvider.plain(tracking)]),
        TestModule('a2', providers: [RoleProvider.plain(tracking)]),
      ]);
      final host = FakeHost(
        answers: [
          ['home'],
          <String>[],
        ],
        terminal: true,
      );

      expect(
        select(
          const CreateRequest(appName: 'app', org: 'com.example'),
          registry,
          host.environment(),
        ),
        throwsA(isA<SmfUsageException>()),
      );
    });

    test('names the role of a provider that requires another', () async {
      final nav = TestRole<NoDsl>('nav');
      final shell = TestRole<NoDsl>('shell', requires: {nav});
      final registry = ModuleRegistry([
        scaffold(),
        TestModule('tabs', providers: [RoleProvider.plain(shell)]),
        TestModule('go', providers: [RoleProvider.plain(nav)]),
        TestModule('auto', providers: [RoleProvider.plain(nav)]),
      ]);
      final host = FakeHost(answers: ['tabs', 'auto'], terminal: true);

      final selection = await select(
        const CreateRequest(appName: 'app', org: 'com.example'),
        registry,
        host.environment(),
      );

      expect(ids(selection), ['scaffold', 'tabs', 'auto']);
      expect(host.prompter.asked.last.shown, isNot(contains('None')));
    });
  });
}
