// A check that continuous integration builds into some of the apps it
// generates as the entry of the app, in place of lib/main.dart, and starts
// on an Android emulator and on an iOS simulator: the app starts. It runs
// main() of the app, with what its modules put into bootstrap(), waits for
// the first screen to settle and looks at the widgets on it: the root
// widget of the app shows its first screen without an error.
//
// Nothing connects to the app to run the check, unlike a test of
// `flutter test`, which sometimes never reaches the app on the devices of
// CI. The check writes its result, one line with `passed` or `failed: `
// and the problems, to the file smf_start_check in the temporary directory
// of the app, where .github/scripts/start_app.sh of the repository of SMF
// reads it, and prints the line after `SMF_START_CHECK: ` to the log of the
// device. The matrix of the apps only analyzes it.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:{{app_name}}/app.dart';
import 'package:{{app_name}}/main.dart' as app;

/// How long main() of the app may take.
const _mainLimit = Duration(seconds: 60);

/// How long the first screen may take to show and settle.
const _settleLimit = Duration(seconds: 30);

/// How long the app must schedule no frame for its screen to be settled.
const _quiet = Duration(milliseconds: 500);

Future<void> main() async {
  final problems = <String>[];
  var returned = false;
  try {
    await app.main().timeout(_mainLimit);
    returned = true;
  } on TimeoutException {
    problems.add('main() did not return in ${_mainLimit.inSeconds} s');
  } on Object catch (error, stack) {
    problems.add('main() threw ${_firstLine(error)}');
    debugPrint('main() threw $error\n$stack');
  }
  // The binding of the app, or a new one if main() failed before it made
  // one.
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // bootstrap() of an app that reports crashes sends the errors of Flutter
  // and those that nothing catches to the crash reporter, where the check
  // would not see them. The check takes them back once main() returns, so
  // that an error in the frames of the first screen fails it, and prints
  // them to the log of the device: a debug app sends the errors of Flutter
  // to the tools of Flutter instead (FlutterError.presentError), and none
  // are connected to it.
  FlutterError.onError = (details) {
    problems.add('Flutter reported ${_firstLine(details.exceptionAsString())}');
    FlutterError.dumpErrorToConsole(details);
  };
  binding.platformDispatcher.onError = (error, stack) {
    problems.add('an error that nothing caught: ${_firstLine(error)}');
    debugPrint('$error\n$stack');
    return true;
  };
  if (returned) {
    if (await _settle(binding) case final problem?) problems.add(problem);
    problems.addAll(_problemsOnScreen(binding.rootElement));
  }
  final result = problems.isEmpty ? 'passed' : 'failed: ${problems.join('; ')}';
  debugPrint('SMF_START_CHECK: $result');
  // Written next to the file and renamed, so that the file is there only
  // with the whole line.
  final file = File('${Directory.systemTemp.path}/smf_start_check');
  File('${file.path}.part')
    ..writeAsStringSync('$result\n', flush: true)
    ..renameSync(file.path);
}

/// Waits until the app has shown its first frame and then schedules no
/// frame for [_quiet], as `pumpAndSettle` of flutter_test does; returns
/// the problem if that takes longer than [_settleLimit].
Future<String?> _settle(WidgetsBinding binding) async {
  final elapsed = Stopwatch()..start();
  try {
    await binding.waitUntilFirstFrameRasterized.timeout(_settleLimit);
  } on TimeoutException {
    return 'the app showed no frame in ${_settleLimit.inSeconds} s, in the '
        'state ${binding.lifecycleState}';
  }
  final quiet = Stopwatch()..start();
  while (quiet.elapsed < _quiet) {
    if (elapsed.elapsed > _settleLimit) {
      return 'the first screen still changed after '
          '${_settleLimit.inSeconds} s';
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (binding.hasScheduledFrame ||
        binding.schedulerPhase != SchedulerPhase.idle) {
      quiet.reset();
    }
  }
  return null;
}

/// The problems of the widgets under [root]: the root widget of the app
/// and its [MaterialApp] are there once each, and no [ErrorWidget] is.
List<String> _problemsOnScreen(Element? root) {
  var apps = 0;
  var materialApps = 0;
  final errors = <String>[];
  void visit(Element element) {
    switch (element.widget) {
      case App():
        apps++;
      case MaterialApp():
        materialApps++;
      case ErrorWidget(:final message):
        errors.add(_firstLine(message));
    }
    element.visitChildren(visit);
  }

  if (root != null) visit(root);
  return [
    if (apps != 1) 'the screen has $apps App widgets rather than one',
    if (materialApps != 1)
      'the screen has $materialApps MaterialApp widgets rather than one',
    for (final error in errors) 'the screen shows an ErrorWidget: $error',
  ];
}

/// The first line of the text of [error].
String _firstLine(Object error) => '$error'.trim().split('\n').first;
