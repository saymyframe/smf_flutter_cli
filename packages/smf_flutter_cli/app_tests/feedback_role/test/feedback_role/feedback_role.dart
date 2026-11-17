// What the tests of the feedback role share, in the apps with the role,
// whichever module provides it: the start of the app with main() of
// lib/main.dart, which the app entry role puts into every app, a context
// below the root of the app, what reached the handlers of the errors while a
// call ran, what a call completed with within two seconds of frames, and a
// service of feedback of the tests, which scripts what a provider answers.
//
// The start-up of an app runs once in a test file, so each file of the tests
// has one test. The matrix sets up the mocks of the platform side of every
// module of the app before the tests of each test file
// (flutter_test_config.dart). The mocks of the provider of the role keep to
// the convention of the role: the provider has what it needs, and the device
// has what the provider opens and says no when it is asked whether it has
// it, as Android 11 and later say to an app whose manifest names no other
// app.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/feedback/feedback_service.dart';
import 'package:{{app_name}}/main.dart' as app;

/// A widget test fails after ten minutes by default; a test that hangs
/// fails sooner.
const timeout = Timeout(Duration(minutes: 2));

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as a timer or the platform side of a module, does
/// not keep the fake time of the test waiting forever. An error of [action]
/// fails the test, which tester.runAsync would only report to the handler
/// of the errors of Flutter.
Future<void> inRealTime(
  WidgetTester tester,
  String what,
  Future<void> Function() action,
) async {
  Object? error;
  StackTrace? stackTrace;
  await tester.runAsync(() async {
    try {
      await action();
    } on Object catch (thrown, stack) {
      error = thrown;
      stackTrace = stack;
    }
  });
  if (error != null) fail('$what threw $error\n$stackTrace');
}

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen.
///
/// main() runs in real time, as the start-up of a module may wait for a
/// timer or for input and output. An error of bootstrap() reaches
/// FlutterError.onError through main(), which fails the test. The handlers
/// of errors that the start-up installs, such as those of crash reporting,
/// and the builder of the widget of an error go back to those of the test
/// once main() returns, so that flutter_test reports the errors of the
/// frames that follow, and an expectation that fails, as in any test.
Future<void> startApp(WidgetTester tester) async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  try {
    await inRealTime(tester, 'main()', app.main);
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
  await tester.pumpAndSettle();
}

/// The navigator at the root of the app, which shows its screens.
NavigatorState rootNavigatorOf(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

/// Shows a page of the test over the app, on top of the navigator at the
/// root of the app, and returns its context: a context below the root of
/// the app, with the theme and the texts of the app, as that of a button on
/// a screen of the app is. [name] tells the page apart from another page of
/// the test. [closeTestPage] closes it.
Future<BuildContext> contextBelowRoot(
  WidgetTester tester, {
  String name = 'page',
}) async {
  unawaited(
    rootNavigatorOf(tester).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _TestPage(name),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    ),
  );
  await tester.pump();
  return tester.element(
    find.byWidgetPredicate(
        (widget) => widget is _TestPage && widget.name == name),
  );
}

/// Closes the route on top of the navigator at the root of the app, such as
/// a page that [contextBelowRoot] showed, and waits until it is gone.
Future<void> closeTestPage(WidgetTester tester) async {
  rootNavigatorOf(tester).pop();
  await tester.pumpAndSettle();
}

/// A page of the test, which shows nothing.
class _TestPage extends StatelessWidget {
  const _TestPage(this.name);

  /// What tells the page apart from another page of the test.
  final String name;

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFFFFFFFF),
        child: SizedBox.expand(),
      );
}

/// The errors that reached the handler of the errors of Flutter and the
/// handler of the uncaught errors of the platform while [action] ran, each
/// as its text.
Future<({List<String> flutter, List<String> platform})> errorsWhile(
  Future<void> Function() action,
) async {
  final flutter = <String>[];
  final platform = <String>[];
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  FlutterError.onError = (details) => flutter.add('${details.exception}');
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    platform.add('$error');
    return true;
  };
  try {
    await action();
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
  }
  return (flutter: flutter, platform: platform);
}

/// What [call] completes with, or the error that it fails with, once frames
/// of a tenth of a second each let it complete, two seconds of them at
/// most, rather than once the screen settled: a way that opens over the app
/// may never settle. Both are `null` if it did not complete by then.
Future<({bool? answer, Object? error})> answerWithin(
  WidgetTester tester,
  Future<bool> call,
) async {
  bool? answer;
  Object? error;
  var done = false;
  unawaited(
    call.then(
      (value) {
        answer = value;
        done = true;
      },
      onError: (Object thrown) {
        error = thrown;
        done = true;
      },
    ),
  );
  for (var frame = 0; frame < 20 && !done; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (answer: answer, error: error);
}

/// What the context of an open reached when the service got it: the theme,
/// the language and the navigator at the root of the app.
typedef Reached = ({ThemeData theme, Locale locale, NavigatorState navigator});

/// A service of feedback of the tests, which scripts what a provider
/// answers and notes the context of each open that reached it.
/// `appFeedback.use()` gives it to the app, and a test gives the app the
/// service of the provider, `createFeedbackService()`, again when it ends.
final class ScriptedFeedback implements FeedbackService {
  /// Whether the service has what it needs.
  bool canWrite = true;

  /// What an open completes with.
  bool answer = true;

  /// What an open fails with, if anything.
  Object? error;

  /// What [available] throws, if anything.
  Object? availableError;

  /// What the next open waits for, while a test holds it.
  Completer<bool>? _held;

  /// Whether the next open waits for [_held].
  bool _holdsNext = false;

  /// The context of each open that reached the service, in order.
  final List<BuildContext> contexts = [];

  /// What the context of each open that reached the service reached, in
  /// order.
  final List<Reached> reached = [];

  /// Holds the next open until [release]. Only that open waits: an open
  /// after it answers at once, so a test that expects no such open sees it
  /// rather than wait for one that nothing lets go.
  void hold() {
    _held = Completer<bool>();
    _holdsNext = true;
  }

  /// Lets the open that waits complete with [answer].
  void release(bool answer) {
    final held = _held;
    _held = null;
    _holdsNext = false;
    held?.complete(answer);
  }

  @override
  bool get available {
    if (availableError case final thrown?) throw thrown;
    return canWrite;
  }

  @override
  Future<bool> open(BuildContext context) {
    contexts.add(context);
    reached.add(
      (
        theme: Theme.of(context),
        locale: Localizations.localeOf(context),
        navigator: Navigator.of(context, rootNavigator: true),
      ),
    );
    if (error case final thrown?) return Future<bool>.error(thrown);
    if (_held case final held? when _holdsNext) {
      _holdsNext = false;
      return held.future;
    }
    return Future<bool>.value(answer);
  }
}
