import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the router: how its file writes the routes of the app.
const agentNote = '''
With `go_router`:

- `${RouterRole.appRouterFactoryFile}` has the one `GoRouter` of the app. A route is a `GoRoute` in its `routes`, or in the `routes` of its parent: `path` is the full path of a top-level route and the path from its parent otherwise, and `name` is `<feature>.<route>`. The values of a route come from `state.pathParameters` and `state.uri.queryParameters`. Parse one that is not a `String` with `tryParse`, and throw a `GoException` in the `redirect` of the route when a required value is missing or does not parse, so that the router shows its error screen.
- The app opens at `initialLocation`, and the route `/` leads to the same screen: change both together.
- To follow the screen that the user sees, add a function to `_screenListeners`.
''';

/// The note of the module for an app with a layout and no destination, in
/// the section of the router: what the first destination needs, since the
/// file of the module then has no main navigation to add it to.
final String firstDestinationAgentNote = '''
- The app has no destination yet, so that file has no main navigation. For the first one, add after the route `/` a `StatefulShellRoute.indexedStack` with `notifyRootObserver: false`, a `StatefulShellBranch` with `observers: _observers()` for each destination, and a `builder` that returns `${LayoutRole.appShell.name}` with the `${LayoutRole.destination.name}`s, `shell.currentIndex`, `shell.goBranch` and `shell` as its `body`. Then make `push()` and `replace()` throw a `StateError` for a location in the main navigation while a page is shown over it.
''';

/// The note of the module for an app with a main navigation, in the section
/// of the router: where the destinations are among the routes.
final String mainNavigationAgentNote = '''
- The destinations of the main navigation are the branches of the `StatefulShellRoute.indexedStack`, in the order of the `destinations` of `${LayoutRole.appShell.name}`. A new destination is a `StatefulShellBranch` there, with `observers: _observers()`, and a `${LayoutRole.destination.name}` at the same index. A route outside the main navigation goes after the shell route.
''';
