import 'package:flutter/material.dart';

import 'destination.dart';

/// The main navigation of the app, with a known bug (fixture): a bar at the
/// bottom with a tab for each destination, below the screen of the selected
/// one, but [destinations] give only the first destination.
class AppShell extends StatelessWidget {
  /// Creates the main navigation with [destinations], the one at
  /// [currentIndex] selected with [body] as its screen; selecting a tab
  /// calls [onSelect] with its index.
  const AppShell({
    required List<Destination> destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.body,
    super.key,
  }) : _tabs = destinations;

  /// A tab of the bar for each destination.
  final List<Destination> _tabs;

  /// The destinations of the main navigation, as code that knows only the
  /// layout role reads them: only the first, the bug of this layout.
  List<Destination> get destinations => _tabs.take(1).toList();

  /// The index of the selected destination.
  final int currentIndex;

  /// Selects the destination at the given index.
  final ValueChanged<int> onSelect;

  /// The screen of the selected destination.
  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: body,
        bottomNavigationBar: _tabs.length < 2
            ? null
            : NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: onSelect,
                destinations: [
                  for (final destination in _tabs)
                    NavigationDestination(
                      icon: Icon(destination.icon),
                      label: destination.label(context),
                    ),
                ],
              ),
      );
}
