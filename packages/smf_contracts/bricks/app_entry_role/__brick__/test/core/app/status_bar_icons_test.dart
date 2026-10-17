import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/app/status_bar_icons.dart';

/// What the widget asks the system for on a screen in [theme].
Future<SystemUiOverlayStyle> _styleIn(
  WidgetTester tester,
  ThemeData theme,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const StatusBarIcons(child: Text('A screen')),
    ),
  );
  return tester
      .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(StatusBarIcons),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      )
      .value;
}

void main() {
  testWidgets('asks for dark icons on a light theme', (tester) async {
    final style = await _styleIn(tester, ThemeData());

    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.statusBarBrightness, Brightness.light);
    expect(find.text('A screen'), findsOneWidget);
  });

  testWidgets('asks for light icons on a dark theme', (tester) async {
    final style = await _styleIn(
      tester,
      ThemeData(brightness: Brightness.dark),
    );

    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
  });

  testWidgets('leaves the navigation bar of the system as it is', (
    tester,
  ) async {
    final style = await _styleIn(tester, ThemeData());

    expect(style.systemNavigationBarColor, isNull);
    expect(style.systemNavigationBarIconBrightness, isNull);
  });
}
