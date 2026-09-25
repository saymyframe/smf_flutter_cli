import 'dart:async';
import 'dart:io' as io;

import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';

/// What `smf` does when the user presses Ctrl-C.
///
/// The first Ctrl-C marks the run [interrupted] and stops the commands it
/// runs, so the pipeline stops at its next command or question, deletes
/// what it generated so far, and exits with [SmfExitCodes.cancelled]. A
/// second Ctrl-C quits at once.
///
/// A command that owns the terminal, such as a login, gets Ctrl-C itself:
/// see [whileForwarding]. A question gets it as a key; see
/// `TerminalPrompter`.
final class Interruption {
  /// Creates the interruption of a run that listens to [signals], by default
  /// `SIGINT`, and quits with [exit], by default `dart:io`'s.
  Interruption({
    Stream<io.ProcessSignal>? signals,
    Never Function(int code)? exit,
  })  : _signals = signals,
        _exit = exit ?? io.exit;

  final Stream<io.ProcessSignal>? _signals;
  final Never Function(int code) _exit;
  StreamSubscription<io.ProcessSignal>? _subscription;
  final Set<io.Process> _processes = {};
  var _forwarding = 0;
  var _interrupted = false;

  /// Whether the user interrupted the run.
  bool get interrupted => _interrupted;

  /// Starts listening to Ctrl-C.
  void listen() {
    _subscription ??= (_signals ?? io.ProcessSignal.sigint.watch())
        .listen((_) => _onSignal());
  }

  /// Stops listening to Ctrl-C.
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onSignal() {
    if (_forwarding > 0) return;
    if (_interrupted) _exit(SmfExitCodes.cancelled);
    _interrupted = true;
    for (final process in [..._processes]) {
      process.kill();
    }
  }

  /// Marks the run interrupted, as when the user cancels a question.
  void markInterrupted() => _interrupted = true;

  /// Throws an [SmfCancelledException] if the user interrupted the run.
  void throwIfInterrupted() {
    if (_interrupted) throw const SmfCancelledException();
  }

  /// Stops [process] if the user interrupts the run before it exits, or
  /// did while it started.
  void track(io.Process process) {
    if (_interrupted) {
      process.kill();
      return;
    }
    _processes.add(process);
    unawaited(process.exitCode.whenComplete(() => _processes.remove(process)));
  }

  /// Runs [body], which runs a command that owns the terminal: while it
  /// runs, Ctrl-C goes to the command alone, which decides what it means.
  Future<T> whileForwarding<T>(Future<T> Function() body) async {
    _forwarding++;
    try {
      return await body();
    } finally {
      _forwarding--;
    }
  }
}
