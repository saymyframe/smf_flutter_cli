import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/router_role_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contracts/src/roles/brick_templates.dart';
import 'package:smf_contracts/src/roles/symbol_uses.dart';

part 'router/router_dsl.dart';
part 'router/router_facade.dart';
part 'router/router_guards.dart';
part 'router/router_rules.dart';
part 'router/router_template.dart';

/// The router role; see [RouterRole].
const routerRole = RouterRole._();

/// The role of the router: the pages of the app, how to reach them, and the
/// main navigation when a layout is present.
///
/// Features describe their pages as [RoutesData]; each module's routes live
/// under its namespace, `/<module id>`. From these routes the role's
/// template generates, whichever provider is selected:
/// - `lib/core/router/app_router.dart`: the `AppRouter` interface, which a
///   provider implements, and the instance `appRouter`, created by the
///   provider's `createAppRouter()` (see [createAppRouter]);
/// - `lib/core/router/navigation.dart`: the typed navigation facade.
///   `context.nav.home.details(id: 5)` returns a `NavLink` whose `go()` makes
///   the stack the route's chain of parents (see [FacadeRoute.chain]),
///   `push<T>()` shows the route on top and completes with its result, and
///   `replace()` replaces the top of the stack. Every route has a location
///   class, such as `HomeDetailsLocation`, which providers match on.
///
/// A provider renders the routes from [facadeOf], so it agrees with the
/// facade on every path and name. It:
/// - names each route by its [FacadeRoute.fullName], which the listeners of
///   [screenListeners] get as the name of the screen and navigator
///   observers as the name of its page;
/// - builds the start route of [startIn] at `/`, or the fallback screen of
///   the app entry if there is none;
/// - when a layout is present and the app has destinations, puts them into
///   the `AppShell` of the layout role, in the order of
///   [RouterFacade.destinations], each with the routes below it in its
///   branch, which keeps its stack while another is selected. It gives the
///   shell the list that the layout role generates for them
///   ([LayoutRole.appDestinations]), with the label and the icon of each,
///   so it renders neither itself. It matches the destinations before the
///   other top-level routes, which stay outside the main navigation, and
///   the app starts on the branch of its start route;
/// - refuses to push a location in the main navigation from a page shown
///   over the main navigation, or to replace such a page with one, with a
///   `StateError` that leaves the stack as it is;
/// - closes the route on top when the user presses the back button of the
///   system, with `NavigatorState.maybePop` of the navigators that the user
///   sees, the innermost first: a dialog before the page below it, and a
///   page of the selected branch of the main navigation before the main
///   navigation, unless a route of the root navigator, such as a dialog,
///   covers the main navigation; with no route to close, it leaves the
///   button to the system, which closes the app. Its error screen is a
///   page like any other for the button: a dialog over it closes, and the
///   screen itself closes only if a page is below it, which is up to the
///   provider. With none, the router has no route to close;
/// - calls every factory of [observers] for each navigator it creates;
/// - calls the listeners of [screenListeners] each time the screen the user
///   sees changes, each on its own, so that a listener that throws keeps no
///   other from hearing the screen;
/// - imports screens with a prefix of its own and does not name its router
///   class `AppRouter`;
/// - creates `config` once.
///
/// A module may keep the user from the rest of the app until a condition
/// holds, with the guards of its [RoutesData.guards] (see [RouteGuard]): a
/// guard is a gate over the whole app, unless it stands for a condition
/// that only some routes ask for ([RouteCondition]), from which alone it
/// then keeps the user. A role publishes such a condition, a feature asks
/// for it on its routes ([Route.conditions]), and a module with the role
/// declares the guard, so neither module knows the other. The target of a
/// gate takes the place of the whole stack. The target of a guard that
/// stands for a condition opens over the page that the user is on, who can
/// go back from it, and the router does what was asked once the condition
/// holds. In an app whose modules declare guards, the role's template also
/// generates [routeGuards], [redirectOf], [flowIsOver], [guardChanges] and
/// [guardedNavigation] with the classes of its answers in `app_router.dart`.
/// The provider asks the guards through them about every location before
/// it shows it, and tells them of its pages when one of them changes, as
/// [guardedNavigation] says. In the guide for coding agents of such an app,
/// the template tells where the guards are and in which order the router
/// asks them, what tells a gate from a guard of some routes, how the code
/// of the app adds one and changes what it allows, that the router
/// navigates when it does, what the user sees while a guard of either kind
/// does not allow and once it allows again, and when code may navigate
/// into the flow of a guard. An app without guards gets none of this.
///
/// When the role is present, the provider of the [AppEntryRole] builds the
/// root `MaterialApp` of the app as a `MaterialApp.router` and passes it
/// `appRouter.config`.
final class RouterRole extends Role<RoutesData> {
  const RouterRole._();

