import 'dart:math';

import 'package:mason_logger/mason_logger.dart' show darkGray, green, lightCyan;
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_flutter_cli/src/io/interruption.dart';

/// A key the user pressed.
final class PromptKey {
  /// A key that types [character].
  const PromptKey.character(String this.character) : control = null;

  /// A key that controls the prompt.
  const PromptKey.control(PromptControl this.control) : character = null;

  /// What the key types, if it is not a [control].
  final String? character;

  /// What the key does, if it types no [character].
  final PromptControl? control;

  @override
  String toString() => character ?? '$control';
}

/// The keys that control a prompt.
enum PromptControl {
  /// Enter or return.
  enter,

  /// Backspace or delete.
  backspace,

  /// The up arrow.
  up,

  /// The down arrow.
  down,

  /// Ctrl-C.
  interrupt,

  /// Ctrl-D, or the end of the input.
  endOfInput,

  /// Any other key.
  other,
}

/// The terminal a [TerminalPrompter] asks in.
abstract interface class PromptTerminal {
  /// Makes [readKey] get every key as it is pressed, without echoing it, and
  /// Ctrl-C as a key rather than a signal.
  void enterRawMode();

  /// Restores the terminal as it was before [enterRawMode].
  void leaveRawMode();

  /// Waits for the next key.
  PromptKey readKey();

  /// Writes [text] at the cursor.
  void write(String text);

  /// The width of the terminal in characters.
  int get columns;
}

/// Asks the user in a terminal: a choice with the arrow keys, several with
/// the space bar, a line of text, or yes or no.
///
/// Ctrl-C, Ctrl-D or the end of the input cancel the question: it throws an
/// [SmfCancelledException] and marks the run interrupted.
/// The terminal is restored whatever happens.
final class TerminalPrompter implements SmfPrompter {
  /// Creates the prompter that asks in a terminal, and says [greeting]
  /// before its first question, if given.
  TerminalPrompter(
    this._terminal, {
    required Interruption interruption,
    String? greeting,
  })  : _interruption = interruption,
        _greeting = greeting;

  final PromptTerminal _terminal;
  final Interruption _interruption;
  String? _greeting;

  static const _hideCursor = '\x1b[?25l';
  static const _showCursor = '\x1b[?25h';

  /// Moves the cursor up [lines] lines, to the start of the line, and clears
  /// the screen below it.
  static String _upAndClear(int lines) =>
      '${lines > 0 ? '\x1b[${lines}A' : ''}\r\x1b[J';

  Future<T> _ask<T>(String question, T Function() answer) async {
    _interruption.throwIfInterrupted();
    if (_greeting case final greeting?) {
      _terminal.write('$greeting\n');
      _greeting = null;
    }
    _terminal
      ..enterRawMode()
      ..write('${green.wrap('?')} $question');
    try {
      return answer();
    } on SmfCancelledException {
      _interruption.markInterrupted();
      rethrow;
    } finally {
      _terminal
        ..write(_showCursor)
        ..leaveRawMode();
    }
  }

  /// Writes the [answer] to [question] where the question started, [lines]
  /// lines up.
  void _answered(String question, String answer, {int lines = 0}) =>
      _terminal.write(
        '${_upAndClear(lines)}${green.wrap('?')} $question '
        '${lightCyan.wrap(answer)}\n',
      );

  /// Throws an [SmfCancelledException] if [key] cancels the question.
  void _cancelOn(PromptKey key, {bool endOfInput = true}) {
    if (key.control == PromptControl.interrupt ||
        (endOfInput && key.control == PromptControl.endOfInput)) {
      _terminal.write('\n');
      throw const SmfCancelledException();
    }
  }

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) =>
      _ask('$message ${darkGray.wrap(defaultValue ? '(Y/n)' : '(y/N)')} ', () {
        while (true) {
          final key = _terminal.readKey();
          _cancelOn(key);
          final answer = switch ((key.control, key.character?.toLowerCase())) {
            (PromptControl.enter, _) => defaultValue,
            (_, 'y') => true,
            (_, 'n') => false,
            _ => null,
          };
          if (answer == null) continue;
          _answered(message, answer ? 'Yes' : 'No');
          return answer;
        }
      });

