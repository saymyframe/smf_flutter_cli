# Generate a Flutter app with tabs at the bottom

`bottom_tabs` is a module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli). Choose it with `-m` together with a feature, such as the start screen `home`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m home,bottom_tabs --no-input
```

The layout needs a router, so `smf create` adds `go_router` and says why:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding go_router: the only provider of the router role, which home requires.
```

The module writes `lib/core/layout/app_shell.dart` with `AppShell`, a `Scaffold` with a Material 3 `NavigationBar` that has a tab for each destination of the features, such as Home with the home icon. The router builds the main navigation around it, and each tab keeps its own stack. This app has a single destination, so the bar stays hidden until a second feature adds another one.

Without `-m`, `smf create` asks which module provides the layout.

The documentation has more on [the bottom_tabs module](https://doc.saymyframe.com/modules/bottom-tabs) and on [navigation in the generated app](https://doc.saymyframe.com/guides/navigation).
