import 'dart:async';
import 'dart:io' as io;

import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';

/// What `smf` does when the user presses Ctrl-C, or the process gets
/// `SIGTERM` on macOS or Linux.
///
/// The first one marks the run [interrupted] and stops the commands it
/// runs, so the pipeline stops at its next command or question, deletes
/// what it generated so far, and exits with [SmfExitCodes.cancelled]. Once
/// the app is in its place, the pipeline only warns that `flutter pub get`
/// did not finish there. A second one quits at once.
///
/// A command that owns the terminal, such as a login, gets Ctrl-C itself:
/// see [whileForwarding]. A question gets it as a key; see
/// `TerminalPrompter`.
final class Interruption {
  /// Creates the interruption of a run that listens to [signals], by default
  /// `SIGINT`, and `SIGTERM` but on Windows, and quits with [exit], by
  /// default `dart:io`'s, after [beforeQuit].
  Interruption({
    Stream<io.ProcessSignal>? signals,
    Never Function(int code)? exit,
    void Function()? beforeQuit,
  })  : _signals = signals,
        _exit = exit ?? io.exit,
        _beforeQuit = beforeQuit;

  final Stream<io.ProcessSignal>? _signals;
  final Never Function(int code) _exit;
  final void Function()? _beforeQuit;
  final List<StreamSubscription<io.ProcessSignal>> _subscriptions = [];
  final Set<io.Process> _processes = {};
  var _forwarding = 0;
  var _forwardedInterrupts = 0;
  var _interrupted = false;

  /// How many Ctrl-C quit at once while a command owns the terminal, which
  /// may keep Ctrl-C for itself.
  static const forwardedToQuit = 3;

  /// Whether the user interrupted the run.
  bool get interrupted => _interrupted;

  /// Starts listening to Ctrl-C.
  void listen() {
    if (_subscriptions.isNotEmpty) return;
    for (final signals in [
      if (_signals case final signals?)
        signals
      else ...[
        io.ProcessSignal.sigint.watch(),
        if (!io.Platform.isWindows) io.ProcessSignal.sigterm.watch(),
      ],
    ]) {
      _subscriptions.add(signals.listen(_onSignal));
    }
  }

  /// Stops listening to Ctrl-C.
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _onSignal(io.ProcessSignal signal) {
    if (_forwarding > 0 && signal == io.ProcessSignal.sigint) {
      if (++_forwardedInterrupts >= forwardedToQuit) _quit();
      return;
    }
    if (_interrupted) _quit();
    _interrupted = true;
    for (final process in [..._processes]) {
      process.kill();
    }
  }

  Never _quit() {
    _beforeQuit?.call();
    _exit(SmfExitCodes.cancelled);
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
  /// runs, Ctrl-C goes to the command alone, which decides what it means,
  /// unless the user presses it [forwardedToQuit] times.
  Future<T> whileForwarding<T>(Future<T> Function() body) async {
    _forwarding++;
    try {
      return await body();
    } finally {
      if (--_forwarding == 0) _forwardedInterrupts = 0;
    }
  }
}
