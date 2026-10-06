import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:mirrors';

import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The directory of the package of [module]: the package of the library of
/// its class.
Future<String> _packageDirectoryOf(SmfModule module) async {
  final library = reflectClass(module.runtimeType).owner! as LibraryMirror;
  final package = library.uri.pathSegments.first;
  final lib = await Isolate.resolvePackageUri(Uri.parse('package:$package/'));
  return p.dirname(p.fromUri(lib));
}

/// The words of [text] in lower case: its runs of letters and digits, split
/// at the humps of camelCase, such as `crashlytics`, `phase` and `fix` of
/// `crashlyticsPhaseFix`.
Set<String> _wordsOf(String text) => {
      for (final match
          in RegExp('[A-Z]+(?![a-z])|[A-Z]?[a-z]+|[0-9]+').allMatches(text))
        match[0]!.toLowerCase(),
    };

/// The lines of the package in [directory] of [module] that name a module of
/// [modules] that depends on it, which it knows nothing of, each as
/// `<path>:<line>: <word> of <module>`, by the path from [directory], in the
/// order of the paths and of the lines: a line of a file of its `lib/` but
/// its bundles, which its bricks generate, of its `bricks/`, of its
/// `example/`, which pub.dev shows, or of its `README.md` that has a word of
/// the id of such a module that is not a word of the id of [module],
/// whatever its case, such as `crashlytics` of `firebase_crashlytics` in the
/// package of `firebase_core`. A file that is not text, such as an image of
/// a brick, has no lines.
List<String> _dependentsNamedIn(
  String directory,
  ModuleDescriptor module,
  List<SmfModule> modules,
) {
  final own = module.id.value.split('_').toSet();
  final dependents = <String, ModuleId>{
    for (final other in modules)
      if (other.descriptor.dependsOn.contains(module.id))
        for (final word in other.descriptor.id.value.split('_'))
          if (!own.contains(word)) word: other.descriptor.id,
  };
  final bundles = p.join(directory, 'lib', 'bundles');
  final files = [
    for (final root in ['lib', 'bricks', 'example'])
      if (Directory(p.join(directory, root)) case final tree
          when tree.existsSync())
        for (final entity in tree.listSync(recursive: true))
          if (entity is File && !p.isWithin(bundles, entity.path)) entity,
    if (File(p.join(directory, 'README.md')) case final readme
        when readme.existsSync())
      readme,
  ];
  final paths = {
    for (final file in files)
      file: p.split(p.relative(file.path, from: directory)).join('/'),
  };
  final named = <String>[];
  for (final file in files..sort((a, b) => paths[a]!.compareTo(paths[b]!))) {
    final String text;
    try {
      text = utf8.decode(file.readAsBytesSync());
    } on FormatException {
      continue;
    }
    final path = paths[file]!;
    for (final (index, line) in const LineSplitter().convert(text).indexed) {
      for (final word in _wordsOf(line)) {
        if (dependents[word] case final dependent?) {
          named.add('$path:${index + 1}: $word of $dependent');
        }
      }
    }
  }
  return named;
}

/// The lines of the tests of the package in [directory] that take more of
/// the class of a module of [others] than its id, each as
/// `<path>:<line>: <class>.<member> of <module>`, by the path from
/// [directory], in the order of the paths and of the lines. [others] has the
/// modules of other packages that the module of the package does not depend
/// on, by the names of their classes.
///
/// A test names such a module by its id, to have it in an app as the
/// provider of a role. What else its class publishes, such as the directory
/// in which it writes its files, is for its own package, for the modules
/// that depend on it and for the CLI.
List<String> _membersOfOthersIn(
  String directory,
  Map<String, ModuleId> others,
) {
  final tests = Directory(p.join(directory, 'test'));
  if (others.isEmpty || !tests.existsSync()) return const [];
  final member = RegExp('\\b(${others.keys.join('|')})\\.([A-Za-z_]\\w*)');
  final paths = {
    for (final entity in tests.listSync(recursive: true))
      if (entity is File && p.extension(entity.path) == '.dart')
        p.split(p.relative(entity.path, from: directory)).join('/'): entity,
  };
  return [
    for (final path in paths.keys.toList()..sort())
      for (final (index, line) in paths[path]!.readAsLinesSync().indexed)
        for (final match in member.allMatches(line))
          if (match[2] != 'id')
            '$path:${index + 1}: ${match[0]} of ${others[match[1]]}',
  ];
}

/// The texts among [texts] that lack a translation into one of
/// [languages], each as `<text> has no translation into <language>`.
List<String> _untranslated(List<AppText> texts, List<String> languages) => [
      for (final text in texts)
        for (final language in languages)
          if (text.text.textIn(language) == null)
            '$text has no translation into $language',
    ];

