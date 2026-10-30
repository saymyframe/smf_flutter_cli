@TestOn('vm')
library;

import 'dart:io';

import 'package:smf_contracts/bundles/ci_role_env_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'support.dart';

const _shopKey = EnvKey('SHOP_KEY', description: 'The public key of the shop');
const _feedUrl = EnvKey('FEED_URL', description: 'The address of the feed');

/// The data of an app with the env role: two keys and the tool arguments of
/// its provider, each given as one argument.
final List<RoleData<Object>> _envData = [
  dataOf<EnvData>(envRole, _shopKey, module: 'shop'),
  dataOf<EnvData>(envRole, _feedUrl, module: 'feed'),
  dataOf<EnvData>(
    envRole,
    const EnvToolArguments(['--dart-define-from-file=.env']),
    module: 'env_provider',
  ),
];

/// The input of the hooks of the role in an app with the env role and the
/// keys and arguments of [_envData].
RoleHookInput<NoDsl> _withEnv() =>
    inputOf(ciRole, data: _envData, present: {envRole});

/// The commands of [commands].
List<String> _commandsOf(List<CiCommand> commands) => [
      for (final command in commands) command.command,
    ];

const _ciFile = 'pipelines/ci.txt';

/// A provider with a format of its own: a step of a list for each command,
/// each key once, the environments on one line, and a variable of its host in
/// place of the name of the environment. Its file has the path of the artifact
/// inside a list on one line, and quotes around a command.
String _listsOfCommands(CiPipeline pipeline) {
  final build = pipeline.build;
  return [
    '# The CI of the app.',
    'on_push:',
    '  script:',
    for (final check in pipeline.checks) '    - "${check.command}"',
    'on_request:',
    '  environments: [${build.environments.join(', ')}]',
    '  variables:',
    for (final key in build.keys) '    $key: { value: "" }',
    '  script:',
    for (final command in build.prepare) '    - ${command.command}',
    '    - ${build.command.of(r'$ENVIRONMENT')}',
    '  keep: { paths: ["${build.artifact.of(r'$ENVIRONMENT')}"] }',
    '',
  ].join('\n');
}

/// A provider with another format: a block for each environment, which has
/// the name of its environment in its commands, and a comment of the other
/// kind.
String _blocksOfEnvironments(CiPipeline pipeline) {
  final build = pipeline.build;
  return [
    '// The CI of the app.',
    'push',
    for (final check in pipeline.checks) '  ${check.name} = ${check.command}',
    for (final environment in build.environments) ...[
      'request $environment',
      for (final key in build.keys) '  variable $key',
      for (final command in build.prepare)
        '  ${command.name} = ${command.command}',
      '  ${build.name} = ${build.command.of(environment)}',
      '  keep ${build.artifact.of(environment)}',
    ],
    '',
  ].join('\n');
}

/// A provider for the tests of the rule, whose hook writes what [write] makes
/// of the pipeline of the app into [_ciFile], or nothing for `null`.
final class _Provider extends RoleProvider<NoDsl> {
  const _Provider(this.write);

  final String Function(CiPipeline pipeline)? write;

  @override
  Role<NoDsl> get role => ciRole;

  @override
  RoleOutput render(RoleHookInput<NoDsl> input) => RoleOutput(
        files: {
          if (write case final write?) _ciFile: write(ciRole.pipelineIn(input)),
        },
      );
}

const _providerId = ModuleId('ci_provider');

/// What the rule says of the file that [write] makes for an app with [input].
/// Each problem is its message.
List<String> _problemsOf(
  String Function(CiPipeline pipeline)? write,
  RoleHookInput<NoDsl> input, {
  required bool hasEnv,
}) {
  final provider = _Provider(write);
  final files = provider.render(input).files;
  final issues = ciRole.checkStructure(
    StructuralRuleRequest(
      hook: RoleHookRequest(
        data: hasEnv ? _envData : const [],
        presentRoles: {ciRole, if (hasEnv) envRole},
        context: testContext,
      ),
      files: const {},
      texts: files,
      owners: {
        for (final path in files.keys) path: const ModuleOrigin(_providerId),
      },
      modules: [
        ModuleDescriptor(
          id: _providerId,
          description: 'A provider of the role',
          kind: plainKind,
          providers: [provider],
        ),
      ],
    ),
  );
  for (final issue in issues) {
    expect(issue.origin, const ModuleOrigin(_providerId));
  }
  return [for (final issue in issues) issue.message];
}

