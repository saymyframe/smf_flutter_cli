import 'package:smf_contracts/smf_contracts.dart';

/// The widget a route builds and the route parameters passed to it.
class RouteScreen {
  /// Creates a screen built from the widget class [className].
  const RouteScreen(this.className, {this.screenArguments = const []});

  /// Name of the widget class, for example `'HomeScreen'`.
  ///
  /// The generated router constructs it directly, so add the import of its
  /// file to the route's [BaseRoute.imports].
  final String className;

  /// Constructor arguments filled from the route's parameters, in the order
  /// they are passed.
  final List<RouteScreenArgs> screenArguments;
}