  /// The path of the file with `AppRouter` and `appRouter`.
  static const appRouterFile = 'lib/core/router/app_router.dart';

  /// The path of the file with the navigation facade.
  static const navigationFile = 'lib/core/router/navigation.dart';

  /// The path of the provider's file with [createAppRouter].
  static const appRouterFactoryFile = 'lib/core/router/app_router_factory.dart';

  /// `AppRouter createAppRouter()`, which creates the provider's
  /// implementation of `AppRouter` on the first use of `appRouter`.
  static const createAppRouter = RequiredFunction(
    'createAppRouter',
    path: appRouterFactoryFile,
    returnType: 'AppRouter',
  );

  /// The name of the list of the guards of an app with guards, which the
  /// role's template generates in [appRouterFile], as
  /// `final List<RouteGuard> routeGuards`: the guards of
  /// [RouterFacade.guards], in the order the app asks them. The gates come
  /// first, and then the guards that stand for a condition. Those of each
  /// kind come by their stages (see [GuardStage]), whatever the order of
  /// the modules, and for the guards of one stage, in the order of the
  /// modules and of their [RoutesData.guards]. The app has nothing else of
  /// the stage of a guard.
  ///
  /// Each is a `RouteGuard` of the app, a class of the same file:
  /// - `name`, the full name of the guard (see [FacadeGuard.fullName]);
  /// - `allows`, the `ValueListenable<bool>` that the function of the guard
  ///   returns, which the list calls once, when it is first used;
  /// - `redirectTo`, the location of the target of the guard;
  /// - `flow`, the full names of the routes of its flow (see
  ///   [FacadeGuard.flow]);
  /// - `resumes`, whether the router brings the user back to where they
  ///   were once the guard allows again (see [RouteGuard.resumes]): `true`
  ///   unless the list says otherwise;
  /// - `routes`, for a guard that stands for a condition, the full names of
  ///   the routes of the app that ask for it
  ///   ([RouterFacade.routesAsking]), which may be none; and `null` for a
  ///   gate, for which the list leaves it out. The app has nothing else of
  ///   a condition.
  static const routeGuards = 'routeGuards';

  /// The name of the function that says what the guards show when the
  /// router is asked for a route, which the role's template generates in
  /// [appRouterFile] in an app with guards, as
  /// `AppLocation? redirectOf(String? routeName)`.
  ///
  /// It takes the full name of the route of a location (see
  /// [FacadeRoute.fullName]), or `null` for a location that is no route of
  /// a module: one that no route matches, and `/`. The location `/` has no
  /// name in any app. It shows the route that the app starts on, which a
  /// provider asks about by the name of that route when it shows it, or
  /// the fallback screen of the app entry.
  ///
  /// It returns the location that the router then shows, or `null` if the
  /// guards let the user see the route. That is the target of the first
  /// gate of [routeGuards] that does not allow, unless the route is in the
  /// flow of that gate. No guard after it is asked, so the answer for the
  /// routes of its flow is always `null`: while a gate does not allow, it
  /// keeps the user from every route outside its flow, of whichever
  /// module, and its target shows in place of the route.
  ///
  /// When every gate allows, the answer is the target of the first guard
  /// with `routes` that does not allow and has the route among them: a
  /// guard that stands for a condition keeps the user only from the routes
  /// that ask for it, and from no location that is no route of a module.
  /// Its target shows over the page that the user is on rather than in
  /// place of the route. The routes of its flow are none of its `routes`,
  /// so the answer for them is `null` then too.
  ///
  /// The function only answers for the guards that do not allow. A route
  /// that they let the user see may be in a flow that is over, which
  /// [flowIsOver] tells. A provider asks through [guardedNavigation], which
  /// asks both, says how the router shows the answer, and keeps what the
  /// gates make a router remember.
  static const redirectOf = 'redirectOf';

