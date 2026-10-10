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
  /// The app asks the gates of all modules first, the guards without a
  /// [RouteGuard.condition], and then the guards that stand for a
  /// condition. It asks the guards of each kind by their
  /// [RouteGuard.stage], and those of one stage in the order of the modules
  /// and of this list.
  final List<RouteGuard> guards;

  /// The texts of the routes that a user sees: the labels of their
  /// destinations of the main navigation (see [Destination.label]).
  @override
  Iterable<LocalizedText> get shownTexts => [
        for (final route in routes)
          if (route.destination case final destination?) destination.label,
      ];
}

/// When the app asks a guard of the routes among the guards of its kind,
/// the gates or the guards of conditions (see [RouteGuard.condition]): it
/// asks the guards of an earlier stage first, whatever the order of their
/// modules, and the first guard that does not allow decides (see
/// [RouteGuard]).
///
/// The stages come in the order of a first launch: the user goes through
/// the flow of a [welcome] guard, and once that guard allows, through the
/// flow of an [identity] guard. The app asks two guards of one stage in the
/// order of their modules, and those of one module in the order of its
/// [RoutesData.guards].
///
/// A module cannot add a stage. A guard that is neither of the two takes
/// the stage that its flow belongs to: [welcome] if the flow needs to know
/// nothing of the user, as that of a consent or of a required update, and
/// [identity] if it needs to know who the user is, as that of a
/// subscription. The order of the modules then says where it comes among
/// the guards of that stage, so the app may ask such a guard before the
/// guard that asks who the user is. It therefore allows while it cannot
/// tell who the user is: the guard that asks who the user is then decides,
/// and this one once the user is known.
enum GuardStage {
  /// Before the app asks who the user is: what a new user goes through on
  /// the first launch, such as an onboarding.
  welcome,

  /// What asks who the user is, such as a sign-in.
  identity,
}

/// Something that a user needs for some routes of the app only, such as an
/// account for an account screen, as a role names it.
///
/// The role that knows what the condition is publishes it as a constant of
/// its class, such as `static const account = RouteCondition(authRole,
/// 'account')`. Two modules then meet through the role, and neither knows
/// the other:
/// - a feature asks for the condition on a route ([Route.conditions]). It
///   lists the role among its roles, and knows no module with a guard;
/// - a module that requires or provides the role stands for the condition
///   with a guard ([RouteGuard.condition]). The function of the guard says
///   whether the condition holds, and its target is the route that the
///   router opens over the page that the user is on when a route that asks
///   for it is asked for before it does.
///
/// An app may have no guard that stands for a condition: it lacks the role,
/// or it has no module with such a guard. The routes that ask for the
/// condition then show like any other, and the router role reports
/// nothing. Whether such an app is worth a warning is up to the role of
/// the condition, whose hooks see the guards of the app if it requires or
/// uses the router role ([RouterFacade.guardFor]).
@immutable
final class RouteCondition {
  /// Creates the condition [name] of [role].
  const RouteCondition(this.role, this.name);

  /// The role that publishes the condition.
  final Role role;

  /// The name of the condition in its role, such as `account`. Messages
  /// name the condition `<role id>.<name>`, and no code of an app has the
  /// name.
  final String name;

  /// Two conditions are the same if they have one role and one name.
  @override
  bool operator ==(Object other) =>
      other is RouteCondition &&
      identical(other.role, role) &&
      other.name == name;

  @override
  int get hashCode => Object.hash(role, name);

  @override
  String toString() => '${role.id}.$name';
}

