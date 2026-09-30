// A test that continuous integration runs in the apps with the events
// role, whichever module provides it: through the communication service of
// the role, every listener of a type gets each event of that type once, in
// the order the events were fired; a listener of another type gets none of
// them, and no error; an event fired before on<T>() is not in the stream
// that on<T>() returns; and a cancelled subscription gets no more events.
//
// It knows only the role, and fires events of its own. The start-up of the
// app runs first, as on a device, since a provider may open its service in
// the start-up, with the mocks of the platform side of every module of the
// app, which the matrix sets up before the tests of each test file
// (flutter_test_config.dart). The role says that fire() sends an event to
// everyone listening to its type; it does not say whether a listener of a
// type that the event extends or implements gets it, so the test does not
// look.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/events/communication_service.dart';

/// An event of the test.
final class _Ping extends AppEvent {
  const _Ping(this.id);

  /// Tells the events apart.
  final int id;
}

/// An event of the test of another type, which no [_Ping] is.
final class _Pong extends AppEvent {}

/// A listener of the events of type [T] of the communication service of the
/// app, which notes the events it gets and the errors of its stream, such as
/// a cast error of an event of another type.
final class _Listener<T extends AppEvent> {
  _Listener() {
    _subscription = createCommunicationService().on<T>().listen(
          events.add,
          onError: (Object error, StackTrace stackTrace) =>
              errors.add('$error'),
        );
  }

  late final StreamSubscription<T> _subscription;

  /// The events it got, in order.
  final List<T> events = [];

  /// The errors of its stream.
  final List<String> errors = [];

  /// Stops listening.
  Future<void> cancel() => _subscription.cancel();
}

/// The ids of the events that [listener] got, in order.
List<int> _ids(_Listener<_Ping> listener) => [
      for (final event in listener.events) event.id,
    ];

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the delivery of events, does not wait for the
/// fake time of the test. An error of [action] fails the test, which
/// tester.runAsync would only report to the handler of the errors of
/// Flutter.
Future<void> _inRealTime(
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

/// The problem of the start-up of the app, which runs once for the tests of
/// the file: `null` before it runs, and empty if it passed.
String? _startUpProblem;

/// Runs the start-up of the app, bootstrap(), as main() runs it before the
/// first frame, in real time, unless a test of the file ran it already, and
/// fails the test if it failed. The handlers of errors that the start-up
/// installs, such as those of crash reporting, and the builder of the widget
/// of an error go back to those of the test once it returns.
Future<void> _startUp(WidgetTester tester) async {
  if (_startUpProblem == null) {
    final onError = FlutterError.onError;
    final onPlatformError = PlatformDispatcher.instance.onError;
    final errorWidgetBuilder = ErrorWidget.builder;
    try {
      _startUpProblem = '';
      await _inRealTime(tester, 'bootstrap()', bootstrap);
    } on TestFailure catch (failure) {
      _startUpProblem = failure.message ?? 'bootstrap() failed';
    } finally {
      FlutterError.onError = onError;
      PlatformDispatcher.instance.onError = onPlatformError;
      ErrorWidget.builder = errorWidgetBuilder;
    }
  }
  if (_startUpProblem case final problem? when problem.isNotEmpty) {
    fail(problem);
  }
}

/// Fires [events] through the communication service of the app, then waits
/// until the listeners got what they get.
Future<void> _fire(List<AppEvent> events) async {
  final service = createCommunicationService();
  events.forEach(service.fire);
  await pumpEventQueue();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'every listener of a type gets an event of that type once',
    (tester) async {
      await _startUp(tester);
      late _Listener<_Ping> first;
      late _Listener<_Ping> second;

      await _inRealTime(tester, 'firing an event', () async {
        first = _Listener<_Ping>();
        second = _Listener<_Ping>();
        await _fire(const [_Ping(1)]);
        await first.cancel();
        await second.cancel();
      });

      expect(_ids(first), [1]);
      expect(_ids(second), [1]);
      expect([...first.errors, ...second.errors], isEmpty);
    },
    timeout: timeout,
  );

  testWidgets(
    'a listener gets the events of its type in the order they were fired',
    (tester) async {
      await _startUp(tester);
      late _Listener<_Ping> listener;

      await _inRealTime(tester, 'firing events', () async {
        listener = _Listener<_Ping>();
        await _fire(const [_Ping(1), _Ping(2), _Ping(3)]);
        await listener.cancel();
      });

      expect(_ids(listener), [1, 2, 3]);
      expect(listener.errors, isEmpty);
    },
    timeout: timeout,
  );

  testWidgets(
    'a listener of another type gets none of the events, and no error',
    (tester) async {
      await _startUp(tester);
      late _Listener<_Ping> pings;
      late _Listener<_Pong> pongs;

      await _inRealTime(tester, 'firing an event', () async {
        pings = _Listener<_Ping>();
        pongs = _Listener<_Pong>();
        await _fire(const [_Ping(1)]);
        await pings.cancel();
        await pongs.cancel();
      });

      expect(_ids(pings), [1]);
      expect(pongs.events, isEmpty);
      expect(
        pongs.errors,
        isEmpty,
        reason: 'An event of another type does not reach the listener, not '
            'even as an error.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'an event fired before on<T>() is not in the stream that it returns',
    (tester) async {
      await _startUp(tester);
      late _Listener<_Ping> listener;

      await _inRealTime(tester, 'firing events', () async {
        final service = createCommunicationService();
        service.fire(const _Ping(1));
        listener = _Listener<_Ping>();
        await _fire(const [_Ping(2)]);
        await listener.cancel();
      });

      expect(
        _ids(listener),
        [2],
        reason: 'on<T>() is the stream of the events sent from then on.',
      );
      expect(listener.errors, isEmpty);
    },
    timeout: timeout,
  );

  testWidgets(
    'a cancelled subscription gets no more events',
    (tester) async {
      await _startUp(tester);
      late _Listener<_Ping> cancelled;
      late _Listener<_Ping> listening;

      await _inRealTime(tester, 'firing events', () async {
        cancelled = _Listener<_Ping>();
        listening = _Listener<_Ping>();
        await _fire(const [_Ping(1)]);
        await cancelled.cancel();
        await _fire(const [_Ping(2)]);
        await listening.cancel();
      });

      expect(_ids(cancelled), [1]);
      expect(_ids(listening), [1, 2]);
      expect([...cancelled.errors, ...listening.errors], isEmpty);
    },
    timeout: timeout,
  );
}
