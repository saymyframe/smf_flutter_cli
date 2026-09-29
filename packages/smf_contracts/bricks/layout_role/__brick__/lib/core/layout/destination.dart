import 'package:flutter/widgets.dart';

/// An item of the main navigation of the app, such as a tab of a bottom bar.
final class Destination {
  /// Creates an item labelled [label] with [icon].
  const Destination({required this.label, required this.icon});

  /// The text of the item.
  final String label;

  /// The icon of the item.
  final IconData icon;
}
