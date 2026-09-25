import 'dart:io';

import 'package:file/local.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_cli/src/io/logger.dart';
import 'package:smf_flutter_cli/src/io/process_runner.dart';
import 'package:smf_flutter_cli/src/io/prompter.dart';
import 'package:test/test.dart';

void main() {
  test('the host is this machine', () {
    final machine = IoHost(verbose: false, interruption: Interruption());
    final host = machine.host;

    expect(host.logger, same(machine.logger));
    expect(host.logger, isA<IoLogger>());
    expect(host.prompter, isA<TerminalPrompter>());
    expect(host.processRunner, isA<IoProcessRunner>());
    expect(host.fileSystem, isA<LocalFileSystem>());
    expect(host.environmentVariables, Platform.environment);
    expect(
      host.operatingSystem,
      switch (Platform.operatingSystem) {
        'macos' => HostOperatingSystem.macos,
        'linux' => HostOperatingSystem.linux,
        'windows' => HostOperatingSystem.windows,
        _ => HostOperatingSystem.other,
      },
    );
    // The tests run without a terminal.
    expect(host.hasTerminal, stdin.hasTerminal && stdout.hasTerminal);
  });
}