  /// The name of the function that says whether the flow of a route is
  /// over, which the role's template generates in [appRouterFile] in an app
  /// with guards, as `bool flowIsOver(String? routeName)`.
  ///
  /// It takes the full name of a route or `null`, as [redirectOf] does, and
  /// returns whether the route is in the flow of a guard and every guard
  /// of [routeGuards] with that flow allows. Two guards of a module may
  /// show the same target and so have the same flow, which is over only
  /// once both allow. That holds for a gate and a guard that stands for a
  /// condition too: while the gate lets every user in and the condition
  /// does not hold, the flow is not over, and its routes show like any
  /// other. A route outside every flow is in none, and neither is a
  /// location that is no route of a module.
  ///
  /// The routes of a flow show only while a guard with that flow does not
  /// allow. Once the flow is over, the router shows the screen that the
  /// app starts on in place of each location of the flow, or the target of
  /// a gate while that one does not allow, and it closes the pages of the
  /// flow that it has, as [guardedNavigation] says. So nothing navigates
  /// into the flow of a gate: its module changes what its guard reads, and
  /// the router shows the target.
  /// A route of a flow cannot start the app, so the screen that the app
  /// starts on is in no flow.
  static const flowIsOver = 'flowIsOver';

  /// The name of the listenable that notifies its listeners when a guard
  /// starts or stops allowing, which the role's template generates in
  /// [appRouterFile] in an app with guards, as
  /// `final Listenable guardChanges`.
  ///
  /// In an app with guards, a provider listens to it, and tells
  /// [guardedNavigation] of its pages each time it notifies. A guard may
  /// notify though what it allows did not change.
  static const guardChanges = 'guardChanges';

