import 'dart:io';

import 'package:file/local.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_cli/src/banner.dart';
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
      IoHost.operatingSystemOf(Platform.operatingSystem),
    );
    expect(host.hasTerminal, stdin.hasTerminal && stdout.hasTerminal);
    expect(machine.host, same(host));
  });

  test(
      'says the greeting before the first question, unless the logger has '
      'printed something before', () {
    final machine = IoHost(verbose: false, interruption: Interruption());
    final prompter = machine.host.prompter as TerminalPrompter;

    expect(prompter.greeting, same(machine.greeting));
    expect(machine.greeting.take(), greeting);

    final printed = IoHost(verbose: false, interruption: Interruption());
    IOOverrides.runZoned(
      () => printed.logger.info('Adding flutter_core'),
      stdout: _Discarded.new,
    );
    expect(printed.greeting.take(), isNull);
  });

  test('knows the operating systems by their names', () {
    expect(IoHost.operatingSystemOf('macos'), HostOperatingSystem.macos);
    expect(IoHost.operatingSystemOf('linux'), HostOperatingSystem.linux);
    expect(IoHost.operatingSystemOf('windows'), HostOperatingSystem.windows);
    expect(IoHost.operatingSystemOf('fuchsia'), HostOperatingSystem.other);
  });
}

/// A standard output that discards what is written to it.
final class _Discarded implements Stdout {
  @override
  void write(Object? object) {}

  @override
  void writeln([Object? object = '']) {}

  @override
  bool get hasTerminal => false;

  @override
  bool get supportsAnsiEscapes => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
