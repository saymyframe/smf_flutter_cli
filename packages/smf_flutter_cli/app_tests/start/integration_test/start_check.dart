// A check that continuous integration builds into some of the apps it
// generates as the entry of the app, in place of lib/main.dart, and starts
// on an Android emulator and on an iOS simulator: the app starts. It runs
// main() of the app, with what its modules put into bootstrap(), waits for
// the first screen to settle and looks at the widgets on it: the app shows
// its first screen without an error. Then it runs the probes of the tests
// of the app, which go through the roles of the app, such as the walk of
// its routes, within a minute together. The matrix of SMF lists them in
// start_probes.dart next to it, the probes of the tests that go into the
// app with the check (MatrixAppTest.startProbe).
//
// It knows no module, only what every app has: main() in lib/main.dart,
// which the app entry role puts there (AppEntryRole.mainFile), whichever
// module provides it, and a WidgetsApp at the root, which MaterialApp and
// CupertinoApp build. So the CLI keeps it rather than the module of the
// app entry, and it applies to every app.
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
import 'package:{{app_name}}/main.dart' as app;

import 'start_probes.dart';

/// How long main() of the app may take.
const _mainLimit = Duration(seconds: 60);

/// How long the first screen may take to show and settle.
const _settleLimit = Duration(seconds: 30);

/// How long the app must schedule no frame for its screen to be settled.
const _quiet = Duration(milliseconds: 500);

/// How long the probes of the tests of the app may take together.
const _probesLimit = Duration(seconds: 60);

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
    if (await _settle(binding) case final problem?) {
      problems.add(problem);
    } else {
      problems
        ..addAll(_problemsOnScreen(binding.rootElement))
        ..addAll(await _problemsOfProbes(binding));
    }
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
/// the problem if that takes longer than [_settleLimit], with [screen], the
/// screen that the app shows.
Future<String?> _settle(
  WidgetsBinding binding, {
  String screen = 'the first screen',
}) async {
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
      return '$screen still changed after ${_settleLimit.inSeconds} s';
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (binding.hasScheduledFrame ||
        binding.schedulerPhase != SchedulerPhase.idle) {
      quiet.reset();
    }
  }
  return null;
}

/// Runs the probes of the tests of the app ([startProbes]) one after
/// another, each with a function that waits until the screen settles, and
/// returns their problems, each after the name of the tests of its probe.
/// The probes take [_probesLimit] together: a probe that is still running
/// then is a problem, and so is each that did not start. It prints the
/// probes that ran to the log of the device, with the time each took, so
/// that the log tells which the check ran, even when it passed.
Future<List<String>> _problemsOfProbes(WidgetsBinding binding) async {
  final problems = <String>[];
  final ran = <String>[];
  final elapsed = Stopwatch()..start();
  Future<void> settle() async {
    if (await _settle(binding, screen: 'the screen') case final problem?) {
      throw _Unsettled(problem);
    }
  }

  for (final (name, probe) in startProbes) {
    final left = _probesLimit - elapsed.elapsed;
    if (left <= Duration.zero) {
      problems.add(
        '$name: the probe did not start: the probes before it took the '
        '${_probesLimit.inSeconds} s of the probes',
      );
      continue;
    }
    final started = elapsed.elapsed;
    try {
      final found = await probe(settle).timeout(
        left,
        onTimeout: () => [
          'the probe did not finish within the ${_probesLimit.inSeconds} s '
              'of the probes',
        ],
      );
      problems.addAll([for (final problem in found) '$name: $problem']);
    } on Object catch (error, stack) {
      problems.add('$name: the probe threw ${_firstLine(error)}');
      debugPrint('The probe of $name threw $error\n$stack');
    }
    ran.add('$name in ${(elapsed.elapsed - started).inMilliseconds} ms');
  }
  debugPrint(
    ran.isEmpty
        ? 'The start check ran no probe.'
        : 'The start check ran the probes of ${ran.join(', ')}.',
  );
  return problems;
}

/// The screen did not settle while a probe waited for it, with the
/// [problem].
final class _Unsettled implements Exception {
  const _Unsettled(this.problem);

  final String problem;

  @override
  String toString() => problem;
}

/// The problems of the widgets under [root]: the app has a [WidgetsApp],
/// which MaterialApp and CupertinoApp build, and no [ErrorWidget] is on
/// the screen.
List<String> _problemsOnScreen(Element? root) {
  var widgetsApps = 0;
  final errors = <String>[];
  void visit(Element element) {
    switch (element.widget) {
      case WidgetsApp():
        widgetsApps++;
      case ErrorWidget(:final message):
        errors.add(_firstLine(message));
    }
    element.visitChildren(visit);
  }

  if (root != null) visit(root);
  return [
    if (widgetsApps == 0) 'the screen has no WidgetsApp',
    for (final error in errors) 'the screen shows an ErrorWidget: $error',
  ];
}

/// The first line of the text of [error].
String _firstLine(Object error) => '$error'.trim().split('\n').first;