  /// The name of the class through which the provider asks the guards of an
  /// app with guards, which the role's template generates in
  /// [appRouterFile], as `GuardedNavigation<L>`, with the classes of its
  /// answers: `ShowInstead`, `ShowOver`, `Stay` and `Close`. The class
  /// decides what a router does about the guards, and keeps what the gates
  /// make it remember, so that this is written once: providers that ask it
  /// alike and do what it answers show the user the same pages at the same
  /// time.
  ///
  /// `L` is how the provider knows a location that it can show as `go()`
  /// does, such as the URI of the location. The provider creates one
  /// `GuardedNavigation(start: ..., locationOf: ...)`: with its location
  /// `/`, the screen that the app starts on, and with its location for an
  /// `AppLocation` of the navigation, in which the class knows the targets
  /// of the guards. It then asks the class at two times.
  ///
  /// Before it shows a location, the provider calls
  /// `asked(route, location, onTopOf: routes)`, with the full name of the
  /// route of the location or `null`, as [redirectOf] takes it: for the
  /// location the app starts on, for each location that `go()`, `push()`
  /// or `replace()` of the navigation is asked to show, and for each
  /// location that the platform gives it, if it takes any. `onTopOf` are
  /// the full names of the routes of the pages that the user can get back
  /// to at that time, the same pages that the provider tells `changed` of
  /// (see below). It gives none while it has no page, and none for a
  /// location from the platform, which takes the place of the stack.
  ///
  /// The provider asks once for each request. The class remembers nothing
  /// of a request that it answers `ShowOver` for, so a second call for the
  /// same request finds the flow open and answers `Stay`. A router that
  /// asks again inside its own navigation, as one whose redirect runs for
  /// each location that it goes to, keeps that second call from the class.
  ///
  /// When the answer is `null`, the provider shows the location. Otherwise
  /// it never builds the screen of that location, and the listeners of
  /// [screenListeners] never hear of it. It does what the answer says:
  /// - `ShowInstead(location)`, with the target of a gate or the location
  ///   `/`: it shows that location in place of the other, as `go()` to it
  ///   does. It takes the whole stack, whichever page the other location
  ///   was asked from. Such a `push()` completes with `null` at once.
  /// - `ShowOver(location, flow: routes)`, with the target of a guard that
  ///   stands for a condition and the full names of the routes of its
  ///   flow: it shows the target over the page on top, as `push()` of it
  ///   does, so the user can go back from it. Asked with no pages, as for
  ///   a location from the platform, it first shows `/` in place of the
  ///   stack and then the target over it, and the listeners of
  ///   [screenListeners] hear only of the target. It keeps the request
  ///   waiting, as said below, and a `push()` that waits does not complete.
  /// - `Stay()`: it shows nothing and leaves its pages as they are. Such a
  ///   `push()` completes with `null` at once.
  ///
  /// The target of a gate also takes the stacks of every branch of the
  /// main navigation, so that each branch is back on its destination when
  /// the user comes to it again: the pages of the branches are pages that
  /// the gate keeps the user from, and none of them may show again. The
  /// location `/` for a flow that is over hides nothing from the user. The
  /// provider shows it as its `go()` to that location does, and whether the
  /// branches that are not selected keep their pages then is up to the
  /// provider, as it is for that `go()`. `ShowOver` and `Close` leave the
  /// main navigation and its branches as they are: no route of the main
  /// navigation asks for a condition.
  ///
  /// The request that waits is the one that the provider got `ShowOver`
  /// for: the location, and whether `go()`, `push()`, `replace()` or the
  /// platform asked for it. The provider keeps it, not the class, since
  /// only the provider can complete a `push()`. It keeps one request: when
  /// it gets `ShowOver` while a request waits, it drops the earlier one,
  /// and a `push()` that waited completes with `null`. The request waits
  /// while a page of a route of the `flow` of the answer is among the
  /// pages that the user can get back to, so it is still there after a
  /// `push()` or a `replace()` inside the flow. It ends in one of two ways:
  /// - `changed` answers `Close` and no page of the flow is left after the
  ///   provider closed the pages. The provider then makes the request
  ///   again as it was made, on top of the pages that are left, and asks
  ///   the class about it again: `push()` shows the location over the page
  ///   that the flow was opened from, and the first `push()` completes
  ///   with the value of that page; `go()` shows it in place of the stack;
  ///   `replace()` shows it in place of the page that the flow was opened
  ///   from; and a location from the platform shows as `go()` to it. The
  ///   class may answer the request with the target of another guard, as
  ///   for a route that asks for two conditions.
  /// - The last page of the flow leaves in any other way: the user goes
  ///   back from it, or a location takes the place of the stack. The
  ///   provider drops the request, and a `push()` that waited completes
  ///   with `null`.
  ///
  /// Each time [guardChanges] notifies, the provider calls
  /// `changed(pages)` with the pages that the user can get back to, the
  /// one on top first: those of its root navigator and, in place of the
  /// main navigation, those of its selected branch, but not those of the
  /// other branches. Each page comes with the full name of its route or
  /// `null`, with its location, and with `pushed`: whether the provider
  /// can close the page on its own and leave the pages below it as they
  /// are. That is `true` for a page that `push()` showed, and for a page
  /// that `replace()` showed in place of such a page: a page of a flow
  /// that replaces the target of its guard closes like the target. Whether
  /// a page that `replace()` showed in place of another page is one is up
  /// to the provider. A provider that has no page yet, as before it shows
  /// the location that the app starts on, has none to tell of and shows
  /// nothing then: it asks about its first location when it shows it.
  ///
  /// When the answer is `null`, the provider leaves everything as it is:
  /// the stack stays, the listeners of [screenListeners] hear nothing, and
  /// each `push()` still completes with the value of its page. Otherwise:
  /// - `ShowInstead(location)`: it shows the location as it shows that
  ///   answer of `asked`, in place of its whole stack, and the target of a
  ///   gate in place of the stacks of every branch too, so no page that a
  ///   gate kept the user from shows again in a branch that was not
  ///   selected. That holds whenever the gate allows again: also in the
  ///   turn in which it stopped allowing, and while the transition to its
  ///   target is on its way. Whether the listeners of [screenListeners]
  ///   hear of a target that no frame showed is up to the provider, and so
  ///   is whether the `push()` of a page that the answer takes out of the
  ///   stack completes, as it is when `go()` replaces the stack.
  /// - `Close(n)`: it closes the `n` pages on top, each of which it told of
  ///   as `pushed`, and leaves the pages below them as they are. The pages
  ///   leave at once, whatever the navigator shows over them, such as a
  ///   dialog, and also a page that a `push()` of the same turn showed and
  ///   that the navigator has not built yet. Each `push()` that showed one
  ///   of them completes with `null`. The provider then makes the request
  ///   that waits again, if no page of its flow is left. The listeners of
  ///   [screenListeners] hear of the page that the user ends on, and not of
  ///   the page below the closed ones when the request shows another page
  ///   over it: the user never saw that page come back.
  ///
  /// What the class answers, and what it remembers:
  /// - While a gate keeps the user from a location, `asked` answers
  ///   `ShowInstead` of its target, as [redirectOf] tells it. The class
  ///   remembers that location, whichever gate keeps the user from it, in
  ///   place of the one that it remembered before: the user comes back to
  ///   the latest location that they or the platform asked for, such as a
  ///   link that arrives while the flow of a gate is shown.
  /// - For a location that the gates let the user see, `asked` answers
  ///   `ShowInstead` of `/` when its flow is over, as [flowIsOver] tells.
  ///   So the routes of a flow show only while a guard with that flow does
  ///   not allow: at any other time `go()`, `replace()`, `push()`, which
  ///   completes with `null`, and a location from the platform show the
  ///   screen that the app starts on, or the target of a gate while that
  ///   one does not allow.
  /// - For a route that asks for a condition that does not hold, `asked`
  ///   answers `ShowOver` of the target of the guard that stands for it,
  ///   and `Stay` while a page of the flow of that guard is among
  ///   `onTopOf`. The page may be on top or below another page, such as a
  ///   page outside the flow that was pushed from the target. So the flow
  ///   never opens over itself: a further request while it is open does
  ///   nothing, and the first one waits. The class remembers no location
  ///   for such a guard.
  /// - `changed` first answers `ShowInstead` of the target of the gate that
  ///   keeps the user from one of the pages, so that no such page stays in
  ///   the stack. If that gate brings the user back
  ///   ([RouteGuard.resumes]), and unless the class remembers a location
  ///   already, it then remembers the location below the pages that the
  ///   provider can close, or `/` when it can close every page. So the
  ///   user comes back to where the pushed pages were opened from, such as
  ///   a tab of the main navigation, and not to a pushed page alone, with
  ///   no way back. The flow of a condition that was open goes with the
  ///   stack, and its request with it.
  /// - When a guard that does not bring the user back stops allowing, the
  ///   class remembers no location for it and forgets the one that it
  ///   remembers, whichever gate or request made it remember it. So once
  ///   the gates allow again, the user comes to a location that was asked
  ///   for since, or else to `/`: after a sign-out, the next user comes
  ///   neither to the page that the last one was on nor to a link that the
  ///   last one followed. That holds for a guard that stands for a
  ///   condition too, though the class remembers nothing for it.
  /// - The class takes such a guard to have stopped when it does not allow
  ///   at a call of `asked` or `changed` and allowed at the call before.
  ///   That holds while another guard decides and the answer is `null`
  ///   too. At the first call no guard has stopped, so the location that
  ///   the app is opened with stays remembered through the flows of a
  ///   first launch. A provider calls `changed` each time [guardChanges]
  ///   notifies, so the class sees every stop of a guard that notifies
  ///   while it does not allow. It cannot see a guard that stops and
  ///   allows again between two calls, such as one that does not notify:
  ///   it forgets nothing then.
  /// - With no page that a gate keeps the user from, `changed` answers
  ///   `ShowInstead` of the location that it remembers, once no gate keeps
  ///   the user from that location, and forgets it. If a guard that stands
  ///   for a condition still keeps the user from it, the answer is `/`
  ///   instead: the class cannot keep a request waiting, so a location
  ///   that asks for a condition and was asked for behind a gate is lost
  ///   when the gate allows before the condition holds. Two guards with
  ///   one flow, as the gate and the guard of an account of a sign-in,
  ///   therefore read one notifier, so that the class never sees the gate
  ///   allow while the condition does not hold yet.
  /// - The class also forgets the location that it remembers when the user
  ///   moves on: when `asked` answers for a location that no gate keeps
  ///   the user from and that is outside every flow, or in a flow that is
  ///   over. The code of the app may navigate right when a gate starts
  ///   allowing, before the provider tells the class.
  /// - It never remembers a location in the flow of a guard, of whichever
  ///   guard: once that guard allows, its flow is over.
  /// - Otherwise `changed` looks for the lowest page that has to leave: a
  ///   page in a flow that is over, or a page that a guard that stands for
  ///   a condition keeps the user from. It answers `Close` of that page
  ///   and the pages over it when the provider can close each of them and
  ///   a page stays below. So once a condition holds, the pages of its
  ///   flow close, with a page outside the flow that was pushed from them,
  ///   and the provider makes the request again. And once a condition
  ///   stops holding, the pages that ask for it close, and the user is on
  ///   the page that they were opened from.
  /// - When the provider cannot close those pages, or no page stays below
  ///   them, `changed` answers `ShowInstead` of `/`. So the user leaves a
  ///   flow that took the place of the stack for the screen that the app
  ///   starts on, as when the gate of the flow started allowing with
  ///   nothing remembered, or when the platform opened the app on a
  ///   location of the flow. The same goes for a page that asks for a
  ///   condition and has no page below it, as after `go()` to it.
  /// - Otherwise `changed` answers `null`, as for a notification without a
  ///   change of what the guards allow.
  static const guardedNavigation = 'GuardedNavigation';

