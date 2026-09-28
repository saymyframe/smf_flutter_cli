import 'dart:ffi';
import 'dart:io' as io;

import 'package:ffi/ffi.dart';
import 'package:smf_flutter_cli/src/io/keys.dart';
import 'package:smf_flutter_cli/src/io/prompter.dart';

/// Undoes, as far as it can, what a question or the animation of a progress
/// changes in the terminal of [device], by default that of the process:
/// shows the cursor, lets long lines wrap again, and echoes keys again, for
/// a process that quits in the middle of them.
void restoreTerminal([TerminalDevice device = const _IoTerminalDevice()]) {
  try {
    if (device.stdoutHasTerminal) device.write('\x1b[?7h\x1b[?25h');
    if (device.stdinHasTerminal) {
      device
        ..lineMode = true
        ..echoMode = true;
    }
  } on Object {
    // The terminal is gone.
  }
}

/// The terminal of the process: keys from the standard input, text to the
/// standard output.
///
/// In raw mode the terminal neither echoes keys nor waits for a whole line,
/// and Ctrl-C comes as a key rather than as a signal that would stop the
/// process before it could restore the terminal. On macOS and Linux, `stty`
/// switches the terminal and restores its exact settings; on Windows, the
/// mode and the code page of the console. If neither works, Ctrl-C stays a
/// signal, which takes effect only once the question has its answer, since
/// reading the key blocks the process.
final class IoPromptTerminal implements PromptTerminal {
  /// Creates the terminal of [device], by default that of the process.
  IoPromptTerminal([TerminalDevice device = const _IoTerminalDevice()])
      : _device = device;

  final TerminalDevice _device;
  String? _sttySettings;
  (int, int)? _console;
  var _dartModes = false;

  @override
  int get columns => _device.stdoutHasTerminal ? _device.terminalColumns : 80;

  @override
  void write(String text) => _device.write(text);

  @override
  void enterRawMode() {
    if (_device.isWindows) {
      _console = _device.enterConsoleRawMode();
      if (_console != null) return;
    } else {
      final settings = _device.stty('-g');
      // A read returns after a tenth of a second without a key, so a lone
      // Escape is not taken for the start of a sequence.
      if (settings != null &&
          _device.stty('-icanon -echo -isig -iexten min 0 time 1') != null) {
        _sttySettings = settings.trim();
        return;
      }
    }
    // Marked first, so that leaving restores what entering changed even if
    // it failed halfway. On Windows, dart:io turns line mode off only with
    // the echo off, and the echo on only with line mode on.
    _dartModes = true;
    _device
      ..echoMode = false
      ..lineMode = false;
  }

  @override
  void leaveRawMode() {
    if (_sttySettings case final settings?) {
      _device.stty("'$settings'");
      _sttySettings = null;
    }
    if (_console case final console?) {
      _device.restoreConsole(console);
      _console = null;
    }
    if (_dartModes) {
      _dartModes = false;
      try {
        _device.lineMode = true;
      } finally {
        _device.echoMode = true;
      }
    }
  }

  /// The next byte of the input, waiting for it; -1 at the end of the input.
  int _byte() {
    while (true) {
      final byte = _device.readByte();
      // With stty's timeout, no byte means no key yet.
      if (byte >= 0 || _sttySettings == null) return byte;
    }
  }

  /// The next byte of the input if it comes at once, as the rest of an
  /// escape sequence does, or -1.
  int _byteSoon() => _device.readByte();

  @override
  PromptKey readKey() => KeyDecoder(next: _byte, soon: _byteSoon).readKey();
}

/// What [IoPromptTerminal] and [restoreTerminal] need of the operating
/// system: the standard input and output, `stty`, and the console of
/// Windows.
abstract interface class TerminalDevice {
  /// Whether the machine runs Windows.
  bool get isWindows;

  /// Whether the standard input is a terminal.
  bool get stdinHasTerminal;

  /// Whether the standard output is a terminal.
  bool get stdoutHasTerminal;

  /// The width of the terminal of the standard output in characters.
  int get terminalColumns;

  /// Writes [text] to the standard output.
  void write(String text);

  /// Whether the terminal waits for a whole line of input.
  bool get lineMode;
  set lineMode(bool value);

  /// Whether the terminal echoes the keys of the input.
  bool get echoMode;
  set echoMode(bool value);

  /// Reads a byte of the standard input, waiting for it as the terminal
  /// says; -1 when none comes.
  int readByte();

