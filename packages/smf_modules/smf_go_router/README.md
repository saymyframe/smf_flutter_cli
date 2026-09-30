# smf_go_router

The SMF module that routes the app with [go_router](https://pub.dev/packages/go_router) 17. It provides the router role of SMF.

The features of the app declare their routes, and the router role gives the app a typed navigation facade, `context.nav`, with `go()`, `push()` and `replace()` for every route. This module turns the routes into the `GoRouter` of the app. With a layout, such as tabs at the bottom, it builds the main navigation of the app around it. It tells the listeners of the screen, such as analytics, about each screen the user sees.

## Use with the SMF CLI

`smf create` asks which module provides the router, and offers none as well. When a module you chose needs a router, such as the start screen of `home`, `smf create` adds this one by itself if it is the only module that provides the router, and asks otherwise. To choose it without the question:

```bash
smf create my_app -m go_router
```

When several routes can start the app, `smf create` asks which one, or takes it from `--start`, such as `--start /home`.

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The go_router module](https://doc.saymyframe.com/modules/go-router)
- [Navigation](https://doc.saymyframe.com/guides/navigation)