  @override
  Future<String> input(String message, {String? defaultValue}) {
    final question = defaultValue == null
        ? '$message:'
        : '$message ${darkGray.wrap('($defaultValue)')}:';
    return _ask('$question ', () {
      final typed = <String>[];
      while (true) {
        final key = _terminal.readKey();
        _cancelOn(key, endOfInput: typed.isEmpty);
        switch (key) {
          case PromptKey(control: PromptControl.enter):
            final text = typed.join().trim();
            final answer = text.isEmpty ? defaultValue ?? '' : text;
            _answered(message, answer);
            return answer;
          case PromptKey(control: PromptControl.backspace):
            if (typed.isNotEmpty) {
              typed.removeLast();
              _terminal.write('\b \b');
            }
          case PromptKey(:final character?):
            typed.add(character);
            _terminal.write(character);
          case _:
            break;
        }
      }
    });
  }

  @override
  Future<T> select<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    T? defaultValue,
  }) {
    final labels = [
      for (final choice in choices) display?.call(choice) ?? '$choice',
    ];
    return _ask(
      '$message ${darkGray.wrap('(↑↓ to move, enter to choose)')}\n'
      '$_hideCursor',
      () {
        var index =
            defaultValue == null ? 0 : max(choices.indexOf(defaultValue), 0);
        _list(labels, (i) => i == index, marks: false);
        while (true) {
          final key = _terminal.readKey();
          _cancelOn(key);
          switch (key) {
            case PromptKey(control: PromptControl.up) ||
                  PromptKey(character: 'k'):
              index = (index - 1) % choices.length;
            case PromptKey(control: PromptControl.down) ||
                  PromptKey(character: 'j'):
              index = (index + 1) % choices.length;
            case PromptKey(control: PromptControl.enter):
              _answered(message, labels[index], lines: labels.length + 1);
              return choices[index];
            case _:
              continue;
          }
          _list(labels, (i) => i == index, marks: false, again: true);
        }
      },
    );
  }

  @override
  Future<List<T>> multiSelect<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    List<T> defaultValues = const [],
  }) {
    final labels = [
      for (final choice in choices) display?.call(choice) ?? '$choice',
    ];
    return _ask(
      '$message '
      '${darkGray.wrap('(↑↓ to move, space to select, enter to confirm)')}\n'
      '$_hideCursor',
      () {
        final selected = {
          for (final value in defaultValues)
            if (choices.indexOf(value) case final i when i >= 0) i,
        };
        var index = 0;
        void draw({bool again = false}) => _list(
              labels,
              (i) => i == index,
              selected: selected.contains,
              again: again,
            );
        draw();
        while (true) {
          final key = _terminal.readKey();
          _cancelOn(key);
          switch (key) {
            case PromptKey(control: PromptControl.up) ||
                  PromptKey(character: 'k'):
              index = (index - 1) % choices.length;
            case PromptKey(control: PromptControl.down) ||
                  PromptKey(character: 'j'):
              index = (index + 1) % choices.length;
            case PromptKey(character: ' '):
              if (!selected.remove(index)) selected.add(index);
            case PromptKey(control: PromptControl.enter):
              final chosen = [
                for (var i = 0; i < choices.length; i++)
                  if (selected.contains(i)) i,
              ];
              _answered(
                message,
                chosen.isEmpty
                    ? 'none'
                    : [for (final i in chosen) labels[i]].join(', '),
                lines: labels.length + 1,
              );
              return [for (final i in chosen) choices[i]];
            case _:
              continue;
          }
          draw(again: true);
        }
      },
    );
  }

  /// Writes [labels] one per line, with a pointer at the one that is
  /// [current] and, with [marks], whether each is [selected]; [again]
  /// writes them over the list written before.
  void _list(
    List<String> labels,
    bool Function(int index) current, {
    bool Function(int index)? selected,
    bool marks = true,
    bool again = false,
  }) {
    final text = StringBuffer(again ? _upAndClear(labels.length) : '');
    // A line that wraps would move the list; keep each within the width.
    final width = max(_terminal.columns - 5, 10);
    for (var i = 0; i < labels.length; i++) {
      final label = labels[i].length > width
          ? '${labels[i].substring(0, width - 1)}…'
          : labels[i];
      final pointer = current(i) ? green.wrap('❯')! : ' ';
      final mark = !marks
          ? ''
          : (selected?.call(i) ?? false)
              ? '${lightCyan.wrap('◉')} '
              : '◯ ';
      final shown = current(i) ? lightCyan.wrap(label) : label;
      text.write('$pointer $mark$shown\n');
    }
    _terminal.write(text.toString());
  }
}
