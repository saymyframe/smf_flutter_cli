import 'dart:async';
import 'dart:io';

import 'package:smf_contracts/lego_core.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_cli/src/io/prompter.dart';
import 'package:test/test.dart';

const _enter = PromptKey.control(PromptControl.enter);
const _up = PromptKey.control(PromptControl.up);
const _down = PromptKey.control(PromptControl.down);
const _backspace = PromptKey.control(PromptControl.backspace);
const _ctrlC = PromptKey.control(PromptControl.interrupt);
const _end = PromptKey.control(PromptControl.endOfInput);
const _ctrlD = PromptKey.control(PromptControl.ctrlD);
const _other = PromptKey.control(PromptControl.other);

PromptKey _key(String character) => PromptKey.character(character);

List<PromptKey> _typed(String text) =>
    [for (final c in text.split('')) _key(c)];

/// A terminal that answers with scripted keys and records what it shows.
final class _Terminal implements PromptTerminal {
  _Terminal(List<PromptKey> keys, {this.columns = 80}) : _keys = [...keys];

  final List<PromptKey> _keys;
  final output = StringBuffer();
  bool raw = false;
  int rawModes = 0;

  @override
  final int columns;

  @override
  void enterRawMode() {
    raw = true;
    rawModes++;
  }

  @override
  void leaveRawMode() => raw = false;

  @override
  PromptKey readKey() {
    expect(raw, isTrue, reason: 'Keys are read in raw mode.');
    if (_keys.isEmpty) throw StateError('No more keys.');
    return _keys.removeAt(0);
  }

  @override
  void write(String text) => output.write(text);

  bool get done => _keys.isEmpty;

  /// What the terminal shows at the end: the text after the last rewrite,
  /// without escape sequences.
  String get shown => output
      .toString()
      .split('\x1b[J')
      .last
      .replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '');
}

