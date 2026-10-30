import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/bundles/dart_define_bundle.dart';
import 'package:smf_dart_define/src/agents.dart';

/// The argument with which a command of the `flutter` tool reads the
/// values of [EnvRole.dotEnvFile].
const _toolArgument = '--dart-define-from-file=${EnvRole.dotEnvFile}';

/// The flavor that a build for a store names.
final String _storeFlavor = AppEntryRole.releaseFlavor.name;

/// The module that gives the app the values of `.env` through
/// `--dart-define-from-file` of the `flutter` tool, and so provides the env
/// role.
///
/// A command of the `flutter` tool that builds, runs or tests the app reads
/// `.env` when it starts, given `--dart-define-from-file=.env`, and compiles
/// each value into the app as a constant. The template of the role writes
/// `.env` and `.env.example` with the keys of the modules of the app. This
/// module adds:
/// - `lib/core/env/app_env.dart` with `AppEnv`, whose static getter of
///   each key reads its value with `const String.fromEnvironment` and
///   returns `null` for an empty one. The getters come from the render
///   hook of the module, from the keys of the app, and an app without keys
///   has the class without members. Nothing is generated after an edit of
///   `.env`, and the analyzer sees the empty values, so a fresh clone of
///   the app analyzes and builds;
/// - its argument for the role ([EnvToolArguments]), which code that runs
///   such a command for the app takes from [EnvRole.toolArgumentsIn], such
///   as the run configurations that the template of the role writes and the
///   tests of the apps of SMF;
/// - the section [readmeHeading] of the README of the app, which gives the
///   commands with the argument, a build for a store with the flavor of a
///   store ([AppEntryRole.releaseFlavor]), tells that the values are read when a
///   command starts, so `flutter run` starts again after an edit of `.env`,
///   and shows how a getter of a new key reads its value;
/// - a note in the section of the role in the guide for coding agents of
///   the app, after what the role says there: the commands with the
///   argument, the restart after an edit of `.env`, and how a getter reads
///   its value.
///
/// The last line of `smf create` stays `flutter run`: right after the app
/// is generated, every value of `.env` is empty, so the app is the same
/// without the argument.
final class DartDefineModule extends SmfModule {
  /// Creates the module.
  const DartDefineModule();

  /// The id of the module.
  static const id = ModuleId('dart_define');

  /// The heading of the section of the module in the README of the app.
  static const readmeHeading = 'Run, test and build with .env';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Values of .env with --dart-define-from-file',
        kind: ModuleKinds.infrastructure,
        providers: [_DartDefineProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(dartDefineBundle),
        envRole.data(const EnvToolArguments([_toolArgument])),
        AppEntryRole.readmeSections.entry(readmeHeading, _readmeSection),
        AppEntryRole.agentSections.entry(
          envRole.description,
          AgentNote(agentNote),
        ),
      ];
}

/// The section of the module in the README of the app: the commands with
/// the argument, when the values are read, and the getter of a new key. What
/// `.env` is for, its keys and the run configurations that pass the argument
/// are in the section of the role.
final String _readmeSection = '''
`AppEnv` in `${EnvRole.readerFile}` reads each value of `${EnvRole.dotEnvFile}` with `String.fromEnvironment`. The `flutter` tool reads `${EnvRole.dotEnvFile}` when a command that builds, runs or tests the app starts, given `$_toolArgument`, and compiles each value into the app. Without the argument, every getter of `AppEnv` is `null`, so give it to each such command:

```bash
flutter run $_toolArgument
flutter test $_toolArgument
flutter build apk --flavor $_storeFlavor $_toolArgument
flutter build appbundle --flavor $_storeFlavor $_toolArgument
flutter build ipa --flavor $_storeFlavor $_toolArgument
```

A build without `--flavor` is a release of `${AppEntryRole.defaultFlavor.name}`, so name the flavor; the section "${AppEntryRole.flavorsHeading}" has more.

A command reads the values only when it starts: after you change `${EnvRole.dotEnvFile}`, stop `flutter run` and start it again. Hot reload and hot restart keep the values that the app was built with.

To read a key of your own, give `AppEnv` a getter for it, as for the other keys:

```dart
static String? get myServiceKey {
  const value = String.fromEnvironment('MY_SERVICE_KEY');
  return value.isEmpty ? null : value;
}
```

The section "${EnvRole.readmeHeading}" tells what goes into `${EnvRole.dotEnvFile}`, lists the keys of the app and names the run configurations that pass the argument.
''';

