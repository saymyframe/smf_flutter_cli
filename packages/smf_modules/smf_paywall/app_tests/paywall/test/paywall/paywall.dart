// What the tests of the paywall module share, in the apps with the module:
// the start of the app with main() of lib/main.dart, which the app entry
// role puts into every app, the screens of the paywall and what they show,
// in the language that the device asks for, the way to them through the
// navigation of the router role, a service of purchases of the test, which
// a test gives the purchases of the app to script what a provider answers,
// and what records the links that the app opens.
//
// They know the module, and of the rest of the app only its roles: the
// purchases of the purchases role, whichever module provides them, and the
// router, which shows the screens and closes them. The matrix writes
// of_app.dart next to this file: the screen that the app starts on, the
// settings screen of the app with the entry of the module, if the app has
// one, from the settings screen role, whether that screen is a destination
// of the main navigation, from the layout role, and the texts of the module
// in each language of the app. It sets up the mocks of the platform side of
// every module of the app before the tests of each test file
// (flutter_test_config.dart), so the start-up runs whatever other modules
// the app has. It writes the values of the tests into .env, which the tests
// read through AppEnv of the env role.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';
import 'package:{{app_name}}/core/purchases/purchases_service.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/paywall/paywall_screen.dart';
import 'package:{{app_name}}/features/paywall/paywall_widgets.dart';
import 'package:{{app_name}}/features/paywall/subscription_screen.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'of_app.dart';

/// The paywall that the user sees, and every one that the app has built,
/// also below another screen.
final Finder paywallScreen = find.byType(PaywallScreen);
final Finder builtPaywall = find.byType(PaywallScreen, skipOffstage: false);

/// The screen of the subscription that the user sees, and every one that
/// the app has built.
final Finder subscriptionScreen = find.byType(SubscriptionScreen);
final Finder builtSubscription = find.byType(
  SubscriptionScreen,
  skipOffstage: false,
);

/// The screen that the app starts on that the user sees, and every one that
/// the app has built.
final Finder startScreenShown = find.byType(startScreen);
final Finder builtStartScreen = find.byType(startScreen, skipOffstage: false);

/// The button of the paywall that buys the selected plan.
final Finder purchaseButton = find.byType(PurchaseButton);

/// The cards of the plans on the paywall, in their order.
final Finder planCards = find.byType(PlanCard);

/// The texts of the module in the language that the device asks for (see
/// [useLanguage]), each by its name in the module.
Map<String, String> texts = paywallTexts.values.first;

/// The text of the module with the name [name], on the screen that the
/// user sees.
Finder text(String name) => find.text(texts[name]!);

/// The link of the paywall with the text [name] of the module.
Finder link(String name) =>
    find.widgetWithText(PaywallLink, texts[name]!);

/// The name among the texts of the module of the text that the paywall
/// shows for [reason], the reason of a failure. A reason that the role gets
/// later has no name here, and this file does not compile until it has.
String failureTextOf(PurchasesFailureReason reason) => switch (reason) {
      PurchasesFailureReason.network => 'failureNetwork',
      PurchasesFailureReason.pending => 'pendingNotice',
      PurchasesFailureReason.alreadyOwned => 'failureOwned',
      PurchasesFailureReason.notAllowed => 'failureNotAllowed',
      PurchasesFailureReason.unavailable => 'failureUnavailable',
      PurchasesFailureReason.storeProblem => 'failureStore',
      PurchasesFailureReason.notConfigured => 'failureNotSetUp',
      PurchasesFailureReason.unknown => 'failureUnknown',
    };