  /// Factories of navigator observers, such as `() => MyNavigatorObserver()`.
  ///
  /// A provider calls each factory once for every navigator it creates,
  /// such as the navigator of each branch of the main navigation, because
  /// an observer can watch only one navigator; each observer sees the pages
  /// of its own navigator. Switching between the branches of the main
  /// navigation is not a navigation event, so no observer sees it, though a
  /// branch shows its first page when it is first selected. When a page
  /// shown over the main navigation closes, the observers of the root
  /// navigator see the main navigation come back, not the page of its
  /// selected branch. To follow the screen the user sees, use
  /// [screenListeners].
  static const observers = SocketRef<FactoryListSocket>.role(
    routerRole,
    'observers',
    FactoryListSocket(),
  );

  /// Listeners of the screen the user sees, such as
  /// `(route, location) => debugPrint('$location: $route')`: functions of
  /// the type `void Function(String? route, String location)`.
  ///
  /// The screen the user sees is the page of the router on top of the app;
  /// a page shown past the router, such as with `Navigator.push`, and a
  /// dialog are not pages of the router. A provider calls every listener
  /// once for each change of it, a switch to another branch of the main
  /// navigation, such as another tab, included:
  /// - when the app shows its first screen;
  /// - when another page comes on top, such as a page that a navigation
  ///   shows, a page that shows again as the pages above it close, or the
  ///   page of the branch of the main navigation that the user selects;
  /// - when the page on top shows another location, such as the same route
  ///   with other values of its parameters.
  ///
  /// It does not call them for the pages that a navigation puts below the
  /// one on top, such as the parents of a route that `go()` shows, and
  /// never twice in a row for the same page at the same location, such as
  /// for a navigation that leaves the page on top as it is. So the
  /// listeners hear of the back button of the system, which closes the
  /// route on top of the innermost navigator, only when it closes a page of
  /// the router: when it closes a dialog, the page below it stays the
  /// screen the user sees.
  ///
  /// Nor does a provider call them for a page that is on top only while it
  /// does what the guards of the routes answer (see [guardedNavigation]),
  /// which the user never sees: the page below a flow that it closes, when
  /// the request that waited shows another page over it at once, and the
  /// screen that the app starts on, when it opens a flow over that screen
  /// for a location from the platform.
  ///
  /// A listener gets the full name of the route of the screen among the
  /// routes of the modules, such as `home.details` (see
  /// [FacadeRoute.fullName]), and the location of the screen: its path,
  /// with the query and the fragment it has, such as `/home/details/5`. For
  /// a screen that is not a route of a module, the route is `null`, and the
  /// location is still that of the screen: `/` for the fallback screen of
  /// the app entry, and for the error screen of the router, the location it
  /// could not show.
  ///
  /// A provider may call the listeners while the app builds, such as for
  /// its first screen, so a listener only takes note of the screen: it does
  /// not navigate or rebuild widgets, and it returns without throwing.
  ///
  /// A provider calls each listener on its own, as the modules of the
  /// listeners know nothing of each other: what one throws anyway keeps no
  /// other listener from hearing the screen, and reaches neither the router
  /// nor the handlers of the errors of the app. In debug mode the provider
  /// prints it, so that a listener that fails shows in the console.
  static const screenListeners = SocketRef<FactoryListSocket>.role(
    routerRole,
    'screen_listeners',
    FactoryListSocket(),
  );