const _prefix = 'The files of the provider of the CI role have';

/// What the rule says of [command], which no line of the files ends with.
String _noLineWith(String command) =>
    '$_prefix no line that ends with `$command`.';

/// What the rule says of the files of a provider without the command of the
/// build, in an app with the arguments of [_envData].
const _noBuildCommand = '$_prefix no line that ends with the command of the '
    'build, `flutter build apk --release --flavor <environment> '
    '--dart-define-from-file=.env`.';

/// What the rule says of the files of a provider without the file of the
/// build.
const _noArtifact = '$_prefix no line with the file of the build, '
    '`build/app/outputs/flutter-apk/app-<environment>-release.apk`.';

/// The problems of what [edit] leaves of the file of [_listsOfCommands], in an
/// app with the env role, whose text has to change for the test to mean
/// anything.
List<String> _problemsAfter(String Function(String text) edit) => _problemsOf(
      (pipeline) {
        final text = _listsOfCommands(pipeline);
        final edited = edit(text);
        expect(edited, isNot(text));
        return edited;
      },
      _withEnv(),
      hasEnv: true,
    );

void main() {
  group('the CI role', () {
    test(
        'has at most one provider, since a repository lives on one host, and '
        'works with the env role when the app has it', () {
      expect(ciRole.id, 'ci');
      expect(ciRole.description, 'CI');
      expect('$ciRole', 'CI role');
      expect(ciRole.presenceFlag, 'has_ci');
      expect(ciRole.cardinality, RoleCardinality.atMostOne);
      expect(ciRole.requires, isEmpty);
      expect(ciRole.uses, {envRole});
      expect(ciRole.openToAllModules, isFalse);
      expect(ciRole.sockets, isEmpty);
      expect(ciRole.options, isEmpty);
      expect(ciRole.moduleRules, isEmpty);
      expect(CiRole.readmeHeading, 'Continuous integration');
      expect(CiRole.writeEnvFile, 'tool/write_env.dart');
    });

    test('names no file and no symbol that a provider has to generate', () {
      expect(ciRole.interface.files, isEmpty);
      expect(ciRole.interface.symbols, isEmpty);
    });

    test('names no host, in its code and in the script of its template', () {
      final host = RegExp(
        r'github|gitlab|workflow|actions/|yaml|\.yml',
        caseSensitive: false,
      );
      final files = [
        File('lib/src/roles/ci.dart'),
        ...Directory('lib/src/roles/ci').listSync().whereType<File>(),
        ...Directory('bricks/ci_role_env')
            .listSync(recursive: true)
            .whereType<File>(),
      ];
      expect(files, hasLength(greaterThan(4)));
      for (final file in files) {
        expect(
          file.readAsStringSync(),
          isNot(contains(host)),
          reason: '${file.path} names a host. The provider of the role knows '
              'its host, and the role does not.',
        );
      }
    });
  });

  group('CiRole.pipelineIn', () {
    test(
        'in an app with the env role, starts each job from what the role '
        'gives it, and passes the tool arguments of its provider on', () {
      final pipeline = ciRole.pipelineIn(_withEnv());

      expect(_commandsOf(pipeline.checks), [
        '[ -f .env ] || cp .env.example .env',
        'flutter pub get',
        'dart format --output=none --set-exit-if-changed lib test',
        'flutter analyze',
        'flutter test --dart-define-from-file=.env',
      ]);
      final build = pipeline.build;
      expect(build.environments, ['dev', 'staging', 'prod']);
      expect(_commandsOf(build.prepare), [
        'dart tool/write_env.dart',
        'flutter pub get',
      ]);
      expect(build.keys, ['SHOP_KEY', 'FEED_URL']);
      expect(
        build.command.of('staging'),
        'flutter build apk --release --flavor staging '
        '--dart-define-from-file=.env',
      );
      expect(
        build.artifact.of('staging'),
        'build/app/outputs/flutter-apk/app-staging-release.apk',
      );
    });

    test(
      'starts the checks with a command that gives a fresh copy of the app '
      'its .env and keeps the values of a developer',
      () {
        final first = ciRole.pipelineIn(_withEnv()).checks.first.command;
        final directory = Directory.systemTemp.createTempSync('ci_first_check');
        addTearDown(() => directory.deleteSync(recursive: true));
        final example = File('${directory.path}/${EnvRole.exampleFile}')
          ..writeAsStringSync('SHOP_KEY=\n');
        final env = File('${directory.path}/${EnvRole.dotEnvFile}');

        ProcessResult run() => Process.runSync(
              'sh',
              ['-c', first],
              workingDirectory: directory.path,
            );

        expect(run().exitCode, 0);
        expect(env.readAsStringSync(), example.readAsStringSync());

        env.writeAsStringSync('SHOP_KEY=mine\n');
        expect(run().exitCode, 0);
        expect(env.readAsStringSync(), 'SHOP_KEY=mine\n');
      },
      testOn: '!windows',
    );

    test('in an app without the env role, has nothing of its files', () {
      final pipeline = ciRole.pipelineIn(inputOf(ciRole));

      expect(_commandsOf(pipeline.checks), [
        'flutter pub get',
        'dart format --output=none --set-exit-if-changed lib test',
        'flutter analyze',
        'flutter test',
      ]);
      final build = pipeline.build;
      expect(_commandsOf(build.prepare), ['flutter pub get']);
      expect(build.keys, isEmpty);
      expect(
        build.command.of('prod'),
        'flutter build apk --release --flavor prod',
      );
    });

    test(
        'takes the environments from the flavors of the app, with the '
        'flavor that the app builds by default first', () {
      final environments =
          ciRole.pipelineIn(inputOf(ciRole)).build.environments;

      expect(environments, [
        for (final flavor in AppEntryRole.flavors) flavor.name,
      ]);
      expect(environments.first, AppEntryRole.defaultFlavor.name);
    });

    test('gives tool arguments of two parts as they are', () {
      final input = inputOf(
        ciRole,
        data: [
          dataOf<EnvData>(
            envRole,
            const EnvToolArguments(['--dart-define-from-file', '.env']),
            module: 'env_provider',
          ),
        ],
        present: {envRole},
      );
      final pipeline = ciRole.pipelineIn(input);

      expect(
        pipeline.checks.last.command,
        'flutter test --dart-define-from-file .env',
      );
      expect(
        pipeline.build.command.of('dev'),
        'flutter build apk --release --flavor dev --dart-define-from-file '
        '.env',
      );
      expect(pipeline.build.keys, isEmpty);
    });

    test('takes an env role whose provider needs no tool arguments', () {
      final pipeline = ciRole.pipelineIn(
        inputOf(ciRole, present: {envRole}),
      );

      expect(
        pipeline.checks.first.command,
        '[ -f .env ] || cp .env.example .env',
      );
      expect(pipeline.checks.last.command, 'flutter test');
      expect(
        pipeline.build.command.of('dev'),
        'flutter build apk --release --flavor dev',
      );
    });

    test('names each command, for a host that shows the names of its steps',
        () {
      final pipeline = ciRole.pipelineIn(_withEnv());

      expect(
        [for (final check in pipeline.checks) check.name],
        [
          'Copy .env.example to .env',
          'Get the packages',
          'Check the format',
          'Analyze',
          'Test',
        ],
      );
      expect(
        [for (final command in pipeline.build.prepare) command.name],
        [
          'Write .env from the variables of the environment',
          'Get the packages',
        ],
      );
      expect(pipeline.build.name, 'Build the Android app');
    });
  });

  group('the rule ci.pipeline_rendered', () {
    for (final (name, write) in [
      ('lists of commands', _listsOfCommands),
      ('a block for each environment', _blocksOfEnvironments),
    ]) {
      test('passes a provider with $name, whatever its format', () {
        expect(_problemsOf(write, _withEnv(), hasEnv: true), isEmpty);
        expect(_problemsOf(write, inputOf(ciRole), hasEnv: false), isEmpty);
      });
    }

    test('reports a provider without a file: the app has no CI', () {
      expect(_problemsOf(null, _withEnv(), hasEnv: true), [
        'The provider of the CI role generates no file that CI could read.',
      ]);
    });

    test('reports a check that the file lacks: CI passes on an app with errors',
        () {
      expect(
        _problemsAfter(
          (text) => text.replaceAll('    - "flutter analyze"\n', ''),
        ),
        [_noLineWith('flutter analyze')],
      );
    });

    test('reports another program whose name only ends like the command', () {
      for (final other in ['myflutter analyze', './flutter analyze']) {
        expect(
          _problemsAfter(
            (text) =>
                text.replaceAll('    - "flutter analyze"', '    - $other'),
          ),
          [_noLineWith('flutter analyze')],
          reason: other,
        );
      }
    });

    test('reports a command in a comment only: it never runs', () {
      for (final comment in ['#', '//', '  #']) {
        expect(
          _problemsAfter(
            (text) => text.replaceAll(
              '    - "flutter analyze"',
              '$comment flutter analyze',
            ),
          ),
          [_noLineWith('flutter analyze')],
          reason: comment,
        );
      }
    });

    test(
        'reports flutter test without the tool arguments: the tests read no '
        'value', () {
      expect(
        _problemsAfter(
          (text) => text.replaceAll(
            'flutter test --dart-define-from-file=.env',
            'flutter test',
          ),
        ),
        [_noLineWith('flutter test --dart-define-from-file=.env')],
      );
    });

    test(
        'reports flutter test with arguments in an app whose provider gives '
        'none: another command does not pass for it', () {
      expect(
        _problemsOf(
          (pipeline) => _listsOfCommands(pipeline).replaceAll(
            'flutter test',
            'flutter test --coverage',
          ),
          inputOf(ciRole),
          hasEnv: false,
        ),
        [_noLineWith('flutter test')],
      );
    });

    test('reports the script of a build that the file lacks: no value is set',
        () {
      expect(
        _problemsAfter(
          (text) => text.replaceAll('    - dart tool/write_env.dart\n', ''),
        ),
        [_noLineWith('dart tool/write_env.dart')],
      );
    });

    test(
        'reports a build without a flavor: it builds the default flavor, '
        'whichever environment the developer chose', () {
      expect(
        _problemsAfter(
          (text) => text.replaceAll(r' --flavor $ENVIRONMENT', ''),
        ),
        [_noBuildCommand],
      );
    });

    test('reports a build without the tool arguments: it builds without values',
        () {
      expect(
        _problemsAfter(
          (text) => text.replaceAll(
            r'--flavor $ENVIRONMENT --dart-define-from-file=.env',
            r'--flavor $ENVIRONMENT',
          ),
        ),
        [_noBuildCommand],
      );
    });

    test('reports another file than the build writes: nothing is kept', () {
      for (final path in [
        r'build/app/outputs/flutter-apk/app-$ENVIRONMENT.apk',
        // Another file, whose name only starts with the right one.
        r'build/app/outputs/flutter-apk/app-$ENVIRONMENT-release.apk.sha1',
        // Another directory, whose path only ends with the right one.
        r'/tmp/build/app/outputs/flutter-apk/app-$ENVIRONMENT-release.apk',
      ]) {
        expect(
          _problemsAfter(
            (text) => text.replaceAll(
              r'build/app/outputs/flutter-apk/app-$ENVIRONMENT-release.apk',
              path,
            ),
          ),
          [_noArtifact],
          reason: path,
        );
      }
    });

    test('reports an environment that the file lacks: it cannot be built', () {
      expect(
        _problemsAfter(
          (text) => text.replaceAll('dev, staging, prod', 'dev, prod'),
        ),
        ['$_prefix no environment `staging`.'],
      );
    });

    test('takes an environment only as a whole word', () {
      expect(
        _problemsAfter(
          (text) =>
              text.replaceAll('dev, staging, prod', 'dev, pre-staging, prod'),
        ),
        ['$_prefix no environment `staging`.'],
      );
    });

    test('reports a key that the file lacks: its value is empty in every build',
        () {
      expect(
        _problemsAfter(
          (text) => text.replaceAll('    FEED_URL: { value: "" }\n', ''),
        ),
        ['$_prefix no key `FEED_URL`.'],
      );
    });

    test('takes a key only as a whole word', () {
      expect(
        _problemsAfter(
          (text) => text.replaceAll('FEED_URL:', 'MY_FEED_URL_2:'),
        ),
        ['$_prefix no key `FEED_URL`.'],
      );
    });

    test('reports every problem of a file', () {
      expect(
        _problemsAfter(
          (text) => text
              .replaceAll('    - "flutter analyze"\n', '')
              .replaceAll('    FEED_URL: { value: "" }\n', ''),
        ),
        [
          _noLineWith('flutter analyze'),
          '$_prefix no key `FEED_URL`.',
        ],
      );
    });

    group('looks only at the files of the provider that are no Dart files:',
        () {
      const other = ModuleOrigin(ModuleId('other'));
      const provider = ModuleDescriptor(
        id: _providerId,
        description: 'A provider of the role',
        kind: plainKind,
        providers: [_Provider(_listsOfCommands)],
      );

      List<SmfIssue> check(
        Map<String, String> texts,
        Map<String, ContributionOrigin> owners, {
        List<ModuleDescriptor>? modules,
      }) =>
          ciRole.checkStructure(
            StructuralRuleRequest(
              hook: const RoleHookRequest(
                data: [],
                presentRoles: {ciRole},
                context: testContext,
              ),
              files: const {},
              texts: texts,
              owners: owners,
              modules: modules ?? const [provider],
            ),
          );

      final text = _listsOfCommands(ciRole.pipelineIn(inputOf(ciRole)));

      test('the same text passes in a file of the provider', () {
        expect(
          check({'ci.txt': text}, {'ci.txt': const ModuleOrigin(_providerId)}),
          isEmpty,
        );
      });

      test('a file of another module does not count, as the README does not',
          () {
        expect(
          check({'README.md': text}, const {'README.md': other}),
          hasLength(1),
        );
        expect(
          check(
            {'README.md': text},
            const {'README.md': RoleTemplateOrigin(appEntryRole)},
          ),
          hasLength(1),
        );
        expect(check({'ci.txt': text}, const {}), hasLength(1));
      });

      test('a Dart file of the provider does not count', () {
        expect(
          check(
            {'lib/ci.dart': text},
            const {'lib/ci.dart': ModuleOrigin(_providerId)},
          ),
          hasLength(1),
        );
      });

      test('an app whose modules only use the role has nothing to check', () {
        expect(
          check(
            const {},
            const {},
            modules: const [
              ModuleDescriptor(
                id: ModuleId('user'),
                description: 'A module that uses the role',
                kind: plainKind,
                uses: {ciRole},
              ),
            ],
          ),
          isEmpty,
        );
      });
    });
  });

  group('the template of the role', () {
    test(
        'generates the script of a build only in an app with the env role, '
        'and contributes no file of a host', () async {
      final withEnv = await renderTemplate(ciRole, present: {envRole});
      expect(withEnv.files.keys, [CiRole.writeEnvFile]);
      expect(withEnv.files.values.single, contains("File('.env.example')"));

      final withoutEnv = await renderTemplate(ciRole);
      expect(withoutEnv.files, isEmpty);
    });

    test(
        'tells the commands in the section of the README of an app with the '
        'env role, and where the values of a build come from', () {
      final section = ciRole.template.render(_withEnv()).fragments.single;

      expect(section.socket, AppEntryRole.readmeSections);
      expect(section.entryKey, CiRole.readmeHeading);
      expect(AppEntryRole.readmeSections.problemsWith(section), isEmpty);
      expect(section.entryValue, '''
On each push, CI of this app runs these commands in a fresh copy of the repository:

```bash
[ -f .env ] || cp .env.example .env
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --dart-define-from-file=.env
```

On request, it builds a release APK for one of the environments `dev`, `staging` and `prod`:

```bash
dart tool/write_env.dart
flutter pub get
flutter build apk --release --flavor <environment> --dart-define-from-file=.env
```

The APK is `build/app/outputs/flutter-apk/app-<environment>-release.apk`. The build signs it as the Android project of the app does, so it is for testers: uploading to a store, a signing key of your own and iOS are not part of it.

CI writes its own `.env`, since that file is not in git. The checks copy `.env.example` when `.env` is missing, so in a fresh copy every value is empty, and on your machine your values stay. A build takes the values of the chosen environment with `tool/write_env.dart`, and lists the keys it found no value for. A value with a double quote or a line break stops the build, and so does a `.env` that has a value already, which the script never replaces: delete the file to write it again. Every value ends up in the app, so never use one for a secret.

The section of the module that provides CI tells how to start a build.
''');
    });

    test('tells nothing of the values in an app without the env role', () {
      final section = ciRole.template
          .render(inputOf(ciRole))
          .fragments
          .single
          .entryValue! as String;

      expect(section, contains('flutter pub get\nflutter build apk'));
      expect(section, isNot(contains('.env')));
      expect(section, isNot(contains('write_env')));
      expect(
        section,
        endsWith(
          'are not part of it.\n'
          '\n'
          'The section of the module that provides CI tells how to start a '
          'build.\n',
        ),
      );
    });

    test(
        'says in the guide that CI runs nothing but the commands of the '
        'README, in every app with the role', () {
      final note = agentNoteOf(ciRole);

      expect(note.isOfRole, isTrue);
      expect(
        note.text,
        allOf(
          contains('"${CiRole.readmeHeading}" of `README.md`'),
          contains('`flutter pub get`'),
        ),
      );
      expect(note.text, isNot(contains('.env')));
    });

    test(
        'says in the guide of an app with the env role what a new key needs, '
        'and that a value is no secret', () {
      final note = agentNoteOf(ciRole, when: {envRole});

      expect(note.isOfRole, isTrue);
      expect(
        note.text,
        allOf(
          contains('`${CiRole.writeEnvFile}`'),
          contains('`${EnvRole.exampleFile}`'),
          contains('A new key also needs its variable where CI runs.'),
          contains('stops when `.env` has a value'),
          contains('never give a build of CI a secret'),
        ),
      );
    });
  });

  group('the script of a build', () {
    final script = templatesOf(ciRoleEnvBundle)[CiRole.writeEnvFile]!;

    /// A directory with the script, and with [example] as `.env.example`
    /// unless it is `null`.
    Directory appWith(String? example) {
      final directory = Directory.systemTemp.createTempSync('ci_write_env');
      addTearDown(() => directory.deleteSync(recursive: true));
      File('${directory.path}/${CiRole.writeEnvFile}')
        ..createSync(recursive: true)
        ..writeAsStringSync(script);
      if (example != null) {
        File('${directory.path}/${EnvRole.exampleFile}')
            .writeAsStringSync(example);
      }
      return directory;
    }

    /// Runs the script in [directory], as a job of CI does, with [values] as
    /// variables of the process.
    ProcessResult run(Directory directory, Map<String, String> values) =>
        Process.runSync(
          Platform.resolvedExecutable,
          [CiRole.writeEnvFile],
          workingDirectory: directory.path,
          environment: values,
        );

    File envOf(Directory directory) =>
        File('${directory.path}/${EnvRole.dotEnvFile}');

    /// The values of the [text] of `.env`, read in the two forms of a value
    /// that the env role names, which also fail on any other form: `KEY=` and
    /// a value without white space, `#` or a quote, or a value in double
    /// quotes.
    Map<String, String> readBack(String text) {
      final values = <String, String>{};
      for (final line in text.split('\n')) {
        if (line.isEmpty || line.startsWith('#')) continue;
        final match = RegExp(
          r'''^([A-Z_]+)=(?:"([^"]*)"|([^\s#"'`]*))$''',
        ).firstMatch(line);
        expect(match, isNotNull, reason: 'A line in no form of a value: $line');
        values[match![1]!] = match[2] ?? match[3]!;
      }
      return values;
    }

    const key = 'SHOP_KEY';

    for (final (name, value, line) in [
      ('a plain value', 'appl_123', 'SHOP_KEY=appl_123'),
      ('a value with an equals sign', 'appl_123=x', 'SHOP_KEY=appl_123=x'),
      (
        'a value with a # and a space',
        'https://e.com/a#b c',
        'SHOP_KEY="https://e.com/a#b c"',
      ),
      (
        'a value with a #, which would be a comment without its quotes',
        'https://e.com/terms#refunds',
        'SHOP_KEY="https://e.com/terms#refunds"',
      ),
      (
        'a value with spaces around it, a single quote and a variable of a '
            'shell',
        r" it's $HOME ",
        r'''SHOP_KEY=" it's $HOME "''',
      ),
      ('a value with a backtick', 'a`b', 'SHOP_KEY="a`b"'),
      (
        'a value with a backslash and an n, which stay two characters',
        r'a\nb',
        r'SHOP_KEY=a\nb',
      ),
      (
        'a value with the substitution of a shell, which nothing runs',
        r'$(touch pwned)',
        r'SHOP_KEY="$(touch pwned)"',
      ),
    ]) {
      test('writes $name in a form that reads back as it is', () {
        final directory = appWith('# The key.\n$key=\n');

        final result = run(directory, {key: value});

        expect(result.exitCode, 0, reason: '${result.stderr}');
        final text = envOf(directory).readAsStringSync();
        expect(text, '# The key.\n$line\n');
        expect(readBack(text), {key: value});
        expect(result.stdout, isNot(contains(value)));
        expect(Directory(directory.path).listSync(), hasLength(3));
      });
    }

    test(
        'keeps the line of a key without a variable, and of one whose '
        'variable is empty, and lists both without a value', () {
      final directory = appWith('$key=\nFEED_URL=\nOTHER_KEY=\n');

      final result = run(directory, {'OTHER_KEY': 'x', 'FEED_URL': ''});

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        envOf(directory).readAsStringSync(),
        '$key=\nFEED_URL=\nOTHER_KEY=x\n',
      );
      expect(result.stdout, contains('No value for: $key, FEED_URL.'));
    });

    test('says nothing of a missing value when every key has one', () {
      final directory = appWith('$key=\n');

      final result = run(directory, {key: 'x'});

      expect(result.stdout, isNot(contains('No value')));
    });

    test('keeps a value of .env.example, unless the variable has another', () {
      final directory = appWith('$key=from_the_example\nFEED_URL=old\n');

      final result = run(directory, {'FEED_URL': 'new'});

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        envOf(directory).readAsStringSync(),
        '$key=from_the_example\nFEED_URL=new\n',
      );
    });

    test('keeps comments and empty lines, also a key that is commented out',
        () {
      const example = '# A comment.\n\n# $key=\n# With a # in it.\n';
      final directory = appWith(example);

      final result = run(directory, {key: 'x'});

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(envOf(directory).readAsStringSync(), example);
    });

    test('fails and names the file when the app has no .env.example', () {
      final directory = appWith(null);

      final result = run(directory, const {});

      expect(result.exitCode, 1);
      expect(result.stderr, contains('.env.example is missing.'));
      expect(envOf(directory).existsSync(), isFalse);
    });

    for (final (name, value) in [
      ('a line break, which would add a line to .env', 'a\nOTHER=evil'),
      ('a carriage return', 'a\rb'),
      ('a tab', 'a\tb'),
      ('a double quote, which would end the quoted form', 'a" # b'),
      ('the delete character', 'a\x7Fb'),
    ]) {
      test(
          'refuses a value with $name: it names the key, never the value, '
          'and writes nothing', () {
        final directory = appWith('$key=\nFEED_URL=\n');
        envOf(directory).writeAsStringSync('KEPT=\n');

        final result = run(directory, {key: value, 'FEED_URL': 'fine'});

        expect(result.exitCode, 1);
        expect(
          result.stderr,
          'The values of $key have a double quote or a control character, '
          'which .env cannot hold.\n',
        );
        expect(result.stdout, isEmpty);
        expect(envOf(directory).readAsStringSync(), 'KEPT=\n');
      });
    }

    for (final (name, lines) in [
      ('a plain value', '$key=mine\n'),
      ('a value in double quotes', '$key="mine and yours"\n'),
      ('a value before a comment', '$key=mine # The key.\n'),
      ('a value next to an empty key', 'FEED_URL=\n# A comment.\n$key=mine\n'),
      ('a line in another form', 'export $key=mine\n'),
    ]) {
      test(
          'keeps a .env with $name, whatever the variables have: it fails, '
          'names no value and writes nothing', () {
        final directory = appWith('$key=\nFEED_URL=\n');
        envOf(directory).writeAsStringSync(lines);

        final result = run(directory, {key: 'from_ci', 'FEED_URL': 'from_ci'});

        expect(result.exitCode, 1);
        expect(
          result.stderr,
          '.env has values, which this script would replace. Delete .env to '
          'write it again.\n',
        );
        expect(result.stdout, isEmpty);
        expect(envOf(directory).readAsStringSync(), lines);
      });
    }

    test('keeps a .env that is no text, and prints nothing of it', () {
      final directory = appWith('$key=\n');
      final bytes = [...'$key='.codeUnits, 0xFF, 0xFE, ...'mine\n'.codeUnits];
      envOf(directory).writeAsBytesSync(bytes);

      final result = run(directory, {key: 'from_ci'});

      expect(result.exitCode, 1);
      expect(result.stderr, startsWith('.env has values'));
      expect(result.stderr, isNot(contains('mine')));
      expect(envOf(directory).readAsBytesSync(), bytes);
    });

    for (final (name, lines) in [
      ('nothing', ''),
      ('a fresh copy of .env.example', '# The key.\n$key=\n'),
      ('a key with empty quotes', '$key=""\n'),
      ('an empty key before a comment', '$key= # The key.\n'),
      ('a key whose value is a comment', '$key=#mine\n'),
      ('a value in a comment', '# $key=mine\n\n'),
    ]) {
      test('writes over a .env with $name, so a job of CI needs no setting',
          () {
        final directory = appWith('$key=\n');
        envOf(directory).writeAsStringSync(lines);

        final result = run(directory, {key: 'from_ci'});

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(envOf(directory).readAsStringSync(), '$key=from_ci\n');
      });
    }

    test('names each key whose value it refuses', () {
      final directory = appWith('$key=\nFEED_URL=\n');

      final result = run(directory, {key: 'a"', 'FEED_URL': 'b"'});

      expect(result.exitCode, 1);
      expect(result.stderr, contains('$key, FEED_URL'));
      expect(envOf(directory).existsSync(), isFalse);
    });
  });
}
