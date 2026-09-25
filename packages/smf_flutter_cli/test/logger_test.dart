import 'dart:convert';
import 'dart:io';

import 'package:smf_flutter_cli/src/io/logger.dart';
import 'package:test/test.dart';

/// A standard stream that records what is written to it, which is a
/// [terminal] or not.
final class _Stream implements Stdout {
  _Stream({this.terminal = false});

  final bool terminal;
  final text = StringBuffer();

  @override
  void write(Object? object) => text.write(object);

  @override
  void writeln([Object? object = '']) => text.writeln(object);

  @override
  bool get hasTerminal => terminal;

  @override
  int get terminalColumns => 80;

  @override
  bool get supportsAnsiEscapes => false;

  @override
  Encoding get encoding => utf8;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Runs [body] with the standard output and error recorded, and returns
/// them; the output is a [terminal] or not.
(String, String) _capture(void Function() body, {bool terminal = false}) {
  final out = _Stream(terminal: terminal);
  final err = _Stream();
  IOOverrides.runZoned(body, stdout: () => out, stderr: () => err);
  return ('${out.text}', '${err.text}');
}

void main() {
  test('reports messages, and details only when verbose', () {
    final (out, err) = _capture(() {
      IoLogger(verbose: false)
        ..info('info')
        ..detail('hidden')
        ..success('done')
        ..warn('careful')
        ..error('broken');
      IoLogger(verbose: true).detail('shown');
    });

    expect(out, 'info\ndone\nshown\n');
    expect(err, '[WARN] careful\nbroken\n');
  });

  test('without a terminal, a progress is a line when it starts and ends', () {
    final (out, _) = _capture(() {
      final logger = IoLogger(verbose: false, terminal: false);
      logger.progress('Getting').complete();
      logger.progress('Formatting')
        ..update('Formatting again')
        ..fail();
      logger.progress('Fixing').complete('Fixed');
    });

    expect(
      out,
      matches(
        RegExp(
          r'^Getting\.\.\.\n✓ Getting \(\d+\.\ds\)\n'
          r'Formatting\.\.\.\nFormatting again\.\.\.\n'
          r'✗ Formatting again \(\d+\.\ds\)\n'
          r'Fixing\.\.\.\n✓ Fixed \(\d+\.\ds\)\n$',
        ),
      ),
    );
  });

  test('in a terminal, a progress animates and ends on its line', () {
    final (out, _) = _capture(
      () {
        IoLogger(verbose: false, terminal: true).progress('Getting')
          ..update('Still getting')
          ..complete('Got');
      },
      terminal: true,
    );

    expect(out, contains('Still getting...'));
    expect(out, matches(RegExp(r'\x1b\[\?7h\x1b\[2K\r.*✓.* Got .*\n$')));
  });

  test('in a terminal, a message clears the line of the progress first', () {
    final (out, _) = _capture(() {
      final logger = IoLogger(verbose: false, terminal: true);
      final progress = logger.progress('Getting');
      logger.info('meanwhile');
      progress.complete();
      logger.info('after');
    });

    expect(out, contains('\u001b[2K\r\u001b[?7hmeanwhile\n'));
    expect(out, isNot(contains('\u001b[2K\r\u001b[?7hafter')));
  });
}
