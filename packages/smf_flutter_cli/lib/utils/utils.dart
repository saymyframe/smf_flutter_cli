import 'dart:io';

int get terminalLineLength {
  if (stdout.hasTerminal) {
    return stdout.terminalColumns;
  }

  return 80;
}

int get maxIntValue => -1 >>> 1;

/// 'My App' -> 'my_app'
String toSnakeCase(String input) {
  return input
      .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
      .replaceAll(RegExp('[^a-zA-Z0-9]+'), '_')
      .replaceAll(RegExp('_+'), '_')
      .replaceAll(RegExp('^_|_ '), '')
      .toLowerCase();
}
