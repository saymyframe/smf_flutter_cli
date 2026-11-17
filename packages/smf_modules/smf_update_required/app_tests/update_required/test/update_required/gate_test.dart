// A test that continuous integration runs in the apps with the
// update_required module: the screen "Update required" takes the place of
// the app while the version of the app, 1.0.0 in the tests, is below the
// lowest version that may run in remote config, and only then.
//
// The defaults of remote config never show the screen. A lowest version of
// 1.0.1 shows it at once in place of the screen that the app starts on, which
// the app does not build then, and a lowest version that the version is not
// below, or that is no version, or blanks, does not. Lowering the lowest
// version brings the user back. The screen is hard: "Update" opens the store
// page once, and "Not now" shows only after that and lets the user in. A
// store page that did not open shows the failure and "Not now" at once.
// Another lowest version takes the place of the app again, and so does the
// next launch, updateStatus.start() again, which forgets that the user let
// a lowest version pass. On iOS without the App Store ID of the app, which
// the tests leave empty, the app has no store page, and the screen never
// shows: a debug build says why.
//
// The screen only changes what the guard of the routes of the module reads:
// the router of the app, whichever module provides it, shows the screen and
// leaves it, as the router role says of the guards of the routes. The test
// gives remote config and the reviews services of its own, which script what
// their providers answer.
//
// It also runs the probe of the module, which the start check runs on a
// device (integration_test/update_required/probe.dart): it finds no problem
// in each state of the screen, and reports a version of the app that is not
// numbers between dots.
//
// The test starts the app once, since the start-up of an app may not run
// twice, and each expectation gives its reason.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/review/app_review.dart';
import 'package:{{app_name}}/features/update_required/update_required_screen.dart';
import 'package:{{app_name}}/features/update_required/update_status.dart';

