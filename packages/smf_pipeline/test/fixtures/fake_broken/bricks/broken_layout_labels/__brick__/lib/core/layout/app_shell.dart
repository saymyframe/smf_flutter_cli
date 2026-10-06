import 'package:flutter/material.dart';

import 'destination.dart';

/// The main navigation of the app, with a known bug (fixture): a bar at the
/// bottom with a tab for each destination, below the screen of the selected
/// one, but each tab keeps the label that its destination had when the bar
/// was first built, whatever language the app is in later.
class AppShell extends StatefulWidget {
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
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// The labels of the destinations as they read when the bar was first
  /// built: the bug of this layout, which reads each label once.
  List<String>? _labels;

  @override
  Widget build(BuildContext context) {
    final labels = _labels ??= [
      for (final destination in widget.destinations) destination.label(context),
    ];
    return Scaffold(
      body: widget.body,
      bottomNavigationBar: widget.destinations.length < 2
          ? null
          : NavigationBar(
              selectedIndex: widget.currentIndex,
              onDestinationSelected: widget.onSelect,
              destinations: [
                for (final (index, destination) in widget.destinations.indexed)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    label: labels[index],
                  ),
              ],
            ),
    );
  }
}