  /// Annotations of the class of a screen, such as auto_route's
  /// `@RoutePage()`.
  ///
  /// The template of the screen's feature puts the member's tag on its own
  /// line right before the class, with only other annotations and comments
  /// between them, as in
  /// `{{{smf_router__screen_annotations__home__home_screen}}}`. The module
  /// rule `router.screen_sockets` checks it for every screen of every
  /// route.
  static const screenAnnotations = SocketFamily<ScreenKey, CodeSocket>.role(
    routerRole,
    'screen_annotations',
    CodeSocket(),
    keyOf: _screenSegments,
    segments: 2,
  );

  /// Annotations of a parameter of the constructor of a screen, such as
  /// auto_route's `@PathParam('id')`.
  ///
  /// The template of the screen's feature puts the member's tag in the
  /// parameters of the screen's unnamed constructor, right before the
  /// parameter, as in
  /// `{{{smf_router__param_annotations__home__details_screen__id}}} required
  /// this.id,`. A tag must not follow a `{`, which mustache would read as
  /// part of it: put the parameters on lines of their own.
  static const paramAnnotations = SocketFamily<ParamKey, CodeSocket>.role(
    routerRole,
    'param_annotations',
    CodeSocket(),
    keyOf: _paramSegments,
    segments: 3,
  );

