// A test that continuous integration runs in the apps with the purchases
// role, whichever module provides it: appPurchases over the service of the
// provider. The offer has at least one plan, each with an id of its own, a
// title, a price in a currency and periods of one unit or more. A fresh
// user who buys a plan has premium access as the plan gives it, the
// listeners hear of it once, and a restore gives the access. The purchases
// of each user stay apart. And the probe of the role, which the start check
// runs on a device, finds no problem, and reports an access of the app that
// the service of the provider does not give.
//
// It knows only the role. The start-up of the app runs first, as on a
// device, since it starts the purchases, with the mocks of the platform side
// of every module of the app, which the matrix sets up before the tests of
// each test file (flutter_test_config.dart). Each test identifies a
// throwaway user first, which takes over what the user of the device
// bought, and then fresh users of its own, as the convention of the mocks
// of the role lets it do (purchases_role.dart). The purchases of the tests
// stay with the users of the tests: what a test bought, a user of another
// test never has, but for a restore, which no expectation relies on. The
// test of whose the purchases are comes last, after every other test that
// buys. Each expectation gives its reason, which a provider of the role
// with a known bug fails the test with (brokenProviders of the fixture
// registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';

import '../../integration_test/purchases_role/probe.dart';
import 'purchases_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the offer has at least one plan, each with an id of its own, a title, a '
    'price in a currency, and periods of one unit or more',
    (tester) async {
      await startUp(tester);
      await identifyThrowaway(tester);
      await startAs(tester, createPurchasesService(), freshUser('offered'));
      var plans = const <Plan>[];
      await inRealTime(tester, 'asking for the plans', () async {
        plans = await appPurchases.plans();
      });

      expect(
        plans,
        isNotEmpty,
        reason: 'The offer of a provider has at least one plan, as the mocks '
            'of every provider give it.',
      );
      expect(
        {for (final plan in plans) plan.id},
        hasLength(plans.length),
        reason: 'Each plan of the offer has an id of its own.',
      );
      expect(
        [for (final plan in plans) ..._problemsOf(plan)],
        isEmpty,
        reason: 'Each plan has a title, the price that the store shows, an '
            'amount of 0 or more, the ISO 4217 code of its currency and a '
            'period of one unit or more, or none for a plan paid once. Its '
            'intro offer, if any, has a price too, and lasts one period of '
            'one unit or more, or several.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the probe of the role finds no problem after the start-up, and for a '
    'fresh user without premium access',
    (tester) async {
      await startUp(tester);
      late List<String> afterStartUp;
      late List<String> ofFreshUser;

      await inRealTime(tester, 'the probe after the start-up', () async {
        afterStartUp = await probePurchases(() async {});
      });
      await identifyThrowaway(tester);
      await startAs(tester, createPurchasesService(), freshUser('probed'));
      await inRealTime(tester, 'the probe of a fresh user', () async {
        ofFreshUser = await probePurchases(() async {});
      });

      expect(
        [...afterStartUp, ...ofFreshUser],
        isEmpty,
        reason: 'The probe finds no problem with purchases that keep the '
            'contract of the role: the access of the app is the one that the '
            'service of the provider gives for the user of the app.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the probe of the role reports an access of the app that is not the one '
    'that the service of the provider gives',
    (tester) async {
      await startUp(tester);
      await identifyThrowaway(tester);
      await startAs(tester, createPurchasesService(), freshUser('mismatch'));
      // A service of the test, whose access the probe finds in appPurchases;
      // the service of the provider gives none for its fresh user.
      await startAs(
        tester,
        ScriptedPurchases()..accessOf[null] = premiumOfTests,
        null,
      );
      late List<String> problems;
      await inRealTime(tester, 'the probe', () async {
        problems = await probePurchases(() async {});
      });

      expect(
        (describe(appPurchases.value), problems.length),
        (describe(premiumOfTests), 1),
        reason: 'The probe reports an access of the app that is not the one '
            'that the service of the provider gives for the user of the app.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a fresh user who buys a plan has premium access as the plan gives it, '
    'the listeners hear of it once, the probe finds no problem, and a '
    'restore gives the access, for each plan',
    (tester) async {
      await startUp(tester);
      await identifyThrowaway(tester);
      final heard = <String>[];
      void listener() => heard.add(describe(appPurchases.value));
      // What happened for each plan, by its id.
      final ofPlans = <String,
          ({
        Plan plan,
        Object? failure,
        DateTime boughtAt,
        String access,
        AppAccess value,
        List<String> heard,
        List<String> probe,
        String restored,
        String afterRestore,
      })>{};
      var ids = const <String>[];
      await inRealTime(tester, 'asking for the plans', () async {
        ids = [for (final plan in await appPurchases.plans()) plan.id];
      });

      for (final id in ids) {
        await startAs(tester, createPurchasesService(), freshUser('buyer'));
        await inRealTime(tester, 'buying the plan $id', () async {
          // The plan as this user gets it, with the intro offer that this
          // user may take.
          final plan =
              (await appPurchases.plans()).singleWhere((plan) => plan.id == id);
          heard.clear();
          appPurchases.addListener(listener);
          final boughtAt = DateTime.now();
          final failure = await errorOf(() => appPurchases.purchase(plan));
          final value = appPurchases.value;
          appPurchases.removeListener(listener);
          final probe = await probePurchases(() async {});
          final restored = await appPurchases.restore();
          ofPlans[id] = (
            plan: plan,
            failure: failure,
            boughtAt: boughtAt,
            access: describe(value),
            value: value,
            heard: [...heard],
            probe: probe,
            restored: describe(restored),
            afterRestore: describe(appPurchases.value),
          );
        });
      }

      expect(
        {
          for (final MapEntry(:key, :value) in ofPlans.entries)
            key: value.failure
        },
        {for (final id in ids) id: null},
        reason: 'A purchase by a user without premium access completes and '
            'succeeds, as the mocks of every provider do.',
      );
      for (final MapEntry(key: id, value: ofPlan) in ofPlans.entries) {
        final plan = ofPlan.plan;
        final value = ofPlan.value;
        expect(
          value,
          isA<PremiumAccess>(),
          reason: 'Every plan gives premium access ($id).',
        );
        if (value is! PremiumAccess) continue;
        if (plan.period == null) {
          expect(
            (value.expiresAt, value.renews),
            (null, false),
            reason: 'A plan paid once gives premium access for good, which '
                'does not renew ($id).',
          );
        } else {
          expect(
            (
              value.expiresAt?.isAfter(ofPlan.boughtAt) ?? false,
              value.renews,
            ),
            (true, true),
            reason: 'A plan with a period gives premium access until a time '
                'after the purchase, and renews until the user cancels '
                '($id).',
          );
        }
        expect(
          value.inTrial,
          plan.introOffer?.isFree ?? false,
          reason: 'A fresh user who buys a plan with a free trial that the '
              'user may take has the premium access of the trial ($id).',
        );
        expect(
          ofPlan.heard,
          [ofPlan.access],
          reason: 'The listeners of appPurchases hear of the access that a '
              'purchase gave once ($id).',
        );
        expect(
          ofPlan.probe,
          isEmpty,
          reason: 'The probe finds no problem with the access that a purchase '
              'gave ($id).',
        );
        expect(
          (ofPlan.restored.startsWith('premium access'), ofPlan.afterRestore),
          (true, ofPlan.restored),
          reason: 'A restore gives the user what the store account bought, '
              'which has the plan of the user, and that access becomes the '
              'value ($id).',
        );
      }
    },
    timeout: timeout,
  );

  testWidgets(
    'the purchases of each user stay apart: a fresh user has nothing, a '
    'purchase gives that user premium access, another fresh user has '
    'nothing, and the first user has the access again',
    (tester) async {
      await startUp(tester);
      await identifyThrowaway(tester);
      final first = freshUser('first');
      final second = freshUser('second');
      late String ofFirst;
      Object? failure;
      late String bought;
      late String ofSecond;
      late String backToFirst;

      await startAs(tester, createPurchasesService(), first);
      ofFirst = describe(appPurchases.value);
      await inRealTime(tester, 'buying a plan', () async {
        final plans = await appPurchases.plans();
        failure = await errorOf(() => appPurchases.purchase(plans.first));
      });
      bought = describe(appPurchases.value);
      await startAs(tester, createPurchasesService(), second);
      ofSecond = describe(appPurchases.value);
      await startAs(tester, createPurchasesService(), first);
      backToFirst = describe(appPurchases.value);

      expect(
        (ofFirst, ofSecond),
        ('no access', 'no access'),
        reason: 'A provider keeps the purchases of each user apart: a user '
            'that no identification named before, identified after another '
            'user of the app, has nothing bought, whatever the users of the '
            'app before bought.',
      );
      expect(
        failure,
        isNull,
        reason: 'A purchase by a user without premium access succeeds.',
      );
      expect(
        (bought.startsWith('premium access'), backToFirst),
        (true, bought),
        reason: 'A provider keeps the purchases of each user apart: the user '
            'who bought a plan has its premium access again once the user of '
            'the app is that user again.',
      );
    },
    timeout: timeout,
  );
}

/// What is wrong with [plan], each problem with the id of the plan.
List<String> _problemsOf(Plan plan) {
  final intro = plan.introOffer;
  return [
    if (plan.id.isEmpty) 'a plan without an id',
    if (plan.title.trim().isEmpty) '${plan.id}: no title',
    if (plan.price.trim().isEmpty) '${plan.id}: no price',
    if (plan.amount < 0) '${plan.id}: an amount below 0',
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(plan.currencyCode))
      '${plan.id}: the currency ${plan.currencyCode}',
    if (plan.period case final period? when period.count < 1)
      '${plan.id}: a period of ${period.count} units',
    if (intro != null) ...[
      if (intro.price.trim().isEmpty)
        '${plan.id}: an intro offer without a '
            'price',
      if (intro.amount < 0) '${plan.id}: an intro offer below 0',
      if (intro.period.count < 1 || intro.cycles < 1)
        '${plan.id}: an intro offer of ${intro.cycles} periods of '
            '${intro.period.count} units',
    ],
  ];
}
