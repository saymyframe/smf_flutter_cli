import 'dart:io';

import 'package:smf_flutter_cli/utils/utils.dart';
import 'package:test/test.dart';

import '../helpers/io_capture.dart';

void main() {
  group('terminalLineLength', () {
    test('uses the terminal width when stdout is a terminal', () {
      final width = IOOverrides.runZoned(
        () => terminalLineLength,
        stdout: () => FakeStdout(hasTerminal: true, columns: 132),
      );

      expect(width, 132);
    });

    test('falls back to 80 columns without a terminal', () {
      final width = IOOverrides.runZoned(
        () => terminalLineLength,
        stdout: FakeStdout.new,
      );

      expect(width, 80);
    });
  });

  group('maxIntValue', () {
    test('is the largest 64-bit signed integer on the VM', () {
      expect(maxIntValue, 0x7FFFFFFFFFFFFFFF);
    });
  });
}
