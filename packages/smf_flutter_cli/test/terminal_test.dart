import 'package:smf_flutter_cli/src/io/prompter.dart';
import 'package:smf_flutter_cli/src/io/terminal.dart';
import 'package:test/test.dart';

/// The arguments with which stty switches the terminal to raw mode.
const _raw = '-icanon -echo -isig -iexten min 0 time 1';

/// A terminal device that records what is done with it, such as
/// `stty -g` or `lineMode false`.
///
/// `stty` gives the output in [sttyOutputs] for its arguments, and fails
/// for others; the console of Windows gives [console]; the input gives
/// its bytes, and -1 once they are read.
final class _Device implements TerminalDevice {
  _Device({
    this.isWindows = false,
    this.stdinHasTerminal = true,
    this.stdoutHasTerminal = true,
    this.sttyOutputs = const {},
    this.console,
    List<int> bytes = const [],
    this.lineModeFails = false,
    this.writeFails = false,
  }) : _bytes = [...bytes];

  @override
  final bool isWindows;

  @override
  final bool stdinHasTerminal;

  @override
  final bool stdoutHasTerminal;

  @override
  int get terminalColumns => 100;

  final Map<String, String> sttyOutputs;
  final (int, int)? console;
  final List<int> _bytes;

  /// Whether turning line mode on throws, as it does for a terminal that is
  /// gone.
  final bool lineModeFails;

  /// Whether writing throws, as it does for a terminal that is gone.
  final bool writeFails;

  final List<String> calls = [];

  var _lineMode = true;
  var _echoMode = true;

  @override
  bool get lineMode => _lineMode;

  @override
  set lineMode(bool value) {
    calls.add('lineMode $value');
    if (lineModeFails && value) throw StateError('The terminal is gone.');
    _lineMode = value;
  }

  @override
  bool get echoMode => _echoMode;

  @override
  set echoMode(bool value) {
    calls.add('echoMode $value');
    _echoMode = value;
  }

  @override
  void write(String text) {
    if (writeFails) throw StateError('The terminal is gone.');
    calls.add('write $text');
  }

  @override
  int readByte() => _bytes.isEmpty ? -1 : _bytes.removeAt(0);

  @override
  String? stty(String arguments) {
    calls.add('stty $arguments');
    return sttyOutputs[arguments];
  }

  @override
  (int, int)? enterConsoleRawMode() {
    calls.add('console raw');
    return console;
  }

  @override
  void restoreConsole((int, int) console) =>
      calls.add('console restore $console');
}

void main() {
  group('raw mode', () {
    test('with stty, restores exactly the settings that stty -g gave', () {
      final device = _Device(
        sttyOutputs: {'-g': 'gfmt1:lflag=5cb:min=1\n', _raw: ''},
      );
      final terminal = IoPromptTerminal(device)..enterRawMode();

      expect(device.calls, ['stty -g', 'stty $_raw']);

      terminal.leaveRawMode();

      expect(device.calls.last, "stty 'gfmt1:lflag=5cb:min=1'");
      expect(device.calls, hasLength(3));
    });

    test('without stty, turns off the echo and the line mode of dart:io', () {
      // In this order, which dart:io needs on Windows.
      final device = _Device();
      final terminal = IoPromptTerminal(device)..enterRawMode();

      expect(device.calls, ['stty -g', 'echoMode false', 'lineMode false']);

      terminal.leaveRawMode();

      expect(device.calls.skip(3), ['lineMode true', 'echoMode true']);
    });

    test('a terminal that stty cannot switch goes to the modes of dart:io', () {
      final device = _Device(sttyOutputs: {'-g': 'gfmt1:saved\n'});
      IoPromptTerminal(device)
        ..enterRawMode()
        ..leaveRawMode();

      // stty changed nothing, so it restores nothing.
      expect(device.calls, [
        'stty -g',
        'stty $_raw',
        'echoMode false',
        'lineMode false',
        'lineMode true',
        'echoMode true',
      ]);
    });

    test('turns the echo on again even when the line mode fails', () {
      final device = _Device(lineModeFails: true);
      final terminal = IoPromptTerminal(device)..enterRawMode();

      expect(terminal.leaveRawMode, throwsStateError);
      expect(device.calls.skip(3), ['lineMode true', 'echoMode true']);

      // What it could restore, it did; leaving again does nothing.
      terminal.leaveRawMode();
      expect(device.calls, hasLength(5));
    });

    test(
        'on Windows, switches the console and restores its mode and code '
        'page', () {
      final device = _Device(isWindows: true, console: (0x1f7, 437));
      IoPromptTerminal(device)
        ..enterRawMode()
        ..leaveRawMode();

      expect(device.calls, ['console raw', 'console restore (503, 437)']);
    });

    test('on Windows without a console, turns to the modes of dart:io', () {
      final device = _Device(isWindows: true);
      IoPromptTerminal(device)
        ..enterRawMode()
        ..leaveRawMode();

      expect(device.calls, [
        'console raw',
        'echoMode false',
        'lineMode false',
        'lineMode true',
        'echoMode true',
      ]);
    });
  });

  group('keys', () {
    test('with stty, a read without a key waits for the next key', () {
      // stty makes a read return after a tenth of a second without a key.
      final device = _Device(
        sttyOutputs: {'-g': 'saved', _raw: ''},
        bytes: [-1, -1, 0x61, 0x1b, -1, -1, 0x62],
      );
      final terminal = IoPromptTerminal(device)..enterRawMode();

      expect(
        [for (var i = 0; i < 3; i++) '${terminal.readKey()}'],
        [
          'a',
          // An Escape that nothing follows at once is a key of its own.
          'PromptControl.other',
          'b',
        ],
      );
    });

    test('without stty, a read without a key is the end of the input', () {
      final terminal = IoPromptTerminal(_Device())..enterRawMode();

      expect(terminal.readKey().control, PromptControl.endOfInput);
    });
  });

  test('writes to the output and takes its width, or 80 without a terminal',
      () {
    final device = _Device();
    final terminal = IoPromptTerminal(device)..write('? Which one?');

    expect(device.calls, ['write ? Which one?']);
    expect(terminal.columns, 100);
    expect(IoPromptTerminal(_Device(stdoutHasTerminal: false)).columns, 80);
  });

  group('restoreTerminal', () {
    test('shows the cursor, wraps long lines and echoes keys again', () {
      final device = _Device();

      restoreTerminal(device);

      expect(device.calls, [
        'write \x1b[?7h\x1b[?25h',
        'lineMode true',
        'echoMode true',
      ]);
    });

    test('changes only the streams that are a terminal', () {
      final output = _Device(stdinHasTerminal: false);
      final input = _Device(stdoutHasTerminal: false);

      restoreTerminal(output);
      restoreTerminal(input);

      expect(output.calls, ['write \x1b[?7h\x1b[?25h']);
      expect(input.calls, ['lineMode true', 'echoMode true']);
    });

    test('leaves a terminal that is gone', () {
      expect(
        () => restoreTerminal(_Device(writeFails: true)),
        returnsNormally,
      );
    });
  });
}
