import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/app/fallback_start_screen.dart';

void main() {
  testWidgets('the fallback start screen shows the name of the app', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FallbackStartScreen()));

    expect(find.text('{{app_name.titleCase()}}'), findsOneWidget);
  });
}
