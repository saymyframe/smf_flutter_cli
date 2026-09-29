import 'package:flutter/material.dart';

import 'destination.dart';

/// The main navigation of the app: a bar at the bottom with a tab for each
/// destination, below the screen of the selected one.
///
/// With one destination there is nothing to switch to, so the bar is
/// hidden and the screen fills the app.
class AppShell extends StatelessWidget {
  /// Creates the main navigation with [destinations], the one at
  /// [currentIndex] selected with [body] as its screen; selecting a tab
  /// calls [onSelect] with its index.
  const AppShell({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.body,
    super.key,
  });

  /// The tabs of the bar, in order.
  final List<Destination> destinations;

  /// The index of the selected destination.
  final int currentIndex;

  /// Selects the destination at the given index.
  final ValueChanged<int> onSelect;

  /// The screen of the selected destination.
  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: body,
    bottomNavigationBar: destinations.length < 2
        ? null
        : NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onSelect,
            destinations: [
              for (final destination in destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  label: destination.label,
                ),
            ],
          ),
  );
}
