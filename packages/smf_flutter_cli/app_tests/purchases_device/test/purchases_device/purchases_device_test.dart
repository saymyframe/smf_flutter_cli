// A test that continuous integration runs in the apps with the purchases
// role and without the auth role, whichever module provides the purchases:
// the purchases belong to the user of the device, which the device keeps
// from one launch of the app to the next, so the next start of the app has
// the premium access that the user of the device bought.
//
// It knows only the role. The start-up of the app runs first, as on a
// device, since it starts the purchases, with the mocks of the platform side
// of every module of the app, which the matrix sets up before the tests of
// each test file (flutter_test_config.dart). The mocks keep the purchases of
// the user of the device from one launch to the next, where the user has the
// same access as before, as the role asks of them. The mocks of a module may
// have bought a plan for the user of the device before the start-up, and
// the test then buys nothing. The next start is initPurchases() of the role
// again, which creates the service of the provider anew and starts
// appPurchases with it, for the user of the device. Each expectation gives
// its reason.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of the provider, does not
/// wait for the fake time of the test. An error of [action] fails the
/// test, which tester.runAsync would only report to the handler of the
/// errors of Flutter.
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

/// Runs the start-up of the app, bootstrap(), as main() runs it before the
/// first frame, in real time, and puts back the handlers of errors that the
/// start-up installs, such as those of crash reporting, and the builder of
/// the widget of an error once it returns.
Future<void> _startUp(WidgetTester tester) async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  try {
    await _inRealTime(tester, 'bootstrap()', bootstrap);
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
}

/// [access] as a test compares it: whether it is premium, until when, and
/// whether it renews and is a free trial.
String _describe(AppAccess access) => switch (access) {
      NoAccess() => 'no access',
      PremiumAccess(:final expiresAt, :final renews, :final inTrial) => [
          if (expiresAt == null)
            'premium access for good'
          else
            'premium access until ${expiresAt.toUtc()}',
          if (renews) 'renews',
          if (inTrial) 'in trial',
        ].join(', '),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the user of the device keeps the premium access that it bought at the '
    'next start of an app without sign-in',
    (tester) async {
      await _startUp(tester);
      Object? failure;
      late String bought;
      late String next;

      await _inRealTime(tester, 'a purchase and the next start', () async {
        if (appPurchases.value is NoAccess) {
          final plans = await appPurchases.plans();
          try {
            await appPurchases.purchase(plans.first);
          } on Object catch (error) {
            failure = error;
          }
        }
        // A change of the access that the provider tells of a moment later
        // shows too.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bought = _describe(appPurchases.value);
        await initPurchases();
        next = _describe(appPurchases.value);
      });

      expect(
        next,
        bought,
        reason: 'The store keeps what the user of the device bought, and the '
            'device keeps that user from one launch of the app to the next, '
            'so the next start of an app without sign-in has its premium '
            'access.',
      );
      expect(
        (failure, bought.startsWith('premium access')),
        (null, true),
        reason: 'A purchase by a user without premium access succeeds, and '
            'gives that user premium access.',
      );
    },
    timeout: timeout,
  );
}
