// What the tests of the purchases role share, in the apps with the role,
// whichever module provides it: the start-up of the app, which runs once
// for the tests of a file, what runs a call in real time and returns what
// it failed with, what makes the id of a user of the app that no
// identification named before, what starts the purchases with a service
// and a user, what brings the user back to the app, how a test compares an
// access, and a service of purchases of the tests, which scripts what a
// provider answers.
//
// It knows only the role. The tests rely on the convention that the mocks
// of the platform side of every provider keep to, as the role says:
// - a first launch finds nothing bought, and the offer has at least one
//   plan, each with an id of its own, a title and a price that are not
//   empty, an amount of 0 or more and a currency of three upper-case
//   letters;
// - any text is the id of a user of the app;
// - a purchase by a user without premium access completes at once and
//   succeeds. Its answer, as that of a restore, is the access that access()
//   gives right after it, field by field, and the provider tells of no
//   other change of the access while the purchase is on its way or right
//   after it;
// - a plan with a free intro offer that the user may take gives an access
//   in trial, and any other plan an access that is not in trial. A plan
//   with a period renews, and its access ends after the time of the device
//   at the purchase;
// - the purchases are kept for each user of the app, also from one launch
//   of the app to the next, where the user has the same access as before,
//   not one computed anew from the time of the start. They are kept by the
//   rules of the user of the device: identify(null) after another user
//   starts a new user of the device with nothing bought; a user that no
//   identification named before, identified while the user of the device
//   is, takes over the purchases of the user of the device; and any other
//   identification keeps the purchases of each user apart;
// - a restore gives the user who is identified what was bought on the
//   device. Whether it takes the purchases away from another user is up to
//   the backend of each provider, so no test relies on it.
//
// In an app with sign-in, the tests also rely on the session of the app,
// which tells appPurchases of a change of its user before the call of the
// session that made the change completes.
//
// So a test that needs a user without purchases identifies a throwaway user
// first, and then a fresh user of its own, which follows a user of the app.
// When the user of the device is the user of the app at that time, the
// throwaway takes over whatever the user of the device bought, such as a
// plan that the mocks of a module bought before the app started.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';
import 'package:{{app_name}}/core/purchases/purchases_service.dart';

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of the provider, does not
/// wait for the fake time of the test. An error of [action] fails the
/// test, which tester.runAsync would only report to the handler of the
/// errors of Flutter.
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

/// The problem of the start-up of the app, which runs once for the tests of
/// a file: `null` before it runs, and empty if it passed.
String? _startUpProblem;

