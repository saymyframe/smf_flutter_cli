import 'dart:async';
import 'dart:io';

import 'package:smf_contracts/lego_core.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:test/test.dart';

/// What the fake `exit` of a test threw.
final class _Exited implements Exception {
  const _Exited(this.code);

  final int code;
}

/// A process that only records that it was stopped.
final class _Process implements Process {
  final _exit = Completer<int>();
  final List<ProcessSignal> kills = [];

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    kills.add(signal);
    if (!_exit.isCompleted) _exit.complete(-15);
    return true;
  }

  @override
  int get pid => 1;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Stream<List<int>> get stderr => const Stream.empty();
}

void main() {
  late StreamController<ProcessSignal> signals;
  late Interruption interruption;

  Future<void> interrupt() async {
    signals.add(ProcessSignal.sigint);
    await pumpEventQueue();
  }

  setUp(() {
    signals = StreamController<ProcessSignal>();
    interruption = Interruption(
      signals: signals.stream,
      exit: (code) => throw _Exited(code),
    )..listen();
  });

  tearDown(() => interruption.close());

  test('the first Ctrl-C marks the run and stops its commands', () async {
    final process = _Process();
    interruption.track(process);
    expect(interruption.interrupted, isFalse);
    expect(interruption.throwIfInterrupted, returnsNormally);

    await interrupt();

    expect(interruption.interrupted, isTrue);
    expect(process.kills, [ProcessSignal.sigterm]);
    expect(
      interruption.throwIfInterrupted,
      throwsA(isA<SmfCancelledException>()),
    );
  });

  /// Sends [sent] to a new interruption, forwarding them to a command that
  /// owns the terminal if [forwarding], and returns what happened: `restore`
  /// before it quits, and `exit <code>`.
  Future<List<String>> quitting(
    List<ProcessSignal> sent, {
    bool forwarding = false,
  }) async {
    final events = <String>[];
    final stream = StreamController<ProcessSignal>();
    late Interruption quitting;
    // The listener runs in the zone that listens, which catches the exit.
    runZonedGuarded(
      () => quitting = Interruption(
        signals: stream.stream,
        exit: (code) => throw _Exited(code),
        beforeQuit: () => events.add('restore'),
      )..listen(),
      (error, _) => events.add('exit ${(error as _Exited).code}'),
    );
    final done = Completer<void>();
    if (forwarding) {
      unawaited(quitting.whileForwarding(() => done.future));
    }
    sent.forEach(stream.add);
    await pumpEventQueue();
    done.complete();
    await stream.close();
    return events;
  }

  test('a second Ctrl-C restores the terminal and quits with 130', () async {
    expect(
      await quitting([ProcessSignal.sigint, ProcessSignal.sigint]),
      ['restore', 'exit 130'],
    );
  });

  test('SIGTERM stops the run like Ctrl-C', () async {
    expect(await quitting([ProcessSignal.sigterm]), isEmpty);
    expect(
      await quitting([ProcessSignal.sigterm, ProcessSignal.sigint]),
      ['restore', 'exit 130'],
    );
  });

  test('a command that owns the terminal keeps two Ctrl-C, not three',
      () async {
    expect(
      await quitting(
        [ProcessSignal.sigint, ProcessSignal.sigint],
        forwarding: true,
      ),
      isEmpty,
    );
    expect(
      await quitting(
        [ProcessSignal.sigint, ProcessSignal.sigint, ProcessSignal.sigint],
        forwarding: true,
      ),
      ['restore', 'exit 130'],
    );
    // SIGTERM does not go to the command.
    final events = await quitting(
      [ProcessSignal.sigterm, ProcessSignal.sigterm],
      forwarding: true,
    );
    expect(events, ['restore', 'exit 130']);
  });

  test('a command that started after Ctrl-C is stopped at once', () async {
    await interrupt();
    final process = _Process();

    interruption.track(process);

    expect(process.kills, [ProcessSignal.sigterm]);
  });

  test('a command that ended is not stopped', () async {
    final process = _Process()..kill();
    interruption.track(process);
    await pumpEventQueue();

    await interrupt();

    expect(process.kills, hasLength(1));
  });

  test('Ctrl-C belongs to a command that owns the terminal', () async {
    final answer = await interruption.whileForwarding(() async {
      await interrupt();
      return 3;
    });

    expect(answer, 3);
    expect(interruption.interrupted, isFalse);

    await interrupt();
    expect(interruption.interrupted, isTrue);
  });

  test('a cancelled question marks the run', () {
    interruption.markInterrupted();

    expect(interruption.interrupted, isTrue);
  });

  test('stops listening when closed', () async {
    await interruption.close();

    expect(signals.hasListener, isFalse);
    await interruption.close();
  });
}