/// The provider of the env role: its render hook writes a getter of
/// `AppEnv` for each key of the app.
final class _DartDefineProvider extends RoleProvider<EnvData> {
  const _DartDefineProvider();

  @override
  Role<EnvData> get role => envRole;

  @override
  RoleOutput render(RoleHookInput<EnvData> input) => RoleOutput(
        vars: {
          'app_env_getters': Fragment(_gettersOf(envRole.keysIn(input))),
        },
      );
}

/// The getters of `AppEnv` for [keys], in their order, with an empty line
/// between two of them.
String _gettersOf(List<AppEnvKey> keys) => keys.map(_getterOf).join('\n\n');

/// The getter of `AppEnv` for [key], at the indent of a member of a class:
/// its description as its doc, and the value of the key, or `null` for an
/// empty one, since `KEY=` in `.env` defines an empty value rather than
/// none.
String _getterOf(AppEnvKey key) => [
      for (final line in _docOf(key.description)) '$_memberDoc$line',
      '  static String? get ${key.getter} {',
      "    const value = String.fromEnvironment('${key.name}');",
      '    return value.isEmpty ? null : value;',
      '  }',
    ].join('\n');

/// The start of a line of the doc of a member of a class.
const _memberDoc = '  /// ';

/// The width of the lines of the doc of a getter.
const _width = 80;

/// The lines of the doc of a getter of `AppEnv` with [description], each
/// without the start of a line of a doc: the description as a sentence,
/// wrapped at [_width] between its words and outside its code spans. A word
/// longer than a line, such as a long code span, stays on a line of its
/// own.
///
/// A `<` outside a code span is escaped, since Markdown would take it for
/// the start of an HTML tag, which the analyzer of the app reports
/// (`unintended_html_in_doc_comment`) and `flutter analyze` fails on. As in
/// Markdown, a code span starts at a run of backticks and ends at the next
/// run of as many, and a run that no such run follows is text.
List<String> _docOf(String description) =>
    _linesOf(_wordsOf(_sentenceOf(description)));

/// The words of [text], separated by its spaces outside its code spans,
/// each code span in its word, and with each `<` outside a code span
/// escaped; see [_docOf].
List<String> _wordsOf(String text) {
  final words = <String>[''];
  var index = 0;
  while (index < text.length) {
    final char = text[index];
    if (char == '`') {
      final end = _backtickEnd(text, index);
      words.last += text.substring(index, end);
      index = end;
      continue;
    }
    if (char == ' ') {
      words.add('');
    } else {
      words.last += char == '<' ? r'\<' : char;
    }
    index++;
  }
  return words;
}

/// [words] wrapped at [_width]: on lines of a doc of a member of a class,
/// with one space between two words, and a word longer than a line on a
/// line of its own; see [_docOf].
List<String> _linesOf(List<String> words) {
  final lines = <String>[];
  var line = '';
  for (final word in words) {
    if (word.isEmpty) continue;
    if (line.isEmpty) {
      line = word;
    } else if (_memberDoc.length + line.length + 1 + word.length > _width) {
      lines.add(line);
      line = word;
    } else {
      line = '$line $word';
    }
  }
  return [...lines, line];
}

/// Where what starts with the run of backticks at [index] of [text] ends:
/// the code span that the run opens, up to the next run of as many
/// backticks, or the run alone, which is text, when no such run follows.
int _backtickEnd(String text, int index) {
  final run = _backticksAt(text, index);
  final close = _closingRun(text, index + run, run);
  return close == null ? index + run : close + run;
}

/// The number of the backticks in [text] from [index] on.
int _backticksAt(String text, int index) {
  var end = index;
  while (end < text.length && text[end] == '`') {
    end++;
  }
  return end - index;
}

/// Where the first run of exactly [length] backticks in [text] from [from]
/// on starts, which closes a code span that such a run opened, or `null`.
int? _closingRun(String text, int from, int length) {
  var index = from;
  while (index < text.length) {
    if (text[index] != '`') {
      index++;
      continue;
    }
    final run = _backticksAt(text, index);
    if (run == length) return index;
    index += run;
  }
  return null;
}

/// [description] as a sentence: with a period at its end unless it ends
/// with a mark that ends a sentence or opens what follows, such as a colon.
String _sentenceOf(String description) =>
    RegExp(r'[.!?…:;]$').hasMatch(description) ? description : '$description.';