/// A module [id] of the tests with [texts], which it gives the localization
/// role.
final class _TextsOwner extends SmfModule {
  const _TextsOwner(this.id, this.texts);

  final ModuleId id;
  final List<LocalizedText> texts;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'The module $id',
        kind: ModuleKinds.infrastructure,
        uses: const {localizationRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      [localizationRole.data(TextsData(texts))];
}

/// A module [id] of the tests that depends on the modules [dependsOn].
final class _Module extends SmfModule {
  const _Module(this.id, {this.dependsOn = const {}});

  final ModuleId id;
  final Set<ModuleId> dependsOn;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'The module $id',
        kind: ModuleKinds.infrastructure,
        dependsOn: dependsOn,
      );
}

void main() {
  test('every module follows the rules of its roles in every app', () async {
    final results =
        await ContractHarness(ModuleRegistry(smfModules)).checkAll();

    expect(results, isNotEmpty);
    for (final result in results) {
      expect(
        result.errors.map((issue) => '$issue'),
        isEmpty,
        reason: '$result',
      );
      expect(result.app, isNotNull, reason: '$result');
    }
  });

  test(
      'every module is checked with each provider of each role it requires or '
      'uses', () async {
    expect(
      await ContractHarness(ModuleRegistry(smfModules)).uncheckedProviders(),
      isEmpty,
    );
  });

  group('the texts of the modules', () {
    /// The languages that every text of a module of the CLI is in, besides
    /// English, which a text always has.
    const languages = ['uk'];

    test(
        'are in English and in Ukrainian, those of the templates of the '
        'roles too, in each app with every module', () async {
      final harness = ContractHarness(ModuleRegistry(smfModules));
      final cases = harness.casesOfAll();

      expect(cases, isNotEmpty);
      for (final contractCase in cases) {
        final result = await harness.check(contractCase);
        // The app has a provider of the localization, so the role has the
        // texts of every module of the app.
        expect(
          result.hook!.presentRoles,
          contains(localizationRole),
          reason: '$contractCase',
        );
        expect(
          _untranslated(
            localizationRole.textsIn(localizationRole.hookInput(result.hook!)),
            languages,
          ),
          isEmpty,
          reason: 'A text of a module that the CLI offers has a translation '
              'into each of $languages ($contractCase).',
        );
      }
    });

    test('lack a translation only when their owner gave none', () async {
      // The modules of the CLI and a module with texts, in each app with
      // every module, whichever modules provide its roles.
      final harness = ContractHarness(
        ModuleRegistry([
          ...smfModules,
          const _TextsOwner(ModuleId('cart'), [
            LocalizedText(
              'title',
              en: 'Your cart',
              translations: {'uk': 'Ваш кошик'},
            ),
            LocalizedText('empty', en: 'Nothing here'),
            LocalizedText('pay', en: 'Pay', translations: {'de': 'Zahlen'}),
          ]),
        ]),
      );
      final cases = harness.casesOfAll();

      expect(cases, isNotEmpty);
      for (final contractCase in cases) {
        final result = await harness.check(contractCase);

        expect(result.errors, isEmpty, reason: '$contractCase');
        expect(
          _untranslated(
            localizationRole.textsIn(localizationRole.hookInput(result.hook!)),
            languages,
          ),
          [
            'text empty of the module cart has no translation into uk',
            'text pay of the module cart has no translation into uk',
          ],
          reason: '$contractCase',
        );
      }
    });
  });

  test(
      'a module package does not name the modules that depend on it, which '
      'it knows nothing of', () async {
    final named = [
      for (final module in smfModules)
        for (final line in _dependentsNamedIn(
          await _packageDirectoryOf(module),
          module.descriptor,
          smfModules,
        ))
          '${module.descriptor.id}: $line',
    ];

    expect(
      named,
      isEmpty,
      reason: 'A module knows only the modules it depends on, and a module '
          'that depends on it adds what the package names:\n'
          '${named.join('\n')}',
    );
  });

  group('the names of the modules that depend on a package', () {
    const id = ModuleId('firebase_core');
    const core = _Module(id);
    const modules = [
      core,
      _Module(ModuleId('firebase_crashlytics'), dependsOn: {id}),
      _Module(ModuleId('firebase_analytics'), dependsOn: {id}),
      // It does not depend on core, which may name it.
      _Module(ModuleId('event_logger')),
    ];
    late Directory package;

    /// Writes [text] into the file at [path] of [package].
    void write(String path, String text) => File(p.join(package.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    setUp(() => package = Directory.systemTemp.createTempSync('smf_names_'));
    tearDown(() => package.deleteSync(recursive: true));

    test(
        'are found in its lib, its bricks, its example and its README, in any '
        'case and in identifiers', () {
      write(
        'README.md',
        'Sets up Firebase with firebase_core.\n'
            'On macOS, it fixes the phase of Crashlytics.\n',
      );
      write(
        'lib/src/fix.dart',
        'const crashlyticsPhaseFix = 1;\n'
            '// Logs with the event logger.\n'
            "const upload = 'upload-crashlytics-symbols';\n",
      );
      write(
        'bricks/core/__brick__/lib/options.dart',
        '// Also for FirebaseAnalytics.\n',
      );
      write(
        'example/README.md',
        '# Firebase\n'
            '\n'
            'firebase_analytics depends on it.\n',
      );

      expect(
        _dependentsNamedIn(package.path, core.descriptor, modules),
        [
          'README.md:2: crashlytics of firebase_crashlytics',
          equals(
            'bricks/core/__brick__/lib/options.dart:1: analytics of '
            'firebase_analytics',
          ),
          'example/README.md:3: analytics of firebase_analytics',
          'lib/src/fix.dart:1: crashlytics of firebase_crashlytics',
          'lib/src/fix.dart:3: crashlytics of firebase_crashlytics',
        ],
      );
    });

    test(
        'are not looked for in its bundles and tests, in files that are not '
        'text, or in a word that only contains them', () {
      write('lib/bundles/core_bundle.dart', '// firebase_crashlytics\n');
      write('test/fix_test.dart', '// crashlytics\n');
      write('lib/src/options.dart', '// Superanalytics.\n');
      File(p.join(package.path, 'bricks/core/__brick__/icon.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([0xFF, 0xD8, ...utf8.encode('crashlytics')]);

      expect(
        _dependentsNamedIn(package.path, core.descriptor, modules),
        isEmpty,
      );
    });

    test('are none of a package that no module depends on', () {
      write('README.md', 'Crashlytics and Analytics.\n');

      expect(
        _dependentsNamedIn(
          package.path,
          modules.last.descriptor,
          modules,
        ),
        isEmpty,
      );
    });
  });

  test(
      'the tests of a module package take only the id of a module of another '
      'package, unless their module depends on it', () async {
    final directories = {
      for (final module in smfModules)
        module: await _packageDirectoryOf(module),
    };
    final taken = [
      for (final module in smfModules)
        for (final line in _membersOfOthersIn(directories[module]!, {
          for (final other in smfModules)
            if (directories[other] != directories[module] &&
                !module.descriptor.dependsOn.contains(other.descriptor.id))
              '${other.runtimeType}': other.descriptor.id,
        }))
          '${module.descriptor.id}: $line',
    ];

    expect(
      taken,
      isEmpty,
      reason: 'A test has another module in its apps as the provider of a '
          'role, by its id, and checks what its own module gives the role '
          'through the data of the role. What the other module does with '
          'it, such as the files that it writes, is for the tests of that '
          'module:\n${taken.join('\n')}',
    );
  });

  group('what the tests of a package take of the modules of others', () {
    const others = {
      'TextsModule': ModuleId('texts'),
      'RouterModule': ModuleId('router'),
    };
    late Directory package;

    /// Writes [text] into the file at [path] of [package].
    void write(String path, String text) => File(p.join(package.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    setUp(() => package = Directory.systemTemp.createTempSync('smf_members_'));
    tearDown(() => package.deleteSync(recursive: true));

    test(
        'is found in each Dart file of its tests, also through the prefix '
        'of an import and more than once on a line', () {
      write(
        'test/feature_test.dart',
        'const modules = [FeatureModule(), TextsModule()];\n'
            "final file = app.files['\${TextsModule.directory}/en.arb'];\n"
            'final both = [RouterModule.file, texts.TextsModule.template];\n',
      );
      write('test/support/app.dart', '// See RouterModule.routes.\n');

      expect(_membersOfOthersIn(package.path, others), [
        'test/feature_test.dart:2: TextsModule.directory of texts',
        'test/feature_test.dart:3: RouterModule.file of router',
        'test/feature_test.dart:3: TextsModule.template of texts',
        'test/support/app.dart:1: RouterModule.routes of router',
      ]);
    });

    test(
        'is not the id of a module, a member of another class, or what '
        'another file of the package has', () {
      write(
        'test/feature_test.dart',
        'const ids = [TextsModule.id, RouterModule.id];\n'
            'final name = TextsModule.id.value;\n'
            'final own = [FeatureModule.texts, FakeTextsModule.directory];\n',
      );
      write('test/snapshots/app.txt', 'TextsModule.directory\n');
      write('lib/src/feature.dart', '// TextsModule.directory\n');

      expect(_membersOfOthersIn(package.path, others), isEmpty);
    });

    test('is nothing of a package without tests or without other modules', () {
      expect(_membersOfOthersIn(package.path, others), isEmpty);

      write('test/feature_test.dart', 'final file = TextsModule.directory;\n');

      expect(_membersOfOthersIn(package.path, const {}), isEmpty);
    });
  });
}
