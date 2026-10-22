@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_dart_define/src/agents.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'support/dart_app.dart';
import 'support/keys.dart';

/// A description with a `<` outside a code span and one inside it, and a
/// code span with spaces where the doc of its getter wraps.
const _terms = 'The <terms> of the shop, at `https://shop.example/<terms>`, '
    'which `the app shows` in a web view';

/// A module that requires the role, with three keys: one whose description
/// ends without a period, [_terms], and one whose description has a
/// backtick that opens no code span.
const _shop = KeysModule('shop', [
  EnvKey(
    'SHOP_APPLE_KEY',
    description: 'The public key of the App Store app of the shop (appl_…)',
  ),
  EnvKey('SHOP_TERMS_URL', description: _terms),
  EnvKey(
    'SHOP_BANNER_TEXT',
    description: 'A text with a ` that opens no code span, before a <b>',
  ),
]);

/// A module that uses the role, with a key whose description is a sentence
/// with two spaces between two of its words.
const _feed = KeysModule(
  'feed',
  [EnvKey('FEED_URL', description: 'The address of  the feed.')],
  requiresEnv: false,
);

/// The modules of the tests: flutter_core, which creates the app, this
/// module, and two modules with keys.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  DartDefineModule(),
  _shop,
  _feed,
];

const _module = ModuleOrigin(DartDefineModule.id);

/// The path of the run configuration of VS Code.
const _launch = '.vscode/launch.json';

/// The path of the run configuration of Android Studio.
const _runConfiguration = '.run/main.run.xml';

/// What the contract harness finds for the app of [modules].
Future<ContractResult> _check(List<ModuleId> modules) =>
    ContractHarness(ModuleRegistry(_modules)).check(
      ContractCase(modules.join(', '), requested: modules),
    );

