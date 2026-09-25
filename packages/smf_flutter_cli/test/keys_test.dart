import 'package:smf_flutter_cli/src/io/keys.dart';
import 'package:smf_flutter_cli/src/io/prompter.dart';
import 'package:test/test.dart';

/// The keys that [groups] of bytes make, each group arriving at once; a
/// sequence ends where no byte comes at once.
List<String> _keys(List<List<int>> groups) {
  final pending = [
    for (final group in groups) [...group],
  ];
  int soon() =>
      pending.isEmpty || pending.first.isEmpty ? -1 : pending.first.removeAt(0);
  int next() {
    while (pending.isNotEmpty && pending.first.isEmpty) {
      pending.removeAt(0);
    }
    return pending.isEmpty ? -1 : pending.first.removeAt(0);
  }

  final decoder = KeyDecoder(next: next, soon: soon);
  final keys = <String>[];
  while (true) {
    final key = decoder.readKey();
    keys.add('$key');
    if (key.control == PromptControl.endOfInput) return keys;
  }
}

void main() {
  test('reads characters, in UTF-8 too', () {
    expect(
      _keys([
        [0x61],
        [0x20],
        [0xc3, 0xa9],
        [0xe2, 0x86, 0x91],
      ]),
      ['a', ' ', 'é', '↑', 'PromptControl.endOfInput'],
    );
  });

  test('reads the keys that control a prompt', () {
    expect(
      _keys([
        [0x0d],
        [0x0a],
        [0x7f],
        [0x08],
        [0x03],
        [0x04],
        [0x01],
      ]),
      [
        'PromptControl.enter',
        'PromptControl.enter',
        'PromptControl.backspace',
        'PromptControl.backspace',
        'PromptControl.interrupt',
        'PromptControl.ctrlD',
        'PromptControl.other',
        'PromptControl.endOfInput',
      ],
    );
  });

  test('reads the arrows and a lone Escape', () {
    expect(
      _keys([
        [0x1b, 0x5b, 0x41],
        [0x1b, 0x5b, 0x42],
        [0x1b, 0x4f, 0x41],
        [0x1b, 0x5b, 0x31, 0x3b, 0x35, 0x42],
        [0x1b, 0x5b, 0x43],
        [0x1b],
        [0x61],
        [0x1b, 0x78],
      ]),
      [
        'PromptControl.up',
        'PromptControl.down',
        'PromptControl.up',
        'PromptControl.down',
        'PromptControl.other',
        // Escape alone, and the key after it is not lost.
        'PromptControl.other',
        'a',
        'PromptControl.other',
        'PromptControl.endOfInput',
      ],
    );
  });

  test('a byte that starts no character is not one', () {
    expect(
      _keys([
        [0x80],
        [0xff],
        [0xc3],
      ]),
      [
        'PromptControl.other',
        'PromptControl.other',
        // The input ended in the middle of a character.
        '�',
        'PromptControl.endOfInput',
      ],
    );
  });
}
