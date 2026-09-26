# smf_go_router

The SMF module that routes the app with [go_router](https://pub.dev/packages/go_router). It provides the router role of the SMF module model.

The modules of the app declare their routes, and the router role gives the app the typed navigation facade, `context.nav`, in `lib/core/router/navigation.dart`. This module adds `go_router` to the dependencies of the app and generates `createAppRouter()` in `lib/core/router/app_router_factory.dart`, which creates the router of the app once, on first use:

- every route is a `GoRoute` under the namespace of its module, such as `/home/details/:id`, with its children below it;
- a route is named by its full name, such as `home.details`, which navigator observers, such as the one of analytics, report as the name of the screen;
- screens are imported with prefixes of their own, so their names never clash;
- the app opens on its start route, and `/` redirects to it. When no route can start the app, as in an app without features, `/` shows the fallback screen of the app.

Screens get the values of their parameters from the location, parsed with `tryParse`. An optional value that the location does not have, or that is not of its type, is `null`. A location without a valid required value, such as `/home/details/abc` for an `int`, shows the error screen of go_router.

`context.nav` navigates through this router whatever the context, even one above the router:

- `go()` shows the location with the chain of its parents below it;
- `push()` shows the location on top and completes with the value its page returns;
- `replace()` replaces the top of the stack with the location, as go_router's `pushReplacement` does.

The navigator of the router creates its observers from the factories that modules give the router role, such as `() => FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)`.

go_router 17 works with the Material library of Flutter 3.44, which the apps of SMF use. go_router 18 has moved to the separate `material_ui` package, whose `MaterialApp` it looks for to choose Material pages.

## Use with SMF CLI

`smf create` asks which module provides the router, and offers none as well. To choose this one without the question, name it with `-m`:

```bash
smf create my_app -m go_router
```

When several routes can start the app, `smf create` asks which one, or takes it from `--start`, such as `--start /home`.

This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_go_router) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