/// What the contract harness finds for the app of [modules], which has no
/// errors and is rendered.
Future<ContractResult> _rendered(List<ModuleId> modules) async {
  final result = await _check(modules);
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The tool arguments of the env role in the app of [result].
List<String> _toolArgumentsOf(ContractResult result) =>
    envRole.toolArgumentsIn(envRole.hookInput(result.hook!));

/// What the contributors of the app of [result] put into [socket], each as
/// its origin and its key, in the order that the pipeline rendered them.
List<(String, String)> _putInto(ContractResult result, SocketRef socket) => [
      for (final collected in result.app!.socketOrders[socket]?.contributions ??
          const <Collected>[])
        if (collected.contribution case final SocketContribution contribution)
          ('${collected.origin}', contribution.entryKey!),
    ];

/// The section of the module in the README of the app.
String _readmeSection() => const DartDefineModule()
    .contribute(ContractHarness.defaultContext)
    .whereType<SocketContribution>()
    .singleWhere((socket) => socket.socket == AppEntryRole.readmeSections)
    .entryValue! as String;

/// The inline code of [text]: what stands between two backticks, outside
/// its code blocks.
Set<String> _inlineCodeOf(String text) => {
      for (final match in RegExp('`([^`\n]+)`')
          .allMatches(text.replaceAll(RegExp(r'```[\s\S]*?```'), '')))
        match[1]!,
    };

void main() {
  const module = DartDefineModule();

  group('DartDefineModule', () {
    test('is infrastructure that provides the env role and needs nothing', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('dart_define'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {envRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, its argument for the commands of the flutter '
        'tool, a section of the README and its note for coding agents, and '
        'nothing else: no package of the app', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(4));
      final brick = (contributions[0] as BrickContribution).bundle;
      expect(brick.name, 'dart_define');
      expect(brick.hooks, isEmpty);
      expect(
        [for (final file in brick.files) file.path],
        unorderedEquals([_launch, _runConfiguration, EnvRole.readerFile]),
      );
      final data = contributions[1] as RoleData<Object>;
      expect(data.role, envRole);
      expect(
        (data.value as EnvToolArguments).arguments,
        ['--dart-define-from-file=${EnvRole.dotEnvFile}'],
      );
      final readme = contributions[2] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, DartDefineModule.readmeHeading);
      expect(DartDefineModule.readmeHeading, 'Run, test and build with .env');
      final note = contributions[3] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, envRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      for (final contribution in contributions) {
        expect(contribution.when, isEmpty);
      }
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test('builds the apps of the modules with keys with the module', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core',
        'dart_define',
        'shop',
        'feed with env',
        'feed',
      ]);
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

    test(
        'renders AppEnv and the code of the modules that read it without a '
        'diagnostic of the analyzer', () async {
      final withModule = [
        for (final result in results)
          if (result.app!.files.containsKey(EnvRole.readerFile)) result,
      ];
      expect(withModule, hasLength(3));
      for (final result in withModule) {
        final app = DartApp.write(result.app!);
        addTearDown(app.delete);
        expect(
          await app.analysisProblems({
            _module,
            ModuleOrigin(_shop.id),
            ModuleOrigin(_feed.id),
          }),
          isEmpty,
          reason: '${result.contractCase}',
        );
      }
    });

    test(
        'has a note of the role in the guide for coding agents that names '
        'neither this module nor its argument', () {
      expect(
        roleNoteProblems(
          results,
          AppEntryRole.agentSections,
          textOf: (note) => note.text,
        ),
        isEmpty,
      );
    });
  });

  group('AppEnv', () {
    test(
        'has no member in an app without keys, so it has no helper that '
        'nothing uses', () async {
      final result = await _rendered(const [DartDefineModule.id]);
      final file = result.app!.files[EnvRole.readerFile]!;

      expect(envRole.keysIn(envRole.hookInput(result.hook!)), isEmpty);
      expect(file.owner, _module);
      expect(file.text, endsWith('\nabstract final class AppEnv {\n}\n'));
      final appEnv = DartFileIndexer.index(EnvRole.readerFile, file.text)
          .declaration(EnvRole.appEnv.name)!;
      expect(appEnv.kind, DeclarationKind.classType);
      expect(appEnv.members, isEmpty);
      expect(appEnv.constructors, isEmpty);
    });

    test(
        'has a static getter of a String? for each key, in the order of the '
        'keys of the app, with the description of the key as its doc',
        () async {
      final result = await _rendered([_shop.id, _feed.id]);
      final text = result.app!.files[EnvRole.readerFile]!.text;
      final keys = envRole.keysIn(envRole.hookInput(result.hook!));

      final appEnv = DartFileIndexer.index(EnvRole.readerFile, text)
          .declaration(EnvRole.appEnv.name)!;
      expect(
        [
          for (final member in appEnv.members)
            (member.name, member.kind, member.isStatic),
        ],
        [
          for (final key in keys) (key.getter, MemberKind.getter, true),
        ],
      );
      expect(
        [for (final key in keys) key.name],
        ['SHOP_APPLE_KEY', 'SHOP_TERMS_URL', 'SHOP_BANNER_TEXT', 'FEED_URL'],
      );
      // A period ends a description that has none, a `<` outside a code
      // span is escaped, so that Markdown takes it for no HTML tag, and the
      // doc wraps at 80 columns between words outside its code spans, with
      // one space between two words.
      expect(
        text,
        contains(
          'abstract final class AppEnv {\n'
          '  /// The public key of the App Store app of the shop (appl_…).\n'
          '  static String? get shopAppleKey {\n'
          "    const value = String.fromEnvironment('SHOP_APPLE_KEY');\n"
          '    return value.isEmpty ? null : value;\n'
          '  }\n'
          '\n'
          r'  /// The \<terms> of the shop, at `https://shop.example/<terms>`, '
          'which\n'
          '  /// `the app shows` in a web view.\n'
          '  static String? get shopTermsUrl {\n'
          "    const value = String.fromEnvironment('SHOP_TERMS_URL');\n"
          '    return value.isEmpty ? null : value;\n'
          '  }\n'
          '\n'
          r'  /// A text with a ` that opens no code span, before a \<b>.'
          '\n'
          '  static String? get shopBannerText {\n'
          "    const value = String.fromEnvironment('SHOP_BANNER_TEXT');\n"
          '    return value.isEmpty ? null : value;\n'
          '  }\n'
          '\n'
          '  /// The address of the feed.\n'
          '  static String? get feedUrl {\n'
          "    const value = String.fromEnvironment('FEED_URL');\n"
          '    return value.isEmpty ? null : value;\n'
          '  }\n'
          '}\n',
        ),
      );
      for (final line in const LineSplitter().convert(text)) {
        expect(line.length, lessThanOrEqualTo(80), reason: line);
      }
    });

    test(
        'returns the value that the flutter tool gives a key, and null for '
        'a key that it gives an empty value or none, as it does for KEY= '
        'and for a key that .env lacks', () async {
      final result = await _rendered([_shop.id, _feed.id]);
      final app = DartApp.write(result.app!);
      addTearDown(app.delete);

      final printed = await app.run(
        '''
import 'dart:convert';

import 'package:contract_app/core/env/app_env.dart';

void main() => print(
      jsonEncode([
        AppEnv.shopAppleKey,
        AppEnv.shopTermsUrl,
        AppEnv.shopBannerText,
        AppEnv.feedUrl,
      ]),
    );
''',
        {
          'SHOP_APPLE_KEY': 'appl_123',
          'SHOP_TERMS_URL': '',
          'SHOP_BANNER_TEXT': 'Ціни # без змін',
        },
      );

      expect(jsonDecode(printed), ['appl_123', null, 'Ціни # без змін', null]);
    });
  });

  group('the run configurations', () {
    late ContractResult result;
    late RenderedApp app;

    setUpAll(() async {
      result = await _rendered([_shop.id]);
      app = result.app!;
    });

    test(
        'of VS Code launch the entry of the app under the name of the app, '
        'with the tool arguments of the role', () {
      expect(app.files[_launch]!.owner, _module);
      expect(jsonDecode(app.files[_launch]!.text), {
        'version': '0.2.0',
        'configurations': [
          {
            'name': ContractHarness.defaultContext.appName,
            'request': 'launch',
            'type': 'dart',
            'program': AppEntryRole.mainFile,
            'toolArgs': _toolArgumentsOf(result),
          },
        ],
      });
      expect(_toolArgumentsOf(result), isNotEmpty);
    });

    test(
        'of Android Studio run the entry of the app with the tool arguments '
        'of the role, in a configuration that the project shares', () {
      expect(app.files[_runConfiguration]!.owner, _module);
      final component =
          XmlDocument.parse(app.files[_runConfiguration]!.text).rootElement;
      expect(component.name.local, 'component');
      expect(
        component.getAttribute('name'),
        'ProjectRunConfigurationManager',
      );
      final configuration = component.childElements.single;
      expect(configuration.name.local, 'configuration');
      expect(configuration.getAttribute('type'), 'FlutterRunConfigurationType');
      expect(configuration.getAttribute('factoryName'), 'Flutter');
      expect(configuration.getAttribute('default'), 'false');
      expect(configuration.getAttribute('name'), 'main.dart');
      expect(
        {
          for (final option in configuration.findElements('option'))
            option.getAttribute('name'): option.getAttribute('value'),
        },
        {
          'additionalArgs': _toolArgumentsOf(result).join(' '),
          'filePath': '\$PROJECT_DIR\$/${AppEntryRole.mainFile}',
        },
      );
    });

    test(
        'stay in git, as does AppEnv, while .gitignore of the app keeps .env '
        'out', () async {
      final root = Directory.systemTemp.createTempSync('smf_dart_define_');
      addTearDown(() => root.deleteSync(recursive: true));
      // Neither the excludes of the user nor those of the system count.
      final excludes = File('${root.path}/excludes')..writeAsStringSync('');
      Future<ProcessResult> git(List<String> arguments) => Process.run(
            'git',
            ['-c', 'core.excludesFile=${excludes.path}', ...arguments],
            workingDirectory: root.path,
          );
      expect((await git(['init', '-q'])).exitCode, 0);
      File('${root.path}/${AppEntryRole.gitignoreFile}')
          .writeAsStringSync(app.files[AppEntryRole.gitignoreFile]!.text);

      final ignored = await git([
        'check-ignore',
        '--no-index',
        '--',
        _launch,
        _runConfiguration,
        EnvRole.readerFile,
        EnvRole.dotEnvFile,
      ]);

      expect(ignored.exitCode, 0, reason: '${ignored.stderr}');
      expect(
        const LineSplitter().convert('${ignored.stdout}'),
        [EnvRole.dotEnvFile],
      );
    });
  });

  group('the README of the app', () {
    late ContractResult result;
    late String section;

    setUpAll(() async {
      result = await _rendered([_shop.id]);
      section = _readmeSection();
    });

    test(
        'has the section of the module, which names the section of the '
        'role on what goes into .env, before that section, as the sections '
        'of modules come before those of roles', () {
      expect(
        [
          for (final entry in _putInto(result, AppEntryRole.readmeSections))
            if (entry.$2 == EnvRole.readmeHeading ||
                entry.$2 == DartDefineModule.readmeHeading)
              entry,
        ],
        [
          ('dart_define', DartDefineModule.readmeHeading),
          ('role:env', EnvRole.readmeHeading),
        ],
      );
      expect(
        result.app!.files[AppEntryRole.readmeFile]!.text,
        contains('\n## ${DartDefineModule.readmeHeading}\n\n$section'),
      );
      expect(section, contains('"${EnvRole.readmeHeading}"'));
    });

    test(
        'gives each command of the flutter tool that builds, runs or tests '
        'the app with the tool arguments of the role', () {
      final commands = [
        for (final line in const LineSplitter().convert(section))
          if (line.startsWith('flutter ')) line,
      ];

      expect(commands, [
        for (final command in ['run', 'test', 'build apk', 'build ipa'])
          ['flutter', command, ..._toolArgumentsOf(result)].join(' '),
      ]);
    });

    test(
        'names the files of the app that read the values and pass the '
        'argument, and the class through which code reads a value', () {
      final paths = {
        for (final code in _inlineCodeOf(section))
          if (code.contains('/')) code,
      };

      expect(paths, {_launch, _runConfiguration, EnvRole.readerFile});
      for (final path in paths) {
        expect(result.app!.files, contains(path));
      }
      expect(_inlineCodeOf(section), contains(EnvRole.appEnv.name));
    });

    test('shows the getter of a new key as the module writes the getters', () {
      final example = RegExp(r'```dart\n([\s\S]*?)```').firstMatch(section)![1];
      final written = RegExp(
        r'  static String\? get shopAppleKey \{[\s\S]*?\n  \}\n',
      ).firstMatch(result.app!.files[EnvRole.readerFile]!.text)![0];

      expect(
        [
          for (final line in const LineSplitter().convert(example!)) '  $line',
        ].join('\n'),
        written!
            .trimRight()
            .replaceAll('shopAppleKey', 'myServiceKey')
            .replaceAll('SHOP_APPLE_KEY', 'MY_SERVICE_KEY'),
      );
    });
  });

  group('the note of the module for coding agents', () {
    late ContractResult result;
    late RenderedApp app;

    setUpAll(() async {
      result = await _rendered([_shop.id, _feed.id]);
      app = result.app!;
    });

    test(
        'is in the section of the env role of the guide, after what the role '
        'says, and opens with the argument', () {
      final notes = [
        for (final (origin, heading, note)
            in app.entriesOf(AppEntryRole.agentSections))
          if (heading == envRole.description) (origin, note),
      ];

      expect(notes, hasLength(2));
      final ofRole = notes
          .singleWhere((note) => note.$1 == const RoleTemplateOrigin(envRole))
          .$2;
      expect(ofRole.isOfRole, isTrue);
      expect(notes, contains((_module, AgentNote(agentNote))));
      expect(agentNote, startsWith('With `--dart-define-from-file`:\n'));
      // The guide has the note of the role first in its section.
      expect(
        app.files[AppEntryRole.agentsFile]!.text,
        contains(
          '\n## ${envRole.description}\n'
          '\n'
          '${ofRole.text.trim()}\n'
          '\n'
          '${agentNote.trim()}\n',
        ),
      );
    });

    test(
        'names in inline code the argument and the commands with it, the '
        'files that the app has, and the code of AppEnv, and nothing else', () {
      final argument = _toolArgumentsOf(result).single;

      expect(_inlineCodeOf(agentNote), {
        'flutter',
        '--dart-define-from-file',
        argument,
        'flutter run $argument',
        'flutter test',
        'flutter build',
        EnvRole.appEnv.name,
        'null',
        _launch,
        _runConfiguration,
        EnvRole.dotEnvFile,
        'flutter run',
        EnvRole.readerFile,
        "const String.fromEnvironment('MY_SERVICE_KEY')",
        'MY_SERVICE_KEY',
      });
      for (final path in [_launch, _runConfiguration, EnvRole.readerFile]) {
        expect(app.files, contains(path));
      }
      final index = DartFileIndexer.index(
        EnvRole.readerFile,
        app.files[EnvRole.readerFile]!.text,
      );
      expect(index.declaration(EnvRole.appEnv.name), isNotNull);
      expect(
        app.files[EnvRole.readerFile]!.text,
        contains("const value = String.fromEnvironment('SHOP_APPLE_KEY');"),
      );
    });
  });
}
