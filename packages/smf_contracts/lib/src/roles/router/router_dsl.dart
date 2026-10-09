part of '../router.dart';

/// The routes a module adds to the app: the data of the [RouterRole].
///
/// A feature contributes it with `routerRole.data(RoutesData([...]))`. The
/// router puts the routes of a module under the module's namespace, the
/// path `/<module id>`: the route `/` of the module `home` is `/home`, and
/// its route `/settings` is `/home/settings`.
@immutable
final class RoutesData implements DataWithTexts {
  /// Creates the data with the top-level [routes] of a module and its
  /// [guards].
  const RoutesData(this.routes, {this.guards = const []});

  /// The top-level routes of the module, in the order the app lists them.
  ///
  /// A router matches a location against the routes in this order, each
  /// followed by its children, and the first route that matches the whole
  /// location takes it. So a route with a fixed segment, such as `/new`,
  /// comes before a route with a parameter in its place, such as `/:id`,
  /// which would take its locations otherwise. In an app with a main
  /// navigation, the router matches the destinations first, each followed
  /// by the routes below it, and then the other routes, so a route below a
  /// destination must not take every location of a route outside the main
  /// navigation either. The module rule `router.routes` reports a route
  /// that another leaves unreachable in either order.
  final List<Route> routes;

  /// The guards of the module; see [RouteGuard].
  ///
  /// The app asks the guards of all modules by their [RouteGuard.stage],
  /// and those of one stage in the order of the modules and of this list.
  final List<RouteGuard> guards;

  /// The texts of the routes that a user sees: the labels of their
  /// destinations of the main navigation (see [Destination.label]).
  @override
  Iterable<LocalizedText> get shownTexts => [
        for (final route in routes)
          if (route.destination case final destination?) destination.label,
      ];
}

/// When the app asks a guard of the routes among its guards: it asks the
/// guards of an earlier stage first, whatever the order of their modules,
/// and the first guard that does not allow decides (see [RouteGuard]).
///
/// The stages come in the order of a first launch: the user goes through
/// the flow of a [welcome] guard, and once that guard allows, through the
/// flow of an [identity] guard. The app asks two guards of one stage in the
/// order of their modules, and two guards of one module in the order of
/// [RoutesData.guards].
///
/// A module cannot add a stage. A guard that is neither of the two takes
/// the stage that its flow belongs to: [welcome] if the flow needs to know
/// nothing of the user, as a consent or a required update does, and
/// [identity] if it needs to know who the user is, as a subscription does.
/// The order of the modules then says where it comes among the guards of
/// that stage.
enum GuardStage {
  /// Before the app asks who the user is: what a new user goes through on
  /// the first launch, such as an onboarding.
  welcome,

  /// Who the user is, such as a sign-in.
  identity,
}

/// A gate over the whole app: a condition without which the user sees a
/// route of the module in place of every other screen of the app, such as
/// the onboarding until the user went through it.
///
/// While the guard does not allow, the router shows the route [redirectTo]
/// of the module, the target of the guard, in place of every location
/// outside its flow: the target and the routes below it. That holds for the
/// location the app starts on, for every location that `go()`, `push()` or
/// `replace()` is asked to show, and for the routes of every module, which
/// know nothing of the guard. Once the guard allows, the router shows the
/// location that the user or the platform last asked for and the guards
/// kept them from, or the location that the guard took the user from when
/// it stopped allowing, if it [resumes], or else the screen that the app
/// starts on. So the screens of the flow only change what the guard reads:
/// the router leaves the flow. See [RouterRole.guardedNavigation] for what
/// every router does with the guards.
///
/// The routes of the flow show only until the flow is over, which it is
/// once the guard allows, and so does every other guard of the module with
/// the same target. The router then shows the screen that the app starts
/// on in place of a location of the flow, or the target of another guard
/// while that one does not allow, whether `go()`, `push()`, `replace()` or
/// the platform asks for it, and such a `push()` completes with `null`. So
/// no code navigates into a flow, the module of the guard included: it
/// changes what the guard reads, and the router shows the target.
///
/// A guard may stop allowing while the app runs, by what the screens of
/// its own module do too: the router then shows its target in place of the
/// screen that the user is on. Where the user comes to once the guard
/// allows again is up to [resumes]. By default the router remembers the
/// location that the guard takes the user from and shows it again, as
/// after an onboarding that the user asked to see once more. A guard with
/// [resumes] `false` makes the router remember nothing then, so the user
/// comes to the screen that the app starts on: after a sign-out, the next
/// user does not come to the screen that the last one was on. Either way,
/// the router shows a location that is asked for while the guard does not
/// allow, such as a link, once the guard allows.
///
/// A guard keeps the user from every route outside its flow. A condition
/// that only some routes ask for, such as a paid screen, is not a guard:
/// the role has nothing for it.
///
/// The app asks the guards of all modules by their [stage], those of an
/// earlier stage first, whatever the order of the modules: the guard of an
/// onboarding comes before the guard of a sign-in. It asks the guards of
/// one stage in the order of the modules and of [RoutesData.guards]. The
/// first guard that does not allow decides, and no later one is asked, so
/// the flows of the guards show one after another.
///
/// ```dart
/// RoutesData(
///   [Route('/', name: 'intro', screen: ScreenRef('IntroScreen', ...))],
///   guards: [
///     RouteGuard(
///       name: 'firstRun',
///       allows: FunctionRef(
///         'introSeen',
///         import: ImportRef.app('features/intro/intro_status.dart'),
///       ),
///       redirectTo: 'intro',
///       stage: GuardStage.welcome,
///     ),
///   ],
/// )
/// ```
@immutable
final class RouteGuard {
  /// Creates the guard [name] of the stage [stage], which shows the route
  /// [redirectTo] of its module until [allows] says otherwise.
  const RouteGuard({
    required this.name,
    required this.allows,
    required this.redirectTo,
    required this.stage,
    this.resumes = true,
  });

