# Generate a Flutter app with go_router

`go_router` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that routes the app with go_router. Choose it with `-m`, here with the start screen `home`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m go_router,home --no-input
```

The module adds go_router to the `pubspec.yaml` of the app, and `lib/core/router/app_router_factory.dart`, which turns the routes of the features into a `GoRouter`:

```dart
@override
late final GoRouter config = GoRouter(
  initialLocation: '/home',
  observers: _observers(),
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/home'),
    GoRoute(
      path: '/home',
      name: 'home.home',
      builder: (context, state) => const screen0.HomeScreen(),
    ),
  ],
)..routerDelegate.addListener(_pagesChanged);
```

Screens navigate with `context.nav`, such as `context.nav.home.home().go()`, which the router role writes into `lib/core/router/navigation.dart`. It does not name go_router, so the screens of a feature work with any router. With a layout such as `bottom_tabs`, the router builds the main navigation with a branch for each tab.

A feature needs a router, so `smf create -m home` adds `go_router` by itself while it is the only module that provides the router. Without `-m`, `smf create` asks which module provides the router.

The documentation has more on [the go_router module](https://doc.saymyframe.com/modules/go-router) and on [navigation in the generated app](https://doc.saymyframe.com/guides/navigation).