/// Runs the start-up of the app, bootstrap(), as main() runs it before the
/// first frame, in real time, unless a test of the file ran it already, and
/// fails the test if it failed. The handlers of errors that the start-up
/// installs, such as those of crash reporting, and the builder of the widget
/// of an error go back to those of the test once it returns.
Future<void> startUp(WidgetTester tester) async {
  if (_startUpProblem == null) {
    final onError = FlutterError.onError;
    final onPlatformError = PlatformDispatcher.instance.onError;
    final errorWidgetBuilder = ErrorWidget.builder;
    try {
      _startUpProblem = '';
      await inRealTime(tester, 'bootstrap()', bootstrap);
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

/// What [call] failed with, or `null` if it completed.
Future<Object?> errorOf(Future<void> Function() call) async {
  try {
    await call();
    return null;
  } on Object catch (error) {
    return error;
  }
}

/// Matches what a call of purchases fails with for [reason]: a
/// [PurchasesFailure] with that reason.
Matcher failsWith(PurchasesFailureReason reason) =>
    isA<PurchasesFailure>().having(
      (failure) => failure.reason,
      'reason',
      reason,
    );

/// How many ids of users the tests of the file made.
int _users = 0;

/// A new id of a user of the app, which no identification named before, on
/// any device: [name], the time and a number of its own, so that a provider
/// that keeps its users on a server does not know it either.
String freshUser(String name) =>
    'purchases-role-$name-${DateTime.now().microsecondsSinceEpoch}-'
    '${++_users}';

/// Starts appPurchases with [service] and [user], the id of a user of the
/// app or `null` for the user of the device, as a start of the app does
/// with the service of the provider and the user of the app, in real time.
Future<void> startAs(
  WidgetTester tester,
  PurchasesService service,
  String? user,
) =>
    inRealTime(
      tester,
      'starting the purchases',
      () => appPurchases.start(service, userId: () => user),
    );

/// Identifies a throwaway user with the service of the provider. A fresh
/// user identified after it follows a user of the app, so it has nothing
/// bought. When the user of the device is the user of the app at that time,
/// the throwaway takes over what the user of the device bought, as a user
/// that no identification named before does.
Future<void> identifyThrowaway(WidgetTester tester) =>
    startAs(tester, createPurchasesService(), freshUser('throwaway'));

/// Waits a moment in real time, for what a call or a change set off to
/// reach a listener.
Future<void> aMoment() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

/// Brings the user back to the app, and waits a moment for the app to ask
/// the service again.
Future<void> comeBack(WidgetTester tester) => inRealTime(
      tester,
      'coming back to the app',
      () async {
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await aMoment();
      },
    );

/// [access] as a test compares it: whether it is premium, until when, and
/// whether it renews and is a free trial.
String describe(AppAccess access) => switch (access) {
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

/// The plan that the service of the tests sells.
const Plan monthlyOfTests = Plan(
  id: 'monthly',
  title: 'Monthly',
  price: r'$4.99',
  amount: 4.99,
  currencyCode: 'USD',
  period: BillingPeriod(1, BillingUnit.month),
);

/// The premium access that a purchase gives with the service of the tests.
final PremiumAccess premiumOfTests = PremiumAccess(
  expiresAt: DateTime.utc(2030),
  renews: true,
  period: const BillingPeriod(1, BillingUnit.month),
);

/// A service of purchases of the tests, which a test gives a controller to
/// script what a provider answers: the access of each user, which a test
/// changes as a grant made elsewhere does, what a purchase gives, and the
/// failure of every call of a provider without what it needs. It notes
/// each call that reaches it, and holds a call back while a test says so.
final class ScriptedPurchases implements PurchasesService {
  /// Creates the service, which fails every call with [failure], if any.
  ScriptedPurchases({this.failure});

  /// The failure of every call, or `null`.
  final PurchasesFailure? failure;

  /// The access of each user by the id of the user, `null` for the user of
  /// the device: none until a test or a purchase gives one.
  final Map<String?, AppAccess> accessOf = {};

  /// What a purchase of a plan answers: [premiumOfTests], which the user
  /// then has, by default; `null` for a purchase that the user cancelled.
  AppAccess? Function(Plan plan) purchaseAnswer = (_) => premiumOfTests;

  /// The error that plans() throws, if any.
  Object? plansError;

  /// The calls that reached the service, in their order, each with what it
  /// was for: `identify <user>`, `access`, `plans`, `purchase <plan>` and
  /// `restore`.
  final List<String> calls = [];

  final Map<String, Completer<void>> _held = {};

  final StreamController<AppAccess> _changes =
      StreamController<AppAccess>.broadcast();

  String? _user;

  /// Holds the next call [name], such as `access`, `purchase` or `restore`,
  /// back until the completer that it returns completes. A test holds a call
  /// in real time, where it completes the completer too: the future of a
  /// completer completes in the zone that created it, and the fake time of a
  /// widget test runs nothing while the test waits for real time.
  Completer<void> hold(String name) => _held[name] = Completer<void>();

  /// Tells of [access], a change of the access of the user that the
  /// provider learned of, such as an expiry.
  void tell(AppAccess access) => _changes.add(access);

  /// Notes the call [name], which [note] describes, waits while a test
  /// holds it back, and fails it with [failure], if any.
  Future<void> _call(String name, [String? note]) async {
    calls.add(note == null ? name : '$name $note');
    final held = _held.remove(name);
    if (held != null) await held.future;
    if (failure case final failure?) throw failure;
  }

  @override
  Future<void> identify(String? userId) async {
    await _call('identify', '$userId');
    _user = userId;
  }

  @override
  Future<AppAccess> access() async {
    await _call('access');
    return accessOf[_user] ?? const NoAccess();
  }

  @override
  Stream<AppAccess> get accessChanges => _changes.stream;

  @override
  Future<List<Plan>> plans() async {
    await _call('plans');
    if (plansError case final error?) throw error;
    return const [monthlyOfTests];
  }

  @override
  Future<AppAccess?> purchase(Plan plan) async {
    final user = _user;
    await _call('purchase', plan.id);
    final answer = purchaseAnswer(plan);
    if (answer != null) accessOf[user] = answer;
    return answer;
  }

  @override
  Future<AppAccess> restore() async {
    await _call('restore');
    return accessOf[_user] ?? const NoAccess();
  }
}
