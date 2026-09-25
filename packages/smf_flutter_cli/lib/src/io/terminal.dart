// This file needs the terminal of a user, which no test has.
// coverage:ignore-file

import 'dart:convert';
import 'dart:ffi';
import 'dart:io' as io;

import 'package:ffi/ffi.dart';
import 'package:smf_flutter_cli/src/io/prompter.dart';

/// The terminal of the process: keys from the standard input, text to the
/// standard output.
///
/// In raw mode the terminal neither echoes keys nor waits for a whole line,
/// and Ctrl-C comes as a key rather than as a signal that would stop the
/// process before it could restore the terminal. On macOS and Linux, `stty`
/// switches the terminal and restores its exact settings; on Windows, the
/// mode of the console. If neither works, Ctrl-C stays a signal.
final class IoPromptTerminal implements PromptTerminal {
  String? _sttySettings;
  int? _consoleMode;
  var _dartModes = false;

  @override
  int get columns => io.stdout.hasTerminal ? io.stdout.terminalColumns : 80;

  @override
  void write(String text) => io.stdout.write(text);

  @override
  void enterRawMode() {
    if (io.Platform.isWindows) {
      _consoleMode = _WindowsConsole.enterRawMode();
      if (_consoleMode != null) return;
    } else {
      final settings = _stty('-g');
      if (settings != null &&
          _stty('-icanon -echo -isig -iexten min 1 time 0') != null) {
        _sttySettings = settings.trim();
        return;
      }
    }
    io.stdin
      ..echoMode = false
      ..lineMode = false;
    _dartModes = true;
  }

  @override
  void leaveRawMode() {
    if (_sttySettings case final settings?) {
      _stty("'$settings'");
      _sttySettings = null;
    }
    if (_consoleMode case final mode?) {
      _WindowsConsole.restore(mode);
      _consoleMode = null;
    }
    if (_dartModes) {
      io.stdin
        ..lineMode = true
        ..echoMode = true;
      _dartModes = false;
    }
  }

  /// Runs `stty` with [arguments] on the terminal and returns its output, or
  /// `null` if it fails.
  static String? _stty(String arguments) {
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
  PromptKey readKey() {
    final byte = io.stdin.readByteSync();
    switch (byte) {
      case -1 || 0x04:
        return const PromptKey.control(PromptControl.endOfInput);
      case 0x03:
        return const PromptKey.control(PromptControl.interrupt);
      case 0x0a || 0x0d:
        return const PromptKey.control(PromptControl.enter);
      case 0x08 || 0x7f:
        return const PromptKey.control(PromptControl.backspace);
      case 0x1b:
        return _escape();
      case < 0x20:
        return const PromptKey.control(PromptControl.other);
      case < 0x80:
        return PromptKey.character(String.fromCharCode(byte));
    }
    // A character of more bytes in UTF-8.
    final length = byte >= 0xf0 ? 4 : (byte >= 0xe0 ? 3 : 2);
    final bytes = [byte];
    while (bytes.length < length) {
      final next = io.stdin.readByteSync();
      if (next < 0) break;
      bytes.add(next);
    }
    return PromptKey.character(utf8.decode(bytes, allowMalformed: true));
  }

  /// The key of an escape sequence, such as `ESC [ A` for the up arrow.
  static PromptKey _escape() {
    final kind = io.stdin.readByteSync();
    if (kind != 0x5b && kind != 0x4f) {
      return const PromptKey.control(PromptControl.other);
    }
    var last = io.stdin.readByteSync();
    // Parameters, as in `ESC [ 1 ; 5 A`, come before the final byte.
    while (last >= 0x30 && last <= 0x3f) {
      last = io.stdin.readByteSync();
    }
    return switch (last) {
      0x41 => const PromptKey.control(PromptControl.up),
      0x42 => const PromptKey.control(PromptControl.down),
      _ => const PromptKey.control(PromptControl.other),
    };
  }
}

/// The mode of the Windows console, through `kernel32.dll`.
abstract final class _WindowsConsole {
  static const _stdInputHandle = -10;
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

  static int get _input => _getStdHandle(_stdInputHandle);

  /// Switches the console to raw input, with the arrow keys as escape
  /// sequences, and returns the mode to restore, or `null` if it cannot.
  static int? enterRawMode() {
    try {
      final mode = calloc<Uint32>();
      try {
        if (_getConsoleMode(_input, mode) == 0) return null;
        final original = mode.value;
        final raw = original & ~(_processedInput | _lineInput | _echoInput);
        if (_setConsoleMode(_input, raw | _virtualTerminalInput) != 0 ||
            _setConsoleMode(_input, raw) != 0) {
          return original;
        }
        return null;
      } finally {
        calloc.free(mode);
      }
    } on Object {
      return null;
    }
  }

  /// Restores the console mode [mode].
  static void restore(int mode) {
    try {
      _setConsoleMode(_input, mode);
    } on Object {
      // The console is gone.
    }
  }
}
