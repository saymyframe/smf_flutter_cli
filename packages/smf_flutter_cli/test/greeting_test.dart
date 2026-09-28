import 'dart:convert';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_cli/src/io/greeting.dart';
import 'package:smf_flutter_cli/src/io/logger.dart';
import 'package:smf_flutter_cli/src/io/prompter.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

/// A module with nothing but a step after generation that the user may
/// leave for later, which a run in a terminal asks about, as it asks about
/// `flutterfire configure` of firebase_core.
final class _LaterModule extends SmfModule {
  const _LaterModule();

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: ModuleId('later'),
        description: 'A step to run now or later (test)',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => const [
        PostGenStep(
          ToolRef('dart'),
          ['run', 'setup'],
          description: 'Setting up the app',
          interactive: true,
          skippable: true,
        ),
      ];
}

/// A terminal that answers with scripted keys and writes into [transcript].
final class _Terminal implements PromptTerminal {
  _Terminal(this.transcript, List<PromptKey> keys) : _keys = [...keys];

  final StringBuffer transcript;
  final List<PromptKey> _keys;

  @override
  void enterRawMode() {}

  @override
  void leaveRawMode() {}

  @override
  PromptKey readKey() => _keys.removeAt(0);

  @override
  void write(String text) => transcript.write(text);

  @override
  int get columns => 200;
}

/// A standard stream that writes into [transcript] too.
final class _Stream implements Stdout {
  _Stream(this.transcript);

  final StringBuffer transcript;

  @override
  void write(Object? object) => transcript.write(object);

  @override
  void writeln([Object? object = '']) => transcript.writeln(object);

  @override
  bool get hasTerminal => false;

  @override
  bool get supportsAnsiEscapes => false;

  @override
  Encoding get encoding => utf8;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Runs `smf create my_app --org com.example` with [options] in a terminal
/// that answers with [keys], on a machine with a Flutter SDK whose commands
/// all succeed, with the prompter and the logger of the CLI, and returns
/// what the terminal showed, without escape sequences.
Future<String> _create(List<String> options, List<PromptKey> keys) async {
  final files = MemoryFileSystem.test();
  files.directory('/sdk/bin/cache/dart-sdk').createSync(recursive: true);
  files.file('/sdk/bin/cache/flutter.version.json').writeAsStringSync(
        '{"flutterVersion": "3.44.2", "dartSdkVersion": "3.12.2"}',
      );
  for (final tool in ['flutter', 'dart']) {
    files.file('/sdk/bin/$tool').createSync();
  }
  files.directory('/work').createSync();
  files.currentDirectory = '/work';
  final transcript = StringBuffer();
  final greeting = Greeting('Hello!');
  final code = await IOOverrides.runZoned(
    () => runSmf(
      ['create', 'my_app', '--org', 'com.example', ...options],
      modules: const [FlutterCoreModule(), _LaterModule()],
      hostFor: ({required verbose}) => SmfHost(
        prompter: TerminalPrompter(
          _Terminal(transcript, keys),
          interruption: Interruption(
            signals: const Stream.empty(),
            exit: (code) => throw StateError('exit $code'),
          ),
          greeting: greeting,
        ),
        processRunner: _Commands(),
        logger: IoLogger(verbose: verbose, terminal: false, greeting: greeting),
        fileSystem: files,
        environmentVariables: const {'PATH': '/sdk/bin'},
        operatingSystem: HostOperatingSystem.macos,
        hasTerminal: true,
      ),
    ),
    stdout: () => _Stream(transcript),
    stderr: () => _Stream(transcript),
  );
  expect(code, SmfExitCodes.success, reason: '$transcript');
  return '$transcript'.replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '');
}

/// Runs every command with success.
final class _Commands implements SmfProcessRunner {
  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
    void Function(String line)? onOutput,
    Duration? timeout,
  }) async =>
      const SmfProcessResult(exitCode: 0);

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) async =>
      0;
}

void main() {
  test(
      'a run whose first question comes at the end of generation, since '
      'every other answer came from the command line, says no greeting in '
      'the middle of its output', () async {
    final shown = await _create(
      ['-m', 'later'],
      [const PromptKey.character('n')],
    );

    expect(
      shown,
      stringContainsInOrder([
        '✓ Rendering the app',
        '? Setting up the app (dart run setup), for later. Run it now? No',
      ]),
    );
    expect(shown, isNot(contains('Hello!')));
  });

  test('a run that asks before it prints anything opens with the greeting',
      () async {
    final shown = await _create(
      const [],
      [const PromptKey.control(PromptControl.enter)],
    );

    expect(shown, startsWith('Hello!\n? Infrastructure: which do you want?'));
    expect('Hello!'.allMatches(shown), hasLength(1));
  });
}