/// Has the device ask for [language], a language of the app, which the app
/// follows while its user chose none.
Future<void> useLanguage(WidgetTester tester, String language) async {
  tester.platformDispatcher.localesTestValue = [Locale(language)];
  texts = paywallTexts[language]!;
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

/// Gives the app a phone tall enough for the paywall with the message of a
/// failure, so that a tap reaches every part of it without a scroll.
void useTallPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(420, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of the provider of
/// purchases, does not wait for the fake time of the test. An error of
/// [action] fails the test, which tester.runAsync would only report to the
/// handler of the errors of Flutter.
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
/// main() runs in real time, so a start-up that waits for a timer or for
/// input and output does not keep the fake time of the test waiting
/// forever. An error of main() fails the test. The handlers of errors that
/// the start-up installs and the builder of the widget of an error go back
/// to those of the test once main() returns.
///
/// A test file starts the app once: the start-up of an app may not run
/// twice, and the entrance of the paywall counts the time from the first
/// frame of the file.
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

/// The navigator of the router role for the page that the user sees, as
/// the code of that page has it.
AppNavigator navigatorOf(WidgetTester tester) =>
    appRouter.navigatorOf(tester.element(find.byType(Navigator).last));

/// Asks the router for [location] over the page that the user sees, as the
/// code of a page does with push(), and waits for the screen. Returns the
/// future of the page, which completes when the page is closed.
Future<Object?> push(WidgetTester tester, AppLocation location) async {
  final page = navigatorOf(tester).push<Object?>(location);
  await tester.pumpAndSettle();
  return page;
}

/// What [page], the future of a page that the router showed, completed
/// with, or [notCompleted] if it has not. A moment of real time passes
/// first: a router that showed the page while the app ran in real time may
/// complete it there.
Future<Object?> outcomeOf(WidgetTester tester, Future<Object?> page) async {
  Object? outcome = notCompleted;
  unawaited(page.then((value) => outcome = value));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
  return outcome;
}

/// What [outcomeOf] returns for a page whose future has not completed.
const Object notCompleted = 'not completed';

/// Presses the back button of the system and waits for the screen. Returns
/// whether the app handled the press.
Future<bool> pressSystemBack(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  return handled;
}

/// Taps [target], which starts a call of the provider of purchases, in real
/// time, and waits there until [until], for three seconds at most, with a
/// frame after each wait: the platform side of the provider may answer in
/// real time. Then the screen settles.
Future<void> tapInRealTime(
  WidgetTester tester,
  Finder target, {
  required bool Function() until,
}) async {
  await inRealTime(tester, 'a tap that starts a call of purchases', () async {
    await tester.tap(target);
    await _framesUntil(tester, until);
  });
  await _settleAfterRealTime(tester);
}

/// Shows frames in real time until [until], for three seconds at most.
Future<void> _framesUntil(WidgetTester tester, bool Function() until) async {
  for (var turn = 0; turn < 300 && !until(); turn++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await tester.pump();
  }
}

/// Lets a moment of real time pass, and then the screen settle, so that
/// what a change in real time set off ends too, such as a page that the
/// navigator disposes of once the router closed it.
Future<void> _settleAfterRealTime(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

/// Waits in real time until [until], for three seconds at most, with a
/// frame after each wait, as for the plans that the paywall loads from the
/// provider of purchases, whose platform side may answer in real time. Then
/// the screen settles.
Future<void> waitInRealTime(
  WidgetTester tester,
  String what, {
  required bool Function() until,
}) async {
  await inRealTime(tester, what, () => _framesUntil(tester, until));
  await _settleAfterRealTime(tester);
}

/// How many ids of users the tests of the file made.
int _users = 0;

/// A new id of a user of the app, which no identification named before.
String freshUser(String name) =>
    'paywall-$name-${DateTime.now().microsecondsSinceEpoch}-${++_users}';

/// Starts the purchases of the app with [service] and [user], the id of a
/// user of the app or `null` for the user of the device, in real time, and
/// waits for the screen.
Future<void> startPurchases(
  WidgetTester tester,
  PurchasesService service, {
  String? user,
}) async {
  await inRealTime(
    tester,
    'starting the purchases',
    () => appPurchases.start(service, userId: () => user),
  );
  await tester.pumpAndSettle();
}

/// Starts the purchases of the app with the service of the provider and a
/// fresh user, who has nothing bought, as the convention of the mocks of
/// every provider has it: a throwaway user takes over what the user of the
/// device bought first.
Future<void> startWithoutPremium(WidgetTester tester) async {
  await startPurchases(
    tester,
    createPurchasesService(),
    user: freshUser('throwaway'),
  );
  await startPurchases(
    tester,
    createPurchasesService(),
    user: freshUser('fresh'),
  );
}

/// A yearly plan with a free week, a monthly plan and a plan paid once, as
/// a service of the tests offers them.
const Plan yearlyOfTests = Plan(
  id: 'yearly',
  title: 'Yearly of the tests',
  price: r'$29.99',
  amount: 29.99,
  currencyCode: 'USD',
  period: BillingPeriod(1, BillingUnit.year),
  introOffer: IntroOffer(
    price: r'$0.00',
    amount: 0,
    period: BillingPeriod(1, BillingUnit.week),
  ),
);
const Plan monthlyOfTests = Plan(
  id: 'monthly',
  title: 'Monthly of the tests',
  price: r'$4.99',
  amount: 4.99,
  currencyCode: 'USD',
  period: BillingPeriod(1, BillingUnit.month),
);
const Plan lifetimeOfTests = Plan(
  id: 'lifetime',
  title: 'Lifetime of the tests',
  price: r'$79.99',
  amount: 79.99,
  currencyCode: 'USD',
);

/// A service of purchases of the tests, which a test gives the purchases of
/// the app to script what a provider answers: the offer, what a purchase
/// and a restore give, a failure of every call, and the access, which a test
/// changes as an expiry does. It notes each call that reaches it, and holds
/// the plans, a purchase or a restore back while a test says so.
final class ScriptedPurchases implements PurchasesService {
  final StreamController<AppAccess> _changes =
      StreamController<AppAccess>.broadcast();

  /// The access of the user.
  AppAccess access_ = const NoAccess();

  /// The plans of the offer.
  List<Plan> offer = const [yearlyOfTests, monthlyOfTests, lifetimeOfTests];

  /// What plans() fails with, if anything.
  PurchasesFailure? plansFailure;

  /// What a purchase and a restore fail with, if anything.
  PurchasesFailure? failure;

  /// What a purchase gives, or `null` for one that the user cancelled.
  AppAccess? purchaseAnswer = PremiumAccess(
    expiresAt: DateTime.utc(2031, 1, 2),
    renews: true,
    period: const BillingPeriod(1, BillingUnit.year),
  );

  /// What the calls named here wait for: `plans`, `purchase` and `restore`.
  final Map<String, Completer<void>> held = {};

  /// The calls that reached the service.
  final List<String> calls = [];

  /// Holds the next call [name] back until the completer that it returns
  /// completes.
  Completer<void> hold(String name) => held[name] = Completer<void>();

  /// The access changes without a call of the app, as when it ends.
  void tell(AppAccess access) {
    access_ = access;
    _changes.add(access);
  }

  Future<void> _call(String name, [String? note]) async {
    calls.add(note == null ? name : '$name $note');
    final completer = held.remove(name);
    if (completer != null) await completer.future;
  }

  @override
  Future<void> identify(String? userId) async {}

  @override
  Future<AppAccess> access() async => access_;

  @override
  Stream<AppAccess> get accessChanges => _changes.stream;

  @override
  Future<List<Plan>> plans() async {
    await _call('plans');
    if (plansFailure case final failure?) throw failure;
    return offer;
  }

  @override
  Future<AppAccess?> purchase(Plan plan) async {
    await _call('purchase', plan.id);
    if (failure case final failure?) throw failure;
    if (purchaseAnswer case final answer?) access_ = answer;
    return purchaseAnswer;
  }

  @override
  Future<AppAccess> restore() async {
    await _call('restore');
    if (failure case final failure?) throw failure;
    return access_;
  }
}

/// Records the links that the app opens, in place of the platform side of
/// url_launcher: each with its mode.
final class LinkRecorder extends UrlLauncherPlatform {
  /// The links that the app opened, each as `<link> <mode>`.
  final List<String> opened = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add('$url ${options.mode.name}');
    return true;
  }
}

/// Puts a [LinkRecorder] in place of the platform side of url_launcher for
/// the rest of the test, and returns it.
LinkRecorder recordLinks() {
  final before = UrlLauncherPlatform.instance;
  final recorder = LinkRecorder();
  UrlLauncherPlatform.instance = recorder;
  addTearDown(() => UrlLauncherPlatform.instance = before);
  return recorder;
}
