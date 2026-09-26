part of '../router.dart';

/// The routes a module adds to the app: the data of the [RouterRole].
///
/// A feature contributes it with `routerRole.data(RoutesData([...]))`. The
/// router puts the routes of a module under the module's namespace, the
/// path `/<module id>`: the route `/` of the module `home` is `/home`, and
/// its route `/settings` is `/home/settings`.
@immutable
final class RoutesData {
  /// Creates the data with the top-level [routes] of a module.
  const RoutesData(this.routes);

  /// The top-level routes of the module, in the order the app lists them.
  ///
  /// A router matches a location against the routes in this order, each
  /// followed by its children, and the first route that matches the whole
  /// location takes it. So a route with a fixed segment, such as `/new`,
  /// comes before a route with a parameter in its place, such as `/:id`,
  /// which would take its locations otherwise; the module rule
  /// `router.routes` reports a route that an earlier one leaves unreachable.
  final List<Route> routes;
}

/// A page of the app: where it is, the screen it shows and the values it
/// takes from its location.
///
/// Its full path and name come from the module that declares it (see
/// [RoutesData]); the navigation facade offers it as
/// `context.nav.<module>.<name>(...)`.
@immutable
final class Route {
  /// Creates the route at [path] that shows [screen].
  const Route(
    this.path, {
    required this.name,
    required this.screen,
    this.params = const [],
    this.children = const [],
    this.destination,
    this.startCandidate = false,
  });

  /// The path of the route relative to its parent.
  ///
  /// A top-level route starts with `/` and is relative to the namespace of
  /// its module, such as `/` or `/settings`. A child has no leading `/` and
  /// is relative to its parent, such as `details/:id`. A segment is
  /// lowercase letters, digits, `-` and `_`, or `:<name>` for the path
  /// parameter `<name>` that [params] declares.
  final String path;

  /// The name of the route in its module, a lowerCamelCase identifier such
  /// as `details`; the full name is `<module id>.<name>`.
  final String name;

  /// The screen the route shows.
  final ScreenRef screen;

  /// The values the route takes from its location: the parameters of the
  /// `:<name>` segments of [path] and of the query.
  ///
  /// The unnamed constructor of [screen] takes each of them as a named
  /// parameter of the same name, which is nullable for an optional one. The
  /// path parameters of the parents are part of the location; a child also
  /// passes one to its screen by listing it here with the parent's type. No
  /// other parameter may repeat the name of a parameter of a parent, because
  /// all pages of a location share its query.
  final List<RouteParam> params;

  /// Pages shown on top of this one: going back from a child returns to
  /// this route.
  ///
  /// Navigating to a child rebuilds its parents with their path parameters
  /// only, so a route with children takes no required query parameters.
  final List<Route> children;

  /// How the route appears in the main navigation of the app, such as a
  /// tab, or `null` to keep it out.
  ///
  /// Only a top-level route without required parameters can be a
  /// destination: selecting it has no values to give. Its children stay in
  /// the destination's branch; the other top-level routes are shown over the
  /// main navigation, and going to one of them leaves the main navigation.
  final Destination? destination;

  /// Whether the app can start on this route; see the `--start` option of
  /// the router. Such a route takes no required parameters.
  final bool startCandidate;
}

/// Where the value of a [RouteParam] comes from.
enum RouteParamSource {
  /// A `:<name>` segment of the path; a path parameter is always required.
  path,

  /// The query of the location, such as `q` in `/search?q=dart`.
  query,
}

/// A value that a route takes from its location and passes to its screen.
@immutable
final class RouteParam {
  /// Declares the path parameter [name] of the segment `:<name>`.
  const RouteParam.path(this.name, {required this.type})
      : source = RouteParamSource.path,
        optional = false;

  /// Declares the query parameter [name]; set [optional] if the location
  /// may leave it out.
  const RouteParam.query(this.name, {required this.type, this.optional = false})
      : source = RouteParamSource.query;

  /// The name of the parameter, a lowerCamelCase identifier such as `id`.
  ///
  /// It is the name of the path segment or query key, of the screen's
  /// constructor parameter and of the parameter of the navigation facade.
  final String name;

  /// The Dart type of the value: [String], [int], [double] or [bool].
  final Type type;

  /// Where the value comes from.
  final RouteParamSource source;

  /// Whether the location may leave the value out, so the screen gets
  /// `null`.
  final bool optional;

  /// Whether the location must have the value.
  bool get isRequired => !optional;

  /// The name of [type] in Dart code, such as `int`, or `null` for a type
  /// the router does not support.
  String? get typeName {
    if (type == String) return 'String';
    if (type == int) return 'int';
    if (type == double) return 'double';
    if (type == bool) return 'bool';
    return null;
  }

  @override
  String toString() => source == RouteParamSource.path ? ':$name' : '?$name';
}

/// The screen a [Route] shows: a widget class of the generated app.
@immutable
final class ScreenRef {
  /// Refers to the widget class [className] declared in the file of
  /// [import], a file of the app such as
  /// `ImportRef.app('features/home/home_screen.dart')`.
  const ScreenRef(this.className, {required this.import});

  /// The name of the widget class, such as `HomeScreen`.
  final String className;

  /// The import of the file that declares the class.
  ///
  /// Routers import screens with a prefix of their own, so [ImportRef.prefix]
  /// and [ImportRef.show] do not apply.
  final ImportRef import;

  /// The path of the file relative to the project root, such as
  /// `lib/features/home/home_screen.dart`, or `null` if [import] is not a
  /// file of the app.
  String? get file => import.isAppFile ? 'lib/${import.uri}' : null;

  @override
  String toString() => className;
}

/// How a top-level route appears in the main navigation of the app, such as
/// a tab of a bottom bar.
///
/// The layout role shows the destinations of all features in the order of
/// the features; see [LayoutRole].
@immutable
final class Destination {
  /// Creates a destination labelled [label] with [icon].
  const Destination({required this.label, required this.icon});

  /// The text of the item, such as `Home`.
  final String label;

  /// A constant expression of type `IconData`, such as `Icons.home`, with
  /// the imports it needs.
  ///
  /// Routers create the destinations as constants, so a release build can
  /// tree-shake the icon fonts.
  final Fragment icon;
}
