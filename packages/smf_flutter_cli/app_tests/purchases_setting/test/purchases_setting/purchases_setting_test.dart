// A test that continuous integration runs in the apps with the purchases
// role and the settings screen role, whichever modules provide them: the
// entry that restores purchases, which the template of the purchases role
// gives the settings screen, over a service of the test that scripts what
// a provider answers. The screen shows the entry once, with its title and
// no result before a restore, in each language of the app. A tap restores
// once, and the entry shows what the restore found: that the premium
// access is back, that there was nothing to restore, or that the restore
// failed, for every reason of a failure and for an error of another kind,
// with the words of the provider below it in debug mode, which the tests
// run in. A screen reader reads the result as it comes. While a restore is
// on its way, the entry shows a spinner and no result of an earlier
// restore, and a second tap restores nothing more. On a small phone with a
// large text size, the title and a long failure stay in the row of the
// entry, in full.
//
// It knows only the two roles, and starts the app once, since the start-up
// of an app may not run twice. The matrix writes setting.dart next to it,
// from the entries of the settings screen role and the languages of the
// localization role of the app: the type of the widget of the entry and
// its texts in each language. It opens the settings screen as the tests of
// the settings screen role do, and takes the service of the tests, which
// scripts what a provider answers, from the files of the test of the
// purchases role. Both of those tests run in every app that this one runs
// in. Each expectation gives its reason.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/purchases/purchases_service.dart';

import '../purchases_role/purchases_role.dart';
import '../settings_screen_role/open_settings.dart';
import 'setting.dart';

