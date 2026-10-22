// A test that continuous integration runs in the apps with the purchases
// role, whichever module provides it: the controller that the template of
// the role generates, over a service of purchases of the test that scripts
// what a provider answers. A call made before the first start waits for it,
// and the start completes after it and after the purchase that its
// completion makes. The start waits for the access at most startWait, and
// an access that comes later still becomes the value. The controller asks
// the service again each time the user comes back to the app, and takes
// each change that the service tells of. A change of the user waits for the
// purchase on its way, which belongs to the user who made it. A provider
// without what it needs leaves the app without purchases and never stops
// it. And a call fails only with a PurchasesFailure, a cancel is no
// failure, and an answer that gives no premium access fails.
//
// It knows only the role. Each test creates a controller of its own, as the
// role lets a test do, and disposes of it, so appPurchases stays as the
// start-up of the app would leave it, which these tests do not run. A
// controller is created in real time, as the start-up of the app creates
// appPurchases: a call made before the first start waits for a future that
// the controller keeps, which completes in the zone that created it, and
// the fake time of a widget test runs nothing while the test waits for real
// time.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';

import 'purchases_role.dart';

/// A controller of the test, created in real time, with [startWait] if
/// given, which the test disposes of once it ends.
Future<AppPurchasesController> newController(
  WidgetTester tester, {
  Duration? startWait,
}) async {
  late AppPurchasesController controller;
  await tester.runAsync(() async {
    controller = startWait == null
        ? AppPurchasesController()
        : AppPurchasesController(startWait: startWait);
  });
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'a call made before the first start waits for it, and the start '
    'completes after it and after the purchase that its completion makes',
    (tester) async {
      final controller = await newController(tester);
      final service = ScriptedPurchases();
      late String atStartEnd;
      late bool bought;

      await inRealTime(tester, 'the start', () async {
        final early = controller
            .plans()
            .then((plans) => controller.purchase(plans.first));
        await controller.start(service);
        atStartEnd = describe(controller.value);
        bought = await early;
      });

      expect(
        service.calls,
        ['identify null', 'access', 'plans', 'purchase monthly'],
        reason: 'A call made before the first start waits for it, and runs '
            'once the start has the access: the service is identified '
            'first, as the role asks.',
      );
      expect(
        (atStartEnd, bought),
        (describe(premiumOfTests), true),
        reason: 'The start completes once the calls made before it, and the '
            'purchase that the completion of plans() made right away, are '
            'over: the app starts with the access that they bought, as the '
            'mocks of a module that buy a plan before the app starts rely '
            'on.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the start waits for the access at most startWait, and an access that '
    'comes later still becomes the value',
    (tester) async {
      final controller = await newController(
        tester,
        startWait: const Duration(milliseconds: 300),
      );
      final service = ScriptedPurchases()..accessOf[null] = premiumOfTests;
      late Duration waited;
      late String atStart;
      late String later;

      await inRealTime(tester, 'the start', () async {
        final held = service.hold('access');
        final watch = Stopwatch()..start();
        await controller.start(service);
        waited = watch.elapsed;
        atStart = describe(controller.value);
        held.complete();
        await aMoment();
        later = describe(controller.value);
      });

      expect(
        (waited < const Duration(seconds: 2), atStart),
        (true, 'no access'),
        reason: 'The start waits for the access at most startWait, so the '
            'app starts while a store does not answer, without the access.',
      );
      expect(
        later,
        describe(premiumOfTests),
        reason: 'An access that comes after the start still becomes the '
            'value.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the controller asks the service again each time the user comes back to '
    'the app, and takes each change that the service tells of',
    (tester) async {
      final controller = await newController(tester);
      final service = ScriptedPurchases();
      late String atStart;
      late String afterGrant;
      late String afterExpiry;

      await inRealTime(tester, 'the start', () async {
        await controller.start(service);
        atStart = describe(controller.value);
        // A grant made elsewhere, such as on the server of the provider.
        service.accessOf[null] = premiumOfTests;
      });
      await comeBack(tester);
      afterGrant = describe(controller.value);
      final asked = service.calls.where((call) => call == 'access').length;
      await inRealTime(tester, 'an expiry', () async {
        service.tell(const NoAccess());
        await aMoment();
      });
      afterExpiry = describe(controller.value);

      expect(atStart, 'no access');
      expect(
        (afterGrant, asked),
        (describe(premiumOfTests), 2),
        reason: 'Each time the user comes back to the app, the controller '
            'asks the service for the access again, so that a grant made '
            'elsewhere, an expiry or a refund shows.',
      );
      expect(
        afterExpiry,
        'no access',
        reason: 'The controller takes each change of the access that the '
            'service tells of, such as an expiry.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a change of the user waits for the purchase on its way, which belongs '
    'to the user who made it, and the access is none until the service has '
    'the new user',
    (tester) async {
      final controller = await newController(tester);
      final service = ScriptedPurchases()..accessOf['first'] = premiumOfTests;
      final user = ValueNotifier<String?>('first');
      addTearDown(user.dispose);
      late String ofFirst;
      late String whileChanging;
      late bool bought;
      late String afterPurchase;
      late String ofSecond;
      late String backToFirst;

      await inRealTime(tester, 'the purchase and the changes', () async {
        await controller.start(
          service,
          userId: () => user.value,
          userChanges: user,
        );
        ofFirst = describe(controller.value);
        final held = service.hold('purchase');
        final purchase = controller.purchase(monthlyOfTests);
        await aMoment();
        user.value = 'second';
        whileChanging = describe(controller.value);
        held.complete();
        bought = await purchase;
        afterPurchase = describe(controller.value);
        // A call takes its turn after the look at the new user.
        await controller.plans();
        ofSecond = describe(controller.value);
        user.value = 'first';
        await controller.plans();
        backToFirst = describe(controller.value);
      });

      expect(
        service.calls.take(5).toList(),
        [
          'identify first',
          'access',
          'purchase monthly',
          'identify second',
          'access',
        ],
        reason: 'A change of the user waits for the purchase that is on its '
            'way: the service identifies the new user only once the purchase '
            'is over, so the purchase is for the user who made it.',
      );
      expect(
        (ofFirst, whileChanging, bought, afterPurchase, ofSecond),
        (describe(premiumOfTests), 'no access', true, 'no access', 'no access'),
        reason: 'Until the service has the new user, the access is none, and '
            'the access that a purchase of the user before gave is not that '
            'of the new user.',
      );
      expect(
        backToFirst,
        describe(premiumOfTests),
        reason: 'The user who made the purchase has its access once that user '
            'is the user of the app again.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'with a provider without what it needs, the app starts without '
    'purchases, every call fails with notConfigured, the hint is printed '
    'once in debug mode, and nothing reaches the handlers of the uncaught '
    'errors',
    (tester) async {
      final controller = await newController(tester);
      const hint = 'The key of the purchases of the tests is missing.';
      final service = ScriptedPurchases(
        failure: const PurchasesFailure(
          PurchasesFailureReason.notConfigured,
          developerHint: hint,
        ),
      );
      final printed = <String>[];
      final uncaught = <Object>[];
      Object? failure;
      late String access;

      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      try {
        await inRealTime(tester, 'the calls', () async {
          await runZonedGuarded(
            () async {
              await controller.start(service);
              tester.binding
                ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
                ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
              await aMoment();
              failure = await errorOf(controller.plans);
            },
            (error, _) => uncaught.add(error),
          );
          access = describe(controller.value);
        });
      } finally {
        debugPrint = print;
      }

      expect(
        failure,
        failsWith(PurchasesFailureReason.notConfigured),
        reason: 'A provider without what it needs fails every call with '
            'notConfigured.',
      );
      expect(
        access,
        'no access',
        reason: 'An app whose provider lacks what it needs runs without '
            'purchases.',
      );
      expect(
        [
          for (final line in printed)
            if (line.contains(hint)) line,
        ],
        hasLength(1),
        reason: 'A failure notConfigured that no caller sees prints its hint '
            'once in debug mode, also when the controller looks again.',
      );
      expect(
        uncaught,
        isEmpty,
        reason: 'A provider without what it needs never stops the app: a '
            'failure notConfigured that no caller sees reaches no handler of '
            'the uncaught errors.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a call fails only with a PurchasesFailure, a purchase that the user '
    'cancelled completes with false, and one whose answer gives no premium '
    'access fails with notConfigured',
    (tester) async {
      final controller = await newController(tester);
      final service = ScriptedPurchases();
      Object? broken;
      Object? gaveNothing;
      late bool cancelled;
      late String afterCancel;

      await inRealTime(tester, 'the calls', () async {
        await controller.start(service);
        service.plansError = StateError('The store of the tests broke.');
        broken = await errorOf(controller.plans);
        service.purchaseAnswer = (_) => null;
        cancelled = await controller.purchase(monthlyOfTests);
        afterCancel = describe(controller.value);
        service.purchaseAnswer = (_) => const NoAccess();
        gaveNothing = await errorOf(
          () => controller.purchase(monthlyOfTests),
        );
      });

      expect(
        broken,
        isA<PurchasesFailure>()
            .having(
              (failure) => failure.reason,
              'reason',
              PurchasesFailureReason.unknown,
            )
            .having(
              (failure) => failure.developerHint,
              'developerHint',
              contains('The store of the tests broke.'),
            ),
        reason: 'An error of another kind than a PurchasesFailure becomes '
            'the reason unknown, with the error as the hint.',
      );
      expect(
        (cancelled, afterCancel),
        (false, 'no access'),
        reason: 'A purchase that the user cancelled completes with false, '
            'which is no failure, and changes nothing.',
      );
      expect(
        gaveNothing,
        failsWith(PurchasesFailureReason.notConfigured),
        reason: 'A purchase whose answer gives no premium access fails with '
            'notConfigured, since every plan gives premium access.',
      );
    },
    timeout: timeout,
  );
}
