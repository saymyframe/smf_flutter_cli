import 'dart:io';

int get terminalLineLength {
  if (stdout.hasTerminal) {
    return stdout.terminalColumns;
  }

  return 80;
}