/// Something that the user needs before the app shows some of its screens,
/// with a route of the module to show until then. A guard without a
/// [condition] is a gate over the whole app: until it allows, the user sees
/// a route of the module in place of every other screen of the app, such as
/// the onboarding until the user went through it. A guard with a
/// [condition] keeps the user only from the routes that ask for that
/// condition; see below.
///
/// While a gate does not allow, the router shows the route [redirectTo]
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
/// on in place of a location of the flow, or the target of a gate while
/// that one does not allow, whether `go()`, `push()`, `replace()` or the
/// platform asks for it, and such a `push()` completes with `null`. So no
/// code navigates into the flow of a gate, the module of the guard
/// included: it changes what the guard reads, and the router shows the
/// target. That holds unless a guard with a [condition] has the same flow:
/// while that one does not allow and the gate does, the flow is not over,
/// and its routes show like any other.
///
/// A guard may stop allowing while the app runs, by what the screens of
/// its own module do too: the router then shows its target in place of the
/// screen that the user is on. Where the user comes to once the guard
/// allows again is up to [resumes]. By default the router remembers the
/// location that the guard takes the user from and shows it again, as
/// after an onboarding that the user asked to see once more. When a guard
/// with [resumes] `false` stops allowing, the router remembers no location
/// for it and forgets what it remembered, for another guard too. So the
/// user comes to the screen that the app starts on: after a sign-out, the
/// next user comes neither to the screen that the last one was on nor to a
/// link that the last one followed. Either way, the router shows a
/// location that is asked for after that, while the guard does not allow,
/// once the guards allow.
///
/// A guard with a [condition] keeps the user from the routes that ask for
/// the condition ([Route.conditions]), of whichever module, and from no
/// other: a screen for users with an account is such a route, and the
/// rest of the app shows to a user without one. While the condition does
/// not hold, a request for such a route opens the target of the guard over
/// the page that the user is on, and the request waits:
/// - back from the target returns to that page, and the request is
///   dropped: a `push()` completes with `null`;
/// - once the condition holds, the router closes the pages of the flow and
///   does what was asked. `push()` shows the route over the page that the
///   user was on and completes with the value of its page, `go()` shows it
///   in place of the stack, and `replace()` in place of that page;
/// - a location from the platform, or one that is asked for before the
///   app has a page, opens the target over the screen that the app starts
///   on, and shows as `go()` to it does once the condition holds;
/// - a further request for a route that asks for the condition does
///   nothing while a page of the flow is open, and the first one waits;
/// - when a gate stops allowing meanwhile, its target takes the place of
///   the stack, and the request is dropped with the pages of the flow. If
///   that target is a page of the same flow, the request is dropped once
///   the target leaves;
/// - when the page that the request was made on closes below the flow, as
///   one that asks for another condition, which stopped holding, the flow
///   closes with it and the request is dropped.
///
/// A known limit: behind a gate that does not allow, the router remembers
/// such a location for the gate, as it does any other, and opens no flow.
/// Once the gate allows while the condition does not hold, the user comes
/// to the screen that the app starts on, and the location is lost. So a
/// link to such a route that opens the app on a first launch, behind an
/// onboarding, does not open the target of the guard, which it does in an
/// app whose gates allow.
///
/// When the condition stops holding, the router closes each page that asks
/// for it, with the pages over it, so the user is on the page that it was
/// opened from. A page that asks for it and has no page below it, as after
/// `go()` to it, leaves for the screen that the app starts on.
///
/// So a screen never closes itself, and never navigates, after it changed
/// what a guard reads: the router has done both by then. That goes for a
/// screen of a flow that made its guard allow, as after a sign-in, and for
/// a page that asks for a condition and ends it itself, as a screen of an
/// account does with its sign-out. A `pop()` after the change closes the
/// page that is on top by then. After a sign-in that is the page that the
/// user asked for, and a `push()` that waited for it completes with `null`.
/// After a sign-out it is the page below the one that the router closed,
/// which may be the main navigation of the app. Only in the turn of the
/// change itself, before the next frame, does such a `pop()` still close
/// the page that the router closed. A `go()` after the change takes the
/// place of what the router showed.
///
/// The flow of such a guard is its target and the routes below it too, and
/// it is over once the guard allows. Until then every route shows that
/// does not ask for the condition, the routes of the flow among them: a
/// module may navigate to the target of its guard while the condition does
/// not hold, as to a sign-in screen that a guest opens. With `push()` the
/// user can go back from it, and once the condition holds the router
/// closes it as it closes a target that it opened itself. The screens of
/// the flow move between its routes with `push()` or `replace()`, which
/// keep the request waiting; `go()` takes the place of the page that the
/// flow was opened over, and the request goes with it. A guard with a
/// condition may show the target of a gate of its module. The two then
/// have one flow, which is over only once both allow: the screens of a
/// sign-in whose gate lets everyone in still show while its guard of an
/// account does not allow. Their functions read one notifier, so that the
/// router never finds that one of them changed and the other did not yet:
/// a location that asks for the condition and was asked for behind the
/// gate is lost when the gate allows first.
///
/// The app asks its gates first: those of all modules by their [stage],
/// the gates of an earlier stage first, whatever the order of the modules,
/// so the guard of an onboarding comes before the guard of a sign-in. It
/// asks the gates of one stage in the order of the modules and of
/// [RoutesData.guards]. The first gate that does not allow decides, for
/// every route, and no later guard is asked, so the flows of the gates
/// show one after another. Only when every gate allows does the app ask
/// the guards with a condition, in the same order among themselves: for a
/// route, the first one whose condition the route asks for and that does
/// not allow decides. For a route that asks for two conditions, the target
/// of the first guard opens, and once that guard allows, the router closes
/// its flow and asks about the request again: the target of the second
/// guard opens in turn.
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
  /// [redirectTo] of its module until [allows] says otherwise: in place of
  /// every other screen of the app, or, with a [condition], in place of
  /// the routes that ask for it.
  const RouteGuard({
    required this.name,
    required this.allows,
    required this.redirectTo,
    required this.stage,
    this.resumes = true,
    this.condition,
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
  /// navigation. Neither it nor a route below it can start the app, and
  /// none of them asks for a condition.
  final String redirectTo;

  /// When the app asks the guard among the guards of its kind, the gates
  /// or the guards with a [condition]: before every one of a later stage,
  /// whichever module declares it; see [GuardStage].
  final GuardStage stage;

  /// Whether the router brings the user back to the location that the
  /// guard takes them from when it stops allowing, once it allows again.
  ///
  /// When a guard with `false` stops allowing, the router remembers no
  /// location for it, and it forgets what it remembered: the location that
  /// another guard took the user from, and a location that was asked for
  /// before. So the user comes to the screen that the app starts on once
  /// the guards allow, as the next user does after a sign-out, whichever
  /// flows were shown in between. A location that is asked for after the
  /// guard stopped, while it does not allow, is remembered, so the user
  /// still comes to a link that arrives then.
  ///
  /// The guard stopped when the router finds that it does not allow after
  /// it found that it allowed. The router looks each time it is about to
  /// show a location and each time a guard notifies, whichever guard
  /// decides then. So a guard that does not allow when the app starts has
  /// not stopped: the location that the app is opened with is shown once
  /// the guards of a first launch allow. And a guard that stops and allows
  /// again without the router looking in between, as one that does not
  /// notify when [allows] changes, is not seen to stop: the router forgets
  /// nothing then.
  ///
  /// The router remembers a location only for a gate. A guard with a
  /// [condition] takes the user from no location: when it stops allowing,
  /// the router closes the pages that ask for the condition, and the user
  /// is on the page below them, whatever this says. With `false`, such a
  /// guard still makes the router forget what a gate made it remember,
  /// whichever page the user is on when it stops.
  final bool resumes;

  /// The condition that the guard stands for, or `null` for a gate, which
  /// keeps the user from every route outside its flow.
  ///
  /// With a condition, the guard keeps the user only from the routes of
  /// the app that ask for it ([Route.conditions]), and [allows] says
  /// whether the condition holds. The module requires or provides the role
  /// of the condition, and an app has one guard for a condition: a module
  /// declares one at most, and two modules with one each cannot be in one
  /// app.
  final RouteCondition? condition;

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
    this.conditions = const [],
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
  /// the router. Such a route takes no required parameters and asks for no
  /// condition. `--start` refuses a route that asks for one in every app,
  /// also in an app without a guard for the condition, where the route
  /// shows like any other.
  final bool startCandidate;

  /// What a user needs for this route and for the routes below it, each a
  /// condition of a role that the module requires, uses or provides, such
  /// as an account; see [RouteCondition].
  ///
  /// While a condition does not hold, a request for the route opens the
  /// target of the guard that stands for it in the app over the page that
  /// the user is on, and the router shows the route once it holds (see
  /// [RouteGuard]). In an app without such a guard, the route shows like
  /// any other.
  ///
  /// Every user gets to the main navigation, to the screen that the app
  /// starts on and to the flow of a guard, so a route that asks for a
  /// condition is none of these: it is no destination and below none, no
  /// start candidate, and outside the flows of the guards of the module.
  final List<RouteCondition> conditions;
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
