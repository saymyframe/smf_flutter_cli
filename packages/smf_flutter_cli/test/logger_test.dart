import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart' show overrideAnsiOutput;
import 'package:smf_flutter_cli/src/io/greeting.dart';
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

/// The link of a terminal (OSC 8) to [address] that shows the address.
String _link(String address) => '\x1B]8;;$address\x1B\\$address\x1B]8;;\x1B\\';

void main() {
  group('web addresses', () {
    const guide = 'https://doc.saymyframe.com/setup?steps=a.b,c.d';

    test(
        'are links of the terminal that show the address, where the output '
        'takes the escapes of ANSI', () {
      final (out, err) = overrideAnsiOutput(
        true,
        () => _capture(() {
          IoLogger(verbose: true)
            ..info('Finish the setup by hand in 2 steps:\n  $guide')
            ..detail('Asked http://localhost:8080/x')
            ..success('Read https://doc.saymyframe.com')
            ..warn('See https://saymyframe.com/discord')
            ..error('Broken: https://github.com/saymyframe/smf_flutter_cli');
        }),
      );

      expect(
        out,
        contains('Finish the setup by hand in 2 steps:\n  ${_link(guide)}\n'),
      );
      expect(out, contains(_link('http://localhost:8080/x')));
      expect(out, contains(_link('https://doc.saymyframe.com')));
      expect(err, contains(_link('https://saymyframe.com/discord')));
      expect(
        err,
        contains(_link('https://github.com/saymyframe/smf_flutter_cli')),
      );
    });

    test(
        'leave out the marks that end a sentence, the frame of the banner and '
        'what is no address', () {
      final (out, _) = overrideAnsiOutput(
        true,
        () => _capture(() {
          IoLogger(verbose: false)
            ..info('See https://doc.saymyframe.com/setup. Then run it.')
            ..info('(https://doc.saymyframe.com), and more.')
            ..info('| Docs: https://doc.saymyframe.com      |')
            ..info('Not one: https://[oops');
        }),
      );

      expect(
        out,
        'See ${_link('https://doc.saymyframe.com/setup')}. Then run it.\n'
        '(${_link('https://doc.saymyframe.com')}), and more.\n'
        '| Docs: ${_link('https://doc.saymyframe.com')}      |\n'
        'Not one: https://[oops\n',
      );
    });

    test('stay plain text where the output takes no escapes, as in CI', () {
      final (out, err) = overrideAnsiOutput(
        false,
        () => _capture(() {
          IoLogger(verbose: false)
            ..info('Finish the setup by hand in one step:\n  $guide')
            ..warn('See $guide.');
        }),
      );

      expect(out, 'Finish the setup by hand in one step:\n  $guide\n');
      expect(err, '[WARN] See $guide.\n');
    });
  });

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

  test(
      'drops the greeting once it prints anything, but not for a detail '
      'that it hides', () {
    final greeting = Greeting('Hello!');
    final (out, _) = _capture(
      () => IoLogger(verbose: false, greeting: greeting).detail('hidden'),
    );

    expect(out, isEmpty);
    expect(greeting.take(), 'Hello!');

    final reports = <String, void Function(IoLogger logger)>{
      'info': (logger) => logger.info('Adding flutter_core'),
      'detail when verbose': (logger) => logger.detail('shown'),
      'warn': (logger) => logger.warn('careful'),
      'error': (logger) => logger.error('broken'),
      'success': (logger) => logger.success('done'),
      'progress': (logger) => logger.progress('Rendering the app'),
    };
    for (final MapEntry(key: kind, value: report) in reports.entries) {
      final greeting = Greeting('Hello!');
      _capture(
        () => report(
          IoLogger(verbose: true, terminal: false, greeting: greeting),
        ),
      );

      expect(greeting.take(), isNull, reason: kind);
    }
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

  test('in a terminal, a progress that fails ends on its line with ✗', () {
    final (out, _) = _capture(
      () {
        IoLogger(verbose: false, terminal: true)
            .progress('Getting')
            .fail('Could not get');
      },
      terminal: true,
    );

    expect(out, matches(RegExp(r'\x1b\[2K\r.*✗.* Could not get .*\n$')));
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
