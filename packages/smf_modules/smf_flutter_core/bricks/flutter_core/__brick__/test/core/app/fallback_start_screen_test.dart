import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/app/fallback_start_screen.dart';

/// The path that the screen names.
const _file = 'lib/core/app/fallback_start_screen.dart';

/// Shows what the fallback start screen shows, with texts of the test: the
/// screen itself reads them from the texts of the app, where the app has
/// them.
Future<void> _show(WidgetTester tester) => tester.pumpWidget(
  const MaterialApp(
    home: FallbackStartView(hint: 'A hint', copied: 'Copied'),
  ),
);

/// How much of the view is shown while it comes in, from 0 to 1.
double _shown(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(_file), matching: find.byType(Opacity)),
    )
    .opacity;

void main() {
  testWidgets('names the app, and tells where its first screen goes', (
    tester,
  ) async {
    await _show(tester);
    // It comes in with a short fade.
    expect(_shown(tester), 0);
    await tester.pumpAndSettle();
    expect(_shown(tester), 1);

    // The cell of the app is a picture, which a screen reader passes over,
    // so only the name of the app has this label.
    expect(find.bySemanticsLabel('{{app_number}}'), findsNothing);
    final name = find.bySemanticsLabel('{{app_name.titleCase()}}');
    expect(tester.getSemantics(name), isSemantics(isHeader: true));
    expect(find.text('A hint'), findsOneWidget);
    expect(
      tester.getSemantics(find.text(_file)),
      isSemantics(isButton: true, hasTapAction: true),
    );
  });

  testWidgets('copies the path of its file on a tap, and says so', (
    tester,
  ) async {
    final copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _show(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text(_file));
    await tester.pumpAndSettle();

    expect(copied, [
      {'text': _file},
    ]);
    expect(find.text('Copied: $_file'), findsOneWidget);
  });

  testWidgets('fits a small phone with the largest text, and comes in at '
      'once when the device asks for less motion', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 480)
      ..devicePixelRatio = 1;
    tester.platformDispatcher
      ..textScaleFactorTestValue = 3
      ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    // A widget that does not fit fails the test.
    await _show(tester);

    expect(_shown(tester), 1);
    TextScaler scalerOf(Finder text) =>
        MediaQuery.textScalerOf(tester.element(text));
    // The letters of the cell are a part of the picture and keep their
    // size, and the path grows less than the other texts.
    expect(scalerOf(find.text('{{app_symbol}}').first), TextScaler.noScaling);
    expect(scalerOf(find.text(_file)).scale(10), 15);
    expect(scalerOf(find.text('A hint')).scale(10), 30);
  });
}
