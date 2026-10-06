import 'package:flutter/widgets.dart';

/// An item of the main navigation of the app, such as a tab of a bottom bar.
final class Destination {
  /// Creates an item with [label] and [icon].
  const Destination({required this.label, required this.icon});

  /// Returns the text of the item in the language of the app, for the
  /// context of the widget that shows it. That widget calls it each time it
  /// builds, so the text follows the language of the app.
  final String Function(BuildContext context) label;

  /// The icon of the item.
  final IconData icon;
}

/// The destinations of the main navigation, in the order in which the
/// router has their branches.
const List<Destination> appDestinations = [
{{{destinations}}}
];
{{{labels}}}