/// Waits in real time until [done] holds, for three seconds at most.
Future<void> _until(bool Function() done) async {
  for (var turn = 0; turn < 300 && !done(); turn++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// The service of the tests of the purchases role, whose restore fails with
/// [restoreError] while a test sets it, once the restore reached the
/// service: a store that does not answer, or a provider without what it
/// needs, fails the restore of a user whom the service knows.
final class _Restores implements PurchasesService {
  _Restores(this._scripted);

  final ScriptedPurchases _scripted;

  /// What the next restores fail with, or `null`.
  Object? restoreError;

  @override
  Future<void> identify(String? userId) => _scripted.identify(userId);

  @override
  Future<AppAccess> access() => _scripted.access();

  @override
  Stream<AppAccess> get accessChanges => _scripted.accessChanges;

  @override
  Future<List<Plan>> plans() => _scripted.plans();

  @override
  Future<AppAccess?> purchase(Plan plan) => _scripted.purchase(plan);

  @override
  Future<AppAccess> restore() async {
    final access = await _scripted.restore();
    if (restoreError case final error?) throw error;
    return access;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the entry that restores purchases shows what a restore found in the '
    'language of the app, takes no second tap while a restore is on its '
    'way, and keeps its texts in its row on a small phone',
    (tester) async {
      await openSettings(tester);
      // The device asks for the first language of the app, which the app is
      // in then.
      final first = restoreTexts.keys.first;
      tester.platformDispatcher.localesTestValue = [Locale(first)];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpAndSettle();

      final entry = find.byType(restorePurchasesSetting);
      // The texts of the entry in that language.
      final texts = restoreTexts[first]!;
      // The texts that the entry shows, each of its lines on its own.
      List<String> lines() => [
            for (final text in tester.widgetList<Text>(
              find.descendant(of: entry, matching: find.byType(Text)),
            ))
              ...(text.data ?? text.textSpan!.toPlainText()).split('\n'),
          ];
      // The spinner of the entry.
      final spinner = find.descendant(
        of: entry,
        matching: find.byWidgetPredicate(
          (widget) => widget is ProgressIndicator,
          description: 'a spinner',
        ),
      );
      // The language that the app is in where the entry is.
      String language() =>
          Localizations.localeOf(tester.element(entry)).languageCode;
      // Has the device ask for each language of the app in turn, and checks
      // that the entry shows the texts that [shown] gives in each, which
      // [what] tells; then the device asks for the first language of the
      // app again.
      Future<void> inEachLanguage(
        List<String> Function(RestoreTexts texts) shown,
        String what,
      ) async {
        for (final MapEntry(key: code, value: texts) in restoreTexts.entries) {
          tester.platformDispatcher.localesTestValue = [Locale(code)];
          await tester.pumpAndSettle();
          expect(
            language(),
            code,
            reason: 'The app is in the language that the device asks for, '
                '$code, one of its languages.',
          );
          expect(
            lines(),
            unorderedEquals(shown(texts)),
            reason: 'The entry shows $what in the language of the app, $code.',
          );
        }
        tester.platformDispatcher.localesTestValue = [Locale(first)];
        await tester.pumpAndSettle();
      }

      expect(
        entry,
        findsOneWidget,
        reason: 'The settings screen shows the entry that restores purchases '
            'once.',
      );
      await inEachLanguage(
        (texts) => [texts.title],
        'its title and no result, since nothing was restored yet,',
      );

      // A service of the test, which the app takes as it takes the service
      // of the provider at its start, for the user of the device.
      final scripted = ScriptedPurchases();
      final service = _Restores(scripted);
      await startAs(tester, service, null);
      await tester.pumpAndSettle();

      // Taps the entry, as the user does, and returns the calls that the
      // tap made to the service. It waits in real time until the tap
      // reached the service, for three seconds at most, and a moment more
      // for the restore to end, then lets the entry show what it found.
      Future<List<String>> tap() async {
        final before = scripted.calls.length;
        await inRealTime(tester, 'a tap on the entry', () async {
          await tester.tap(entry);
          await _until(() => scripted.calls.length > before);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        return scripted.calls.sublist(before);
      }

      // The store account of the user bought nothing.
      expect(
        await tap(),
        ['restore'],
        reason: 'A tap on the entry restores, once.',
      );
      await inEachLanguage(
        (texts) => [texts.title, texts.none],
        'that there was nothing to restore',
      );

      // The store account of the user bought a plan, such as on another
      // device.
      scripted.accessOf[null] = premiumOfTests;
      expect(
        await tap(),
        ['restore'],
        reason: 'A tap on the entry restores, once.',
      );
      await inEachLanguage(
        (texts) => [texts.title, texts.active],
        'that the premium access is back',
      );
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(
          find.descendant(
              of: entry, matching: find.textContaining(texts.active)),
        ),
        isSemantics(isLiveRegion: true),
        reason: 'A screen reader reads what the restore found once it comes: '
            'the result is in a live region.',
      );
      semantics.dispose();

      // A restore that takes a while, as one that waits for the store: the
      // service holds it back until the test lets it go. The test creates
      // and completes the completer in real time, where the restore waits
      // for it.
      late Completer<void> held;
      await inRealTime(tester, 'holding the restore back', () async {
        held = scripted.hold('restore');
      });
      final beforeHeld = scripted.calls.length;
      await inRealTime(tester, 'a tap on the entry', () async {
        await tester.tap(entry);
        await _until(() => scripted.calls.length > beforeHeld);
      });
      // A frame of the entry while the restore is on its way.
      await tester.pump();
      expect(
        spinner,
        findsOneWidget,
        reason: 'While a restore is on its way, the entry shows a spinner.',
      );
      expect(
        lines(),
        [texts.title],
        reason: 'While a restore is on its way, the entry shows no result of '
            'an earlier restore, which the user would take for the answer to '
            'this tap, and a screen reader then reads the answer to this tap '
            'when it comes, also when it is the same as before.',
      );
      await inRealTime(tester, 'a second tap on the entry', () async {
        await tester.tap(entry);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await inRealTime(tester, 'the end of the restore', () async {
        held.complete();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(
        scripted.calls.sublist(beforeHeld),
        ['restore'],
        reason: 'A second tap while a restore is on its way restores nothing '
            'more: the entry takes no other tap until the restore ends.',
      );
      expect(
        spinner,
        findsNothing,
        reason: 'Once the restore ends, the entry shows no spinner.',
      );
      expect(
        lines(),
        unorderedEquals([texts.title, texts.active]),
        reason: 'Once the restore ends, the entry shows what it found.',
      );

      // A restore that fails, for each reason of a failure: the entry shows
      // the same text for each, since the user can only try again.
      for (final reason in PurchasesFailureReason.values) {
        final hint = 'What the provider says of ${reason.name}.';
        service.restoreError = PurchasesFailure(reason, developerHint: hint);
        expect(
          await tap(),
          ['restore'],
          reason: 'A tap on the entry restores, once.',
        );
        expect(
          lines(),
          unorderedEquals([texts.title, texts.failed, hint]),
          reason: 'A restore that fails with ${reason.name} shows that it '
              'failed, and in debug mode, which the tests run in, the words '
              'of the provider for the developer of the app.',
        );
      }
      service.restoreError = const PurchasesFailure(
        PurchasesFailureReason.network,
      );
      await tap();
      expect(
        lines(),
        unorderedEquals([texts.title, texts.failed]),
        reason: 'A failure without the words of the provider shows only that '
            'the restore failed.',
      );
      final error = StateError('The store went away.');
      service.restoreError = error;
      await tap();
      expect(
        lines(),
        unorderedEquals([texts.title, texts.failed, '$error']),
        reason: 'appPurchases turns an error of another kind into a failure '
            'with the error as the words of the provider, which the entry '
            'shows as any failure.',
      );
      const longHint = 'Purchases are not set up: give the provider what it '
          'needs, as https://example.com/a/long/address/without/a/space/in-it '
          'explains.';
      service.restoreError = const PurchasesFailure(
        PurchasesFailureReason.notConfigured,
        developerHint: longHint,
      );
      await tap();
      await inEachLanguage(
        (texts) => [texts.title, texts.failed, longHint],
        'that the restore failed, with the words of the provider,',
      );

      // The list of the screen that holds the entry, the nearest scrollable
      // above it on the tall surface, where the screen builds every row. On
      // the small phone below, a screen that builds its rows only as they
      // come into view may build none for the entry until this list
      // scrolls to it.
      final listOfEntry = find
          .ancestor(of: entry, matching: find.byType(Scrollable))
          .evaluate()
          .first;
      final list = find.byElementPredicate(
        (element) => element == listOfEntry,
        description: 'the list of the entry that restores purchases',
      );

      // A small phone with the text at three times its size, about the
      // largest that the settings of a device have.
      tester.view.physicalSize = const Size(320, 480);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The settings screen with the entry that restores purchases '
            'fits a small phone with a large text size.',
      );
      for (final MapEntry(key: code, value: texts) in restoreTexts.entries) {
        tester.platformDispatcher.localesTestValue = [Locale(code)];
        await tester.pumpAndSettle();
        // The list scrolls until the entry is in view, as a user scrolls to
        // it: the large title and the entries above it may have moved it
        // below the end of the screen.
        await tester.scrollUntilVisible(entry, 100, scrollable: list);
        await tester.pumpAndSettle();
        expect(
          lines(),
          unorderedEquals([texts.title, texts.failed, longHint]),
          reason: 'The entry shows its title and the failure on a small phone '
              'with a large text size, in $code.',
        );
        final row = tester.getRect(entry);
        final title = tester.getRect(
          find.descendant(of: entry, matching: find.text(texts.title)),
        );
        for (final text in find
            .descendant(of: entry, matching: find.byType(Text))
            .evaluate()) {
          final shown = find.byElementPredicate(
            (element) => element == text,
            description: 'a text of the entry',
          );
          final box = tester.getRect(shown);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: shown,
              matching: find.byType(RichText),
              matchRoot: true,
            ),
          );
          final content = (text.widget as Text).data;
          expect(
            (box.left >= row.left, box.right <= row.right),
            (true, true),
            reason: 'The texts of the entry stay in its row on a small phone '
                'with a large text size, in $code: "$content" is at $box in '
                'the row at $row.',
          );
          expect(
            (
              paragraph.didExceedMaxLines,
              paragraph.size.height < paragraph.textSize.height,
            ),
            (false, false),
            reason: 'The entry shows "$content" in full, on as many lines as '
                'it needs, on a small phone with a large text size, in '
                '$code.',
          );
          if (content != texts.title) {
            expect(
              box.top,
              greaterThanOrEqualTo(title.bottom),
              reason: 'At a large text size, what the restore found is below '
                  'the title of the entry, where it has the width of the row, '
                  'in $code: "$content" is at $box, and the title at $title.',
            );
          }
        }
      }
      expect(
        tester.takeException(),
        isNull,
        reason: 'The entry fits a small phone with a large text size in each '
            'language of the app.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
