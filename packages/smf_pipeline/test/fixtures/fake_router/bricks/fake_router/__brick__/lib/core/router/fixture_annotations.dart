import 'package:meta/meta_meta.dart';

/// Marks the class of a screen; the analyzer rejects it anywhere else, so
/// a misplaced tag of the screen annotations does not compile cleanly.
@Target({TargetKind.classType})
final class FixtureScreen {
  /// Marks the screen of the route [route].
  const FixtureScreen(this.route);

  /// The full name of the route.
  final String route;
}

/// Marks a parameter of the constructor of a screen; the analyzer rejects
/// it anywhere else.
@Target({TargetKind.parameter})
final class FixtureParam {
  /// Marks the parameter [name].
  const FixtureParam(this.name);

  /// The name of the parameter of the route.
  final String name;
}
