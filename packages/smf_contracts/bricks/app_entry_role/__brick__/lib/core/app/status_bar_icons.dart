import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks the system for the icons of the status bar that suit the theme,
/// around [child]: dark icons on a light theme, light ones on a dark theme.
///
/// The root of the app puts it around the content of every route, below
/// the `MaterialApp` whose theme it reads. It leaves the navigation bar of
/// the system as the platform has it. A screen with an `AppBar` gets the
/// icons that suit its bar, since the bar tells them for the top of the
/// screen itself.
class StatusBarIcons extends StatelessWidget {
  /// Creates the widget around [child].
  const StatusBarIcons({required this.child, super.key});

  /// What the icons suit: the content of a route.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // iOS takes the brightness of the bar, and Android that of its icons.
      value: SystemUiOverlayStyle(
        statusBarBrightness: brightness,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: child,
    );
  }
}