void main() {
  late Interruption interruption;

  setUp(() {
    interruption = Interruption(
      signals: const Stream.empty(),
      exit: (code) => throw StateError('exit $code'),
    );
  });

  TerminalPrompter prompter(_Terminal terminal, {String? greeting}) =>
      TerminalPrompter(
        terminal,
        interruption: interruption,
        greeting: greeting,
      );

  group('select', () {
    test('moves with the arrows and chooses with enter', () async {
      final terminal = _Terminal([_down, _down, _up, _other, _enter]);

      final choice = await prompter(terminal).select(
        'Which one?',
        ['a', 'b', 'c'],
        display: (c) => c.toUpperCase(),
      );

      expect(choice, 'b');
      expect(terminal.shown, '? Which one? B\n');
      expect(terminal.raw, isFalse);
      expect(terminal.output.toString(), contains('❯ A\n  B\n  C\n'));
      expect(terminal.output.toString(), endsWith('\x1b[?25h'));
    });

    test('starts at the default, wraps around, and knows j and k', () async {
      final terminal = _Terminal([_key('j'), _down, _key('k'), _enter]);

      expect(
        await prompter(terminal)
            .select('?', ['a', 'b', 'c'], defaultValue: 'c'),
        'a',
      );
    });

    test('writes the answer over a question that wraps', () async {
      final terminal = _Terminal([_down, _enter], columns: 20);

      // "? " and 30 characters and the hint of 31: 63 characters, 4 rows.
      await prompter(terminal).select('x' * 30, ['a', 'b']);

      expect(
        terminal.output.toString(),
        contains('\x1b[6A\r\x1b[J? ${'x' * 30} b\n'),
      );
    });

    test('shortens a label that would wrap', () async {
      final terminal = _Terminal([_enter], columns: 20);

      await prompter(terminal).select('?', ['x' * 40]);

      expect(terminal.output.toString(), contains('❯ ${'x' * 14}…\n'));
    });
  });

  group('multiSelect', () {
    test('selects with space and confirms with enter', () async {
      final terminal = _Terminal([
        _key(' '),
        _down,
        _down,
        _key(' '),
        _up,
        _key(' '),
        _key(' '),
        _enter,
      ]);

      final chosen = await prompter(terminal).multiSelect(
        'Which ones?',
        ['a', 'b', 'c'],
        defaultValues: ['b'],
      );

      expect(chosen, ['a', 'b', 'c']);
      expect(terminal.shown, '? Which ones? a, b, c\n');
      expect(terminal.output.toString(), contains('❯ ◯ a\n  ◉ b\n  ◯ c\n'));
    });

    test('may choose none', () async {
      final terminal = _Terminal([_enter]);

      expect(await prompter(terminal).multiSelect('?', ['a']), isEmpty);
      expect(terminal.shown, '? ? none\n');
    });
  });

  group('input', () {
    test('takes the typed text, with backspace', () async {
      final terminal = _Terminal([
        ..._typed('my_azz'),
        _backspace,
        _backspace,
        _other,
        ..._typed('pp'),
        _enter,
      ]);

      expect(await prompter(terminal).input('App name'), 'my_app');
      expect(terminal.shown, '? App name my_app\n');
      expect(terminal.output.toString(), contains('\b \b'));
    });

    test('writes the answer over a line that wraps', () async {
      final terminal = _Terminal([..._typed('a' * 21), _enter], columns: 20);

      // "? Name: " and 21 characters: 29 characters, 2 rows.
      await prompter(terminal).input('Name');

      expect(
        terminal.output.toString(),
        contains('\x1b[1A\r\x1b[J? Name ${'a' * 21}\n'),
      );
    });

    test('takes the default for an empty line', () async {
      final terminal = _Terminal([_backspace, _key(' '), _enter]);

      expect(
        await prompter(terminal).input('App name', defaultValue: 'my_app'),
        'my_app',
      );
      expect(terminal.output.toString(), contains('? App name (my_app): '));
    });

    test('Ctrl-D cancels only an empty line, the end of the input any',
        () async {
      final terminal = _Terminal([_key('a'), _ctrlD, _enter]);

      expect(await prompter(terminal).input('Name'), 'a');
      expect(
        prompter(_Terminal([_ctrlD])).input('Name'),
        throwsA(isA<SmfCancelledException>()),
      );
      expect(
        prompter(_Terminal([_key('a'), _end])).input('Name'),
        throwsA(isA<SmfCancelledException>()),
      );
    });
  });

  group('confirm', () {
    test('takes y or n at once, and enter for the default', () async {
      expect(
        await prompter(_Terminal([_other, _key('Y')])).confirm('Go?'),
        isTrue,
      );
      expect(
        await prompter(_Terminal([_key('n')]))
            .confirm('Go?', defaultValue: true),
        isFalse,
      );
      final terminal = _Terminal([_enter]);
      expect(
        await prompter(terminal).confirm('Go?', defaultValue: true),
        isTrue,
      );
      expect(terminal.shown, '? Go? Yes\n');
      expect(terminal.output.toString(), contains('(Y/n)'));
    });
  });

  test('says the greeting before the first question only', () async {
    final terminal = _Terminal([_enter, _enter]);
    final asking = prompter(terminal, greeting: 'Hello!');

    await asking.confirm('One?');
    await asking.confirm('Two?');

    expect(terminal.output.toString(), startsWith('Hello!\n? One?'));
    expect('Hello!'.allMatches(terminal.output.toString()), hasLength(1));
  });

  group('cancelling', () {
    final questions = <String, Future<Object?> Function(SmfPrompter p)>{
      'select': (p) => p.select('?', ['a']),
      'multiSelect': (p) => p.multiSelect('?', ['a']),
      'input': (p) => p.input('?'),
      'confirm': (p) => p.confirm('?'),
    };

    for (final MapEntry(key: kind, value: ask) in questions.entries) {
      test('Ctrl-C, Ctrl-D or the end of the input cancels $kind', () async {
        for (final key in [_ctrlC, _ctrlD, _end]) {
          interruption = Interruption(
            signals: const Stream.empty(),
            exit: (code) => throw StateError('exit $code'),
          );
          final terminal = _Terminal([key]);

          await expectLater(
            ask(prompter(terminal)),
            throwsA(isA<SmfCancelledException>()),
          );
          expect(terminal.raw, isFalse);
          expect(terminal.output.toString(), endsWith('\n\x1b[?25h'));
          expect(interruption.interrupted, isTrue);
        }
      });
    }

    test('an interrupted run asks nothing', () async {
      interruption.markInterrupted();
      final terminal = _Terminal(const []);

      await expectLater(
        prompter(terminal).confirm('?'),
        throwsA(isA<SmfCancelledException>()),
      );
      expect(terminal.rawModes, 0);
    });

    test('a signal is left to the interruption', () async {
      final signals = StreamController<ProcessSignal>();
      interruption = Interruption(
        signals: signals.stream,
        exit: (code) => throw StateError('exit $code'),
      )..listen();
      signals.add(ProcessSignal.sigint);
      await pumpEventQueue();

      await expectLater(
        prompter(_Terminal(const [])).input('?'),
        throwsA(isA<SmfCancelledException>()),
      );
      await interruption.close();
    });
  });
}