  /// `--start`, the full path of the route the app starts on, such as
  /// `/home`.
  static const startOption = RoleOption(
    name: 'start',
    valueHelp: 'path',
    help: 'The full path of the screen the app starts on, such as /home.',
  );

  @override
  String get id => 'router';

  @override
  String get description => 'Router';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get uses => {layoutRole};

  @override
  List<SocketRef> get sockets => const [observers, screenListeners];

  @override
  List<SocketFamily<Object?, SocketKind>> get socketFamilies =>
      const [screenAnnotations, paramAnnotations];

  @override
  RoleInterface get interface => const RoleInterface(
        files: [appRouterFile, navigationFile],
        symbols: [createAppRouter],
      );

  @override
  List<RoleOption> get options => const [startOption];

  @override
  RoleTemplate<RoutesData> get template => const _RouterTemplate();

  @override
  List<ModuleRule<RoutesData>> get moduleRules => const [
        ModuleRule(
          id: 'router.routes',
          description: 'The routes of a module have valid paths, names, '
              'screens, parameters and destinations, and a router can reach '
              'each of them. A route asks only for conditions of the roles '
              'of the module, and such a route is outside the main '
              'navigation and the flows of the guards of the module, and '
              'neither it nor a route below it is a start candidate.',
          check: _checkRoutes,
        ),
        ModuleRule(
          id: 'router.guards',
          description: 'The guards of a module have valid names and '
              'functions of the app, and each shows a top-level route of '
              'the module that needs no values, is outside the main '
              'navigation, and has no start candidate in its flow. A guard '
              'that stands for a condition is the only one of the module '
              'for it, and the module requires or provides the role of the '
              'condition.',
          check: _checkGuards,
        ),
        ModuleRule(
          id: 'router.screen_sockets',
          description: 'The template of every screen has the tags of its '
              'annotation sockets, before the class and before each '
              'parameter of the route.',
          check: _checkScreenSockets,
        ),
      ];

