// What the tests of bottom_tabs share: the bar that its AppShell draws at
// the bottom of the main navigation, and the tabs of the bar. The classes
// of the bar are private to the file of the layout, so the tests find the
// bar where the layout puts it: in the Scaffold of the AppShell, as its
// bottomNavigationBar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/layout/app_shell.dart';

/// What the Scaffold of the AppShell has as its bottomNavigationBar, or
/// `null` when it has none.
Widget? barWidget(WidgetTester tester) => tester
    .widget<Scaffold>(
      find
          .descendant(
            of: find.byType(AppShell),
            matching: find.byType(Scaffold),
          )
          .first,
    )
    .bottomNavigationBar;

/// The bar at the bottom of the main navigation.
Finder bar(WidgetTester tester) => find.byWidget(barWidget(tester)!);

/// The text of the tab that shows [label] in the bar.
Finder tab(WidgetTester tester, String label) =>
    find.descendant(of: bar(tester), matching: find.text(label));

/// The icon of the tab of the destination with [icon] in the bar.
Finder tabIcon(WidgetTester tester, IconData icon) =>
    find.descendant(of: bar(tester), matching: find.byIcon(icon));
