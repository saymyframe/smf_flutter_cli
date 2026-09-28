/// The Ruby of the machine, for the tests that run it.
library;

import 'dart:io';

/// The Ruby on the `PATH`, or `null` without one, or without `which` to find
/// it.
String? rubyOnPath() {
  final ProcessResult result;
  try {
    result = Process.runSync('which', ['ruby']);
  } on ProcessException {
    return null;
  }
  final path = result.stdout.toString().trim();
  return result.exitCode == 0 && path.isNotEmpty ? path : null;
}

/// The Rubies that a user of this machine may run a command of SMF with:
/// the one on the `PATH` and, on macOS, the Ruby of macOS in `/usr/bin`,
/// which is the one on the `PATH` unless another Ruby is installed.
List<String> rubiesOfMachine() => {
      if (rubyOnPath() case final ruby?) ruby,
      if (Platform.isMacOS && File('/usr/bin/ruby').existsSync())
        '/usr/bin/ruby',
    }.toList();