  @override
  List<StructuralRule<RoutesData>> get structuralRules => const [
        StructuralRule(
          id: 'router.nav_access',
          description: 'Code of a module navigates only to its own routes '
              'and to those of the modules it depends on, through the facade '
              'or through their location classes.',
          check: _checkNavAccess,
        ),
        StructuralRule(
          id: 'router.screen_constructors',
          description: 'The unnamed constructor of every screen is const '
              'and takes each parameter of its route as a named parameter of '
              'the same name, and nothing else that is required.',
          check: _checkScreenConstructors,
        ),
        StructuralRule(
          id: 'router.guard_functions',
          description: 'The function of every guard is a top-level function '
              'in its file that takes no arguments and returns a '
              'ValueListenable<bool>.',
          check: _checkGuardFunctions,
        ),
        StructuralRule(
          id: 'router.guards_asked',
          description: 'In an app with guards, the files of the provider of '
              'the role create a GuardedNavigation, read guardChanges, and '
              'name its answers ShowOver and Close.',
          check: _checkGuardsAsked,
        ),
        StructuralRule(
          id: 'router.destinations_shown',
          description: 'In an app with a layout and destinations, the files '
              'of the provider of the role read appDestinations of the '
              'layout role, the destinations that its main navigation '
              'shows.',
          check: _checkDestinationsShown,
        ),
      ];

  /// The routes of the app in [input], the input of a hook of this role or
  /// of a role that requires or uses it, such as the layout.
  RouterFacade facadeOf(RoleHookInput<Object> input) =>
      RouterFacade.of(dataIn(input));

  /// The route the app starts on, as the template chose it, or `null` if
  /// no route can start the app or [input] comes before the choice.
  FacadeRoute? startIn(RoleHookInput<RoutesData> input) {
    final choice = input.choice;
    if (choice is! RouterChoice) return null;
    final path = choice.startPath;
    return path == null ? null : facadeOf(input).routeAt(path);
  }
}

List<String> _screenSegments(ScreenKey key) =>
    [key.feature.value, SmfNames.snakeCaseOf(key.screen)];

List<String> _paramSegments(ParamKey key) => [
      key.feature.value,
      SmfNames.snakeCaseOf(key.screen),
      SmfNames.snakeCaseOf(key.param),
    ];