import '../../integration_test/update_required/probe.dart';
import '../update_required_mocks.dart';
import 'of_app.dart';
import 'update_required.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// What the probe of the module finds in the running app, as the start
  /// check runs it: in real time, with a function that waits until the
  /// screen settles.
  Future<List<String>> probe(WidgetTester tester) async {
    var problems = <String>[];
    await inRealTime(
      tester,
      'the probe of the module',
      () async => problems = await probeUpdateRequired(tester.pumpAndSettle),
    );
    await tester.pumpAndSettle();
    return problems;
  }

  /// Checks that the app shows the screen of the module in place of the
  /// screen that it starts on, which it does not build, once [what].
  Future<void> expectGate(WidgetTester tester, String what) async {
    expect(
      updateStatus.supported.value,
      isFalse,
      reason: 'Once $what, the version of the app may not run.',
    );
    expect(
      gate,
      findsOneWidget,
      reason: 'Once $what, the app shows the screen "Update required".',
    );
    expect(
      find.byType(startScreen, skipOffstage: false),
      findsNothing,
      reason: 'Once $what, the screen "Update required" takes the place of '
          'the app, which does not build the screen that it starts on.',
    );
    expect(
      await probe(tester),
      isEmpty,
      reason: 'Once $what, the probe of the module finds no problem.',
    );
  }

  /// Checks that the app shows the screen that it starts on and not the
  /// screen of the module, once [what].
  Future<void> expectApp(WidgetTester tester, String what) async {
    expect(
      updateStatus.supported.value,
      isTrue,
      reason: 'Once $what, the version of the app may run.',
    );
    expect(
      find.byType(UpdateRequiredScreen, skipOffstage: false),
      findsNothing,
      reason: 'Once $what, the app does not show the screen "Update '
          'required".',
    );
    expect(
      find.byType(startScreen),
      findsOneWidget,
      reason: 'Once $what, the app shows the screen that it starts on.',
    );
    expect(
      await probe(tester),
      isEmpty,
      reason: 'Once $what, the probe of the module finds no problem.',
    );
  }

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the screen "Update required" takes the place of the app while its '
    'version is below the lowest version that may run, is hard until the '
    'user opens the store from it, then lets the user in for this launch, '
    'and never shows on iOS without the App Store ID',
    (tester) async {
      await startApp(tester);
      await expectApp(tester, 'the app started with the defaults');
      expect(
        updateStatus.version,
        testVersion,
        reason: 'The app reads its version, without the build number, from '
            'package_info_plus.',
      );

      await useScriptedServices(tester);
      await expectApp(tester, 'remote config has no lowest version');

      // Lowest versions that the version of the app is not below, and
      // texts that are no version.
      for (final minimum in ['1.0.0', '0.9', '1', 'abc', '1.0.0-beta', '  ']) {
        await publishMinimum(tester, minimum);
        await expectApp(tester, 'the lowest version is "$minimum"');
      }

      await publishMinimum(tester, '1.0.1');
      await expectGate(tester, 'the lowest version is 1.0.1');
      expect(
        shown(find.text(texts['title']!)),
        findsOneWidget,
        reason: 'The screen says that an update is required.',
      );
      expect(
        updateButton(),
        findsOneWidget,
        reason: 'The screen has the button "Update".',
      );
      expect(
        laterButton(),
        findsNothing,
        reason: 'The screen is hard until the user opens the store from it: '
            'it does not offer "Not now" yet.',
      );
      expect(
        review.pages,
        isEmpty,
        reason: 'The screen opens the store page only on a tap.',
      );

      // Back below the version of the app: the user is back.
      await publishMinimum(tester, '1.0.0');
      await expectApp(tester, 'the lowest version went back to 1.0.0');

      await publishMinimum(tester, '1.0.1');
      await expectGate(tester, 'the lowest version is 1.0.1 again');
      await tester.tap(updateButton());
      await tester.pumpAndSettle();
      expect(
        review.pages,
        [appReview.storePage()],
        reason: '"Update" opens the page of the app in its store once, '
            'through the review role.',
      );
      expect(
        updateStatus.storeVisit.value,
        StoreVisit.opened,
        reason: 'The store page opened.',
      );
      expect(
        laterButton(),
        findsOneWidget,
        reason: 'Once the user opened the store from the screen, the screen '
            'offers "Not now".',
      );
      expect(
        storeFailed(),
        findsNothing,
        reason: 'The store page opened, so the screen says nothing of a '
            'failure.',
      );
      expect(await probe(tester), isEmpty);
      await tester.tap(laterButton());
      await tester.pumpAndSettle();
      await expectApp(tester, 'the user tapped "Not now"');
      expect(
        updateStatus.waived,
        '1.0.1',
        reason: '"Not now" lets the user in below the lowest version that '
            'remote config has.',
      );

      // Another lowest version takes the place of the app again, and the
      // screen is hard again.
      await publishMinimum(tester, '1.0.2');
      await expectGate(tester, 'another lowest version, 1.0.2, came');
      expect(
        laterButton(),
        findsNothing,
        reason: 'For another lowest version, the screen is hard again until '
            'the user opens the store from it.',
      );

      // A store page that no app of the device opens.
      review.opens = false;
      await tester.tap(updateButton());
      await tester.pumpAndSettle();
      expect(
        review.pages,
        hasLength(2),
        reason: 'Each tap on "Update" opens the store page once.',
      );
      expect(
        storeFailed(),
        findsOneWidget,
        reason: 'When the store page did not open, the screen says so.',
      );
      expect(
        laterButton(),
        findsOneWidget,
        reason: 'When the store page did not open, the screen offers "Not '
            'now" at once, so that nobody is locked out.',
      );
      await tester.tap(laterButton());
      await tester.pumpAndSettle();
      await expectApp(tester, 'the user tapped "Not now" after a failure');

      // The next launch forgets that the user let the lowest version pass.
      await startStatusAgain(tester);
      await expectGate(tester, 'the next launch found the lowest version');
      expect(
        laterButton(),
        findsNothing,
        reason: 'At the next launch, the screen is hard again.',
      );
      expect(
        storeFailed(),
        findsNothing,
        reason: 'At the next launch, the screen says nothing of a failure '
            'of the launch before.',
      );

      // On iOS, the store page needs the App Store ID of the app.
      await publishMinimum(tester, '');
      await expectApp(tester, 'the lowest version is empty again');
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final printed = await printedBy(
          tester,
          'publishing 1.0.3 on iOS',
          () async {
            remoteConfig.publish({minimumParameter: '1.0.3'});
            await aMoment();
          },
        );
        await tester.pumpAndSettle();
        if (appReview.hasStorePage) {
          await expectGate(tester, 'the lowest version is 1.0.3 on iOS');
        } else {
          await expectApp(
            tester,
            'the lowest version is 1.0.3 on iOS without the App Store ID',
          );
          expect(
            printed,
            contains(contains(appStoreIdKey)),
            reason: 'On iOS without the App Store ID, a debug build says why '
                'the screen does not show, and names the key of .env.',
          );
        }
        await publishMinimum(tester, '');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      // A version of the app that is no version keeps the app running, and
      // the probe reports it.
      mockUpdateRequired(version: '1.0.0-dev');
      await publishMinimum(tester, '2.0.0');
      final printed = await printedBy(
        tester,
        'updateStatus.start() with the version 1.0.0-dev',
        updateStatus.start,
      );
      await tester.pumpAndSettle();
      expect(
        printed,
        contains(contains('"1.0.0-dev"')),
        reason: 'A debug build says that the version of the app is not '
            'numbers between dots.',
      );
      expect(
        updateStatus.supported.value,
        isTrue,
        reason: 'A version of the app that is no version keeps it running.',
      );
      expect(
        await probe(tester),
        [contains('"1.0.0-dev"')],
        reason: 'The probe reports a version of the app that is not numbers '
            'between dots.',
      );
      mockUpdateRequired();
      await startStatusAgain(tester);
      await expectGate(tester, 'the version is 1.0.0 again');
      await publishMinimum(tester, '');
      await expectApp(tester, 'the lowest version is empty at the end');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
