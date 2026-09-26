import 'dart:io' as io;

import 'package:mason_logger/mason_logger.dart';
import 'package:smf_contracts/lego_core.dart';

/// Reports to the standard output and error of the process, with the
/// styles and the progress animation of `mason_logger`.
///
/// In a terminal a progress indicator animates on its own line, which a
/// message clears first; otherwise, as in CI, a progress is a line when it
/// starts and one when it ends.
final class IoLogger implements SmfLogger {
  /// Creates the logger, which shows the details only if [verbose].
  ///
  /// [terminal] is whether the standard output is a terminal, which tests
  /// may set.
  IoLogger({required bool verbose, bool? terminal})
      : _logger = Logger(level: verbose ? Level.verbose : Level.info),
        _stdout = io.stdout,
        _terminal = terminal ?? io.stdout.hasTerminal;

  final Logger _logger;
  final io.Stdout _stdout;
  final bool _terminal;
  _IoProgress? _active;

  /// Clears the line of the animated progress, so that a message does not
  /// land after it, and lets long lines wrap again, which the animation
  /// stops; the progress draws itself again below the message.
  void _clearProgress() {
    if (_terminal && (_active?.running ?? false)) {
      _stdout.write('\u001b[2K\r\u001b[?7h');
    }
  }

  @override
  void info(String message) {
    _clearProgress();
    _logger.info(message);
  }

  @override
  void detail(String message) {
    _clearProgress();
    _logger.detail(message);
  }

  @override
  void warn(String message) {
    _clearProgress();
    _logger.warn(message);
  }

  @override
  void error(String message) {
    _clearProgress();
    _logger.err(message);
  }

  @override
  void success(String message) {
    _clearProgress();
    _logger.success(message);
  }

  @override
  SmfProgress progress(String message) {
    _clearProgress();
    return _active = _IoProgress(
      message,
      animated: _terminal ? _logger.progress(message) : null,
      logger: _logger,
    );
  }
}

/// A progress: the animation of `mason_logger` in a terminal, or lines.
final class _IoProgress implements SmfProgress {
  _IoProgress(
    this._message, {
    required Progress? animated,
    required Logger logger,
  })  : _animated = animated,
        _logger = logger {
    if (animated == null) logger.info('$_message...');
  }

  final Progress? _animated;
  final Logger _logger;
  final _stopwatch = Stopwatch()..start();
  String _message;

  /// Whether the progress has not ended.
  bool get running => _stopwatch.isRunning;

  String get _time {
    final seconds = _stopwatch.elapsedMilliseconds / 1000;
    return darkGray.wrap('(${seconds.toStringAsFixed(1)}s)')!;
  }

  @override
  void update(String message) {
    _message = message;
    if (_animated case final animated?) {
      animated.update(message);
    } else {
      _logger.info('$message...');
    }
  }

  @override
  void complete([String? message]) {
    _stopwatch.stop();
    if (_animated case final animated?) {
      animated.complete(message);
    } else {
      _logger.info('${lightGreen.wrap('✓')} ${message ?? _message} $_time');
    }
  }

  @override
  void fail([String? message]) {
    _stopwatch.stop();
    if (_animated case final animated?) {
      animated.fail(message);
    } else {
      _logger.info('${red.wrap('✗')} ${message ?? _message} $_time');
    }
  }
}
