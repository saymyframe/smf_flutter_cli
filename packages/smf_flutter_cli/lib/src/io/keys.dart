import 'dart:convert';

import 'package:smf_flutter_cli/src/io/prompter.dart';

/// Reads the keys that a terminal in raw mode sends as bytes.
final class KeyDecoder {
  /// Creates the decoder of the bytes of [next], which waits for a byte and
  /// returns -1 at the end of the input, and [soon], which returns a byte
  /// that comes at once, as the rest of an escape sequence does, or -1.
  const KeyDecoder({required int Function() next, required int Function() soon})
      : _next = next,
        _soon = soon;

  final int Function() _next;
  final int Function() _soon;

  /// Waits for the next key.
  PromptKey readKey() {
    final byte = _next();
    switch (byte) {
      case < 0:
        return const PromptKey.control(PromptControl.endOfInput);
      case 0x03:
        return const PromptKey.control(PromptControl.interrupt);
      case 0x04:
        return const PromptKey.control(PromptControl.ctrlD);
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
      case < 0xc2 || >= 0xf5:
        // Not the first byte of a character in UTF-8.
        return const PromptKey.control(PromptControl.other);
    }
    final length = byte >= 0xf0 ? 4 : (byte >= 0xe0 ? 3 : 2);
    final bytes = [byte];
    while (bytes.length < length) {
      final next = _soon();
      if (next < 0) break;
      bytes.add(next);
    }
    return PromptKey.character(utf8.decode(bytes, allowMalformed: true));
  }

  /// The key of an escape sequence, such as `ESC [ A` for the up arrow, or
  /// of the Escape key alone.
  PromptKey _escape() {
    final kind = _soon();
    if (kind != 0x5b && kind != 0x4f) {
      return const PromptKey.control(PromptControl.other);
    }
    var last = _soon();
    // Parameters, as in `ESC [ 1 ; 5 A`, come before the final byte.
    while (last >= 0x30 && last <= 0x3f) {
      last = _soon();
    }
    return switch (last) {
      0x41 => const PromptKey.control(PromptControl.up),
      0x42 => const PromptKey.control(PromptControl.down),
      _ => const PromptKey.control(PromptControl.other),
    };
  }
}
