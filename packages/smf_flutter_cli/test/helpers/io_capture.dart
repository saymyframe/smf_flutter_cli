import 'dart:async';
import 'dart:io';

import 'package:mocktail/mocktail.dart';

/// In-memory [Stdout] that is not attached to a terminal by default.
class FakeStdout extends Fake implements Stdout {
  FakeStdout({this.hasTerminal = false, this.columns = 80});

  final StringBuffer _buffer = StringBuffer();

  final int columns;

  @override
  final bool hasTerminal;

  String get text => _buffer.toString();

  @override
  int get terminalColumns {
    if (!hasTerminal) throw const StdoutException('No terminal attached');
    return columns;
  }

  @override
  bool get supportsAnsiEscapes => false;

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);
}

/// Output captured by [captureOutput].
typedef CapturedOutput = ({String stdout, String printed});

/// Runs [body] with `stdout` redirected to a [FakeStdout] and `print`
/// captured, so nothing reaches the real terminal.
Future<CapturedOutput> captureOutput(FutureOr<void> Function() body) async {
  final fakeStdout = FakeStdout();
  final printed = StringBuffer();

  await IOOverrides.runZoned(
    () => runZoned(
      () async => body(),
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, line) => printed.writeln(line),
      ),
    ),
    stdout: () => fakeStdout,
  );

  return (stdout: fakeStdout.text, printed: printed.toString());
}