  /// Runs `stty` with [arguments] on the terminal and returns its output,
  /// or `null` if it fails.
  String? stty(String arguments);

  /// Switches the console of Windows to raw input in UTF-8, with the arrow
  /// keys as escape sequences, and returns its mode and code page before,
  /// or `null` if it cannot.
  (int, int)? enterConsoleRawMode();

  /// Restores the mode and code page of the console of Windows, [console].
  void restoreConsole((int, int) console);
}

// coverage:ignore-start
// The terminal of a user and the console of Windows, which no test has; the
// tests give IoPromptTerminal and restoreTerminal a device of their own. This
// is checked by hand in the terminals of macOS and Linux and in the console
// of Windows.

/// The terminal of the process, through `dart:io`, `stty` and
/// `kernel32.dll`.
final class _IoTerminalDevice implements TerminalDevice {
  const _IoTerminalDevice();

  @override
  bool get isWindows => io.Platform.isWindows;

  @override
  bool get stdinHasTerminal => io.stdin.hasTerminal;

  @override
  bool get stdoutHasTerminal => io.stdout.hasTerminal;

  @override
  int get terminalColumns => io.stdout.terminalColumns;

  @override
  void write(String text) => io.stdout.write(text);

  @override
  bool get lineMode => io.stdin.lineMode;

  @override
  set lineMode(bool value) => io.stdin.lineMode = value;

  @override
  bool get echoMode => io.stdin.echoMode;

  @override
  set echoMode(bool value) => io.stdin.echoMode = value;

  @override
  int readByte() => io.stdin.readByteSync();

  @override
  String? stty(String arguments) {
    try {
      final result = io.Process.runSync(
        '/bin/sh',
        ['-c', 'stty $arguments < /dev/tty'],
      );
      return result.exitCode == 0 ? '${result.stdout}' : null;
    } on io.ProcessException {
      return null;
    }
  }

  @override
  (int, int)? enterConsoleRawMode() => _WindowsConsole.enterRawMode();

  @override
  void restoreConsole((int, int) console) => _WindowsConsole.restore(console);
}

/// The mode and the code page of the Windows console, through
/// `kernel32.dll`.
abstract final class _WindowsConsole {
  static const _stdInputHandle = -10;
  static const _utf8CodePage = 65001;
  static const _processedInput = 0x0001;
  static const _lineInput = 0x0002;
  static const _echoInput = 0x0004;
  static const _virtualTerminalInput = 0x0200;

  static final _kernel32 = DynamicLibrary.open('kernel32.dll');

  static final int Function(int) _getStdHandle =
      _kernel32.lookupFunction<IntPtr Function(Uint32), int Function(int)>(
    'GetStdHandle',
  );

  static final int Function(int, Pointer<Uint32>) _getConsoleMode =
      _kernel32.lookupFunction<Int32 Function(IntPtr, Pointer<Uint32>),
          int Function(int, Pointer<Uint32>)>('GetConsoleMode');

  static final int Function(int, int) _setConsoleMode = _kernel32
      .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
    'SetConsoleMode',
  );

  static final int Function() _getConsoleCP = _kernel32
      .lookupFunction<Uint32 Function(), int Function()>('GetConsoleCP');

  static final int Function(int) _setConsoleCP =
      _kernel32.lookupFunction<Int32 Function(Uint32), int Function(int)>(
    'SetConsoleCP',
  );

  static int get _input => _getStdHandle(_stdInputHandle);

  /// Switches the console to raw input in UTF-8, with the arrow keys as
  /// escape sequences, and returns the mode and code page to restore, or
  /// `null` if it cannot.
  static (int, int)? enterRawMode() {
    try {
      final mode = calloc<Uint32>();
      try {
        if (_getConsoleMode(_input, mode) == 0) return null;
        final original = mode.value;
        final raw = original & ~(_processedInput | _lineInput | _echoInput);
        if (_setConsoleMode(_input, raw | _virtualTerminalInput) == 0 &&
            _setConsoleMode(_input, raw) == 0) {
          return null;
        }
        final codePage = _getConsoleCP();
        _setConsoleCP(_utf8CodePage);
        return (original, codePage);
      } finally {
        calloc.free(mode);
      }
    } on Object {
      return null;
    }
  }

  /// Restores the console mode and code page of [console].
  static void restore((int, int) console) {
    try {
      final (mode, codePage) = console;
      _setConsoleMode(_input, mode);
      if (codePage != 0) _setConsoleCP(codePage);
    } on Object {
      // The console is gone.
    }
  }
}
// coverage:ignore-end
