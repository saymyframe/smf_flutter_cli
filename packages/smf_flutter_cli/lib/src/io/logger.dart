import 'dart:io' as io;

import 'package:mason_logger/mason_logger.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_flutter_cli/src/io/greeting.dart';

/// Reports to the standard output and error of the process, with the
/// styles and the progress animation of `mason_logger`.
///
/// In a terminal a progress indicator animates on its own line, which a
/// message clears first; otherwise, as in CI, a progress is a line when it
/// starts and one when it ends. Where the output takes the escapes of ANSI,
/// as the styles do, each web address of a message is a link of the
/// terminal (see [_linked]).
final class IoLogger implements SmfLogger {
  /// Creates the logger, which shows the details only if [verbose], and
  /// drops [greeting], if given, once it has printed something.
  ///
  /// [terminal] is whether the standard output is a terminal, which tests
  /// may set.
  IoLogger({required bool verbose, bool? terminal, Greeting? greeting})
      : _logger = Logger(level: verbose ? Level.verbose : Level.info),
        _verbose = verbose,
        _stdout = io.stdout,
        _terminal = terminal ?? io.stdout.hasTerminal,
        _greeting = greeting;

  final Logger _logger;
  final bool _verbose;
  final io.Stdout _stdout;
  final bool _terminal;
  final Greeting? _greeting;
  _IoProgress? _active;

  /// Makes room for a message: drops the greeting, which only opens the
  /// output of a run, and clears the line of the animated progress, so that
  /// the message does not land after it, and lets long lines wrap again,
  /// which the animation stops; the progress draws itself again below the
  /// message.
  void _beforeMessage() {
    _greeting?.drop();
    if (_terminal && (_active?.running ?? false)) {
      _stdout.write('\u001b[2K\r\u001b[?7h');
    }
  }

  @override
  void info(String message) {
    _beforeMessage();
    _logger.info(_linked(message));
  }

  @override
  void detail(String message) {
    // Details are shown only in verbose output.
    if (!_verbose) return;
    _beforeMessage();
    _logger.detail(_linked(message));
  }

  @override
  void warn(String message) {
    _beforeMessage();
    _logger.warn(_linked(message));
  }

  @override
  void error(String message) {
    _beforeMessage();
    _logger.err(_linked(message));
  }

  @override
  void success(String message) {
    _beforeMessage();
    _logger.success(_linked(message));
  }

  @override
  SmfProgress progress(String message) {
    _beforeMessage();
    return _active = _IoProgress(
      message,
      animated: _terminal ? _logger.progress(message) : null,
      logger: _logger,
    );
  }
}

/// A web address of a message: `http://` or `https://` and what follows up
/// to a space, a quote, an angle bracket, a pipe or an escape.
final _webAddress = RegExp(r'''https?://[^\s<>"'`|\x1B]+''');

/// The marks of punctuation at the end of a web address of a message, which
/// end the sentence rather than the address, such as the period of
/// `See https://doc.saymyframe.com.`
final _closingMarks = RegExp(r'[.,;:!?)\]}]+$');

/// [message] with each web address in it a link of the terminal, an escape
/// of OSC 8 that shows the address itself, so that a click opens it, also
/// where a long address wraps; a terminal without such links shows the
/// address as it is. Where the output takes no escapes of ANSI, as in CI,
/// in a pipe or in a log, the message stays as it is.
String _linked(String message) {
  if (!ansiOutputEnabled) return message;
  return message.replaceAllMapped(_webAddress, (match) {
    final text = match[0]!;
    final closing = _closingMarks.firstMatch(text)?[0] ?? '';
    final address = text.substring(0, text.length - closing.length);
    final uri = Uri.tryParse(address);
    if (uri == null) return text;
    return '${link(uri: uri, message: address)}$closing';
  });
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
