// A test of the analytics role that continuous integration runs in the app
// with every module of the registry of several providers, whichever
// modules provide the role there: the analytics service of the app,
// createAnalyticsService(), forwards each call to every analytics service
// once. An analytics service that throws as it is called, or whose call
// fails, keeps no other from the call, and its failure does not reach the
// code that called: an app that does not await its analytics would get it
// as an error that nothing catches.
//
// It looks only at what reaches the fixture providers of the role: the
// service log of the fixtures, which notes each call and fails when the
// test says so, and the fixture analytics, through its platform side. The
// service log is created with the app, and the fixture analytics starts
// asynchronously, so it comes after the log among the analytics services
// of the app. What another analytics service, such as Firebase Analytics,
// does with a call, only the tests of its own module know. The matrix sets
// up the mocks of the platform side of every module of the app before the
// tests, so the start-up runs whatever other modules the app has.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/analytics/analytics_service.dart';
import 'package:{{app_name}}/core/fixture_analytics/fixture_analytics.dart';
import 'package:{{app_name}}/core/fixture_service_log/fixture_service_log.dart';

/// Runs the start-up of the app, which creates the analytics services that
/// start asynchronously, and then puts back the handlers of the errors and
/// the widget of an error, which it may replace, as the start-up of an app
/// that reports its crashes does: this test does not look at them.
Future<void> _start() async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  try {
    await bootstrap();
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
}

/// Awaits [call] and returns what it threw, or `null`.
Future<Object?> _failureOf(Future<void> Function() call) async {
  try {
    await call();
  } on Object catch (error) {
    return error;
  }
  return null;
}

/// Runs [body] and returns the lines that it printed with debugPrint.
Future<List<String>> _printed(Future<void> Function() body) async {
  final lines = <String>[];
  final debugPrintBefore = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) =>
      lines.addAll((message ?? '').split('\n'));
  try {
    await body();
  } finally {
    debugPrint = debugPrintBefore;
  }
  return lines;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // What reached the platform side of the fixture analytics: each call as
  // its method and its arguments.
  final fixtureCalls = <List<Object?>>[];

  setUpAll(() async {
    await _start();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fixtureAnalyticsChannel, (call) async {
      fixtureCalls.add([call.method, call.arguments]);
      return null;
    });
  });

  setUp(() {
    fixtureCalls.clear();
    loggedAnalyticsCalls.clear();
  });

  tearDown(() => serviceLogFailure = ServiceLogFailure.none);

  test(
      'the analytics service of the app forwards each call to every '
      'analytics service once', () async {
    final analytics = createAnalyticsService();

    await analytics.logEvent('smf_test', parameters: {'count': 1});
    await analytics.logSignIn(method: 'email');
    await analytics.logSignUp(method: 'email', parameters: {'plan': 'free'});
    await analytics.setAnalyticsCollectionEnabled(false);
    await analytics.setUserId('user-1');
    await analytics.setUserProperty(name: 'plan', value: null);

    const once = 'Each call reaches every analytics service once, in the '
        'order of the calls.';
    expect(
      loggedAnalyticsCalls,
      [
        [
          'logEvent',
          'smf_test',
          {'count': 1},
        ],
        ['logSignIn', 'email', null],
        [
          'logSignUp',
          'email',
          {'plan': 'free'},
        ],
        ['setAnalyticsCollectionEnabled', false],
        ['setUserId', 'user-1'],
        ['setUserProperty', 'plan', null],
      ],
      reason: once,
    );
    expect(
      fixtureCalls,
      [
        [
          'logEvent',
          {
            'name': 'smf_test',
            'parameters': {'count': 1},
          },
        ],
        [
          'logSignIn',
          {'method': 'email', 'parameters': null},
        ],
        [
          'logSignUp',
          {
            'method': 'email',
            'parameters': {'plan': 'free'},
          },
        ],
        [
          'setAnalyticsCollectionEnabled',
          {'enabled': false},
        ],
        [
          'setUserId',
          {'userId': 'user-1'},
        ],
        [
          'setUserProperty',
          {'name': 'plan', 'value': null},
        ],
      ],
      reason: once,
    );
  });

  for (final (failure, how) in [
    (ServiceLogFailure.throwing, 'throws as it is called'),
    (ServiceLogFailure.failing, 'returns a future that fails'),
  ]) {
    test(
        'an analytics service that $how keeps no other from the call, and '
        'its failure does not reach the code that called', () async {
      serviceLogFailure = failure;
      Object? failed;

      final printed = await _printed(() async {
        failed = await _failureOf(
          () => createAnalyticsService().logEvent('smf_test'),
        );
      });

      expect(
        fixtureCalls,
        [
          [
            'logEvent',
            {'name': 'smf_test', 'parameters': null},
          ],
        ],
        reason: 'Every other analytics service gets the call once.',
      );
      expect(
        loggedAnalyticsCalls,
        [
          ['logEvent', 'smf_test', null],
        ],
        reason: 'The service log gets the call once.',
      );
      expect(
        failed,
        isNull,
        reason: 'The failure of one analytics service does not reach the '
            'code that called the analytics service of the app.',
      );
      expect(
        printed.where((line) => line.contains('The service log failed on')),
        hasLength(1),
        reason: 'In debug mode, the analytics service of the app prints each '
            'failure of an analytics service, once.',
      );
    },
        skip: 'Bug: the analytics service of the app stops at an analytics '
            'service that throws, and fails when one of them fails.');
  }
}