  /// The name of the guard in its module, a lowerCamelCase identifier such
  /// as `firstRun`; the full name is `<module id>.<name>`.
  final String name;

  /// A top-level function of a file of the app, without parameters, that
  /// returns a `ValueListenable<bool>` of `package:flutter/foundation.dart`:
  /// whether the guard allows, which notifies its listeners when that
  /// changes.
  ///
  /// The app calls the function once, when its router first asks the
  /// guards, which is after `bootstrap()`, and then reads the value whenever
  /// it asks the guard. So the value is known without waiting: a guard that
  /// depends on something that loads, such as a setting on the device,
  /// loads it in `bootstrap()`. The value changes outside the build of a
  /// frame, such as in the handler of a tap, since the router navigates
  /// when it does.
  ///
  /// The router role imports the file with a prefix of its own, so
  /// [ImportRef.prefix] and [ImportRef.show] do not apply. A feature whose
  /// guard needs a service keeps the function in its composition file,
  /// which may resolve services (see [CompositionFile]).
  final FunctionRef allows;

  /// The name of the route of the module that the router shows while the
  /// guard does not allow, such as `intro`: its target.
  ///
  /// It is a top-level route that needs no values and is outside the main
  /// navigation. Neither it nor a route below it can start the app.
  final String redirectTo;

  /// When the app asks the guard among its guards: before every guard of a
  /// later stage, whichever module declares it; see [GuardStage].
  final GuardStage stage;

  /// Whether the router brings the user back to the location that the
  /// guard takes them from when it stops allowing, once it allows again.
  ///
  /// With `false`, the router remembers nothing when the guard stops
  /// allowing, and the user comes to the screen that the app starts on
  /// once it allows again, as the next user does after a sign-out. A
  /// location that is asked for while the guard does not allow is
  /// remembered then too, so the user still comes to a link that arrived
  /// meanwhile. And what the router remembers already stays: the location
  /// that an earlier guard kept the user from is shown once this guard
  /// allows.
  final bool resumes;

  @override
  String toString() => 'guard $name';
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
///
/// ```dart
/// static const _label = LocalizedText(
///   'label',
///   en: 'Home',
///   translations: {'uk': 'Головна'},
/// );
///
/// // The descriptor of the module has uses: {localizationRole}.
/// localizationRole.data(const TextsData([_label])),
/// routerRole.data(
///   const RoutesData([
///     Route(
///       '/',
///       name: 'home',
///       screen: ScreenRef('HomeScreen', ...),
///       destination: Destination(
///         label: _label,
///         icon: Fragment('Icons.home', imports: [...]),
///       ),
///     ),
///   ]),
/// ),
/// ```
@immutable
final class Destination {
  /// Creates a destination labelled [label] with [icon].
  const Destination({required this.label, required this.icon});

  /// The text of the item, such as `Home`, which the app shows in its
  /// language.
  ///
  /// It is a text of the module. A module that lists the [LocalizationRole]
  /// among its roles gives that role the same text, among its [TextsData]:
  /// in an app with that role the label then reads from the texts of the
  /// app, in the language of the app, and in an app without it the label
  /// is the English text. The rule `localization.texts` reports a label
  /// that such a module did not give the role.
  ///
  /// A module that does not list the role gives the label its English text
  /// alone, which every app shows: the rule `router.routes` reports a
  /// translation there, which no app would show.
  final LocalizedText label;

  /// A constant expression of type `IconData`, such as `Icons.home`, with
  /// the imports it needs.
  ///
  /// The layout role creates the destinations as constants, so a release
  /// build can tree-shake the icon fonts.
  final Fragment icon;
}
