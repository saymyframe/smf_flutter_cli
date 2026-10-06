# Generate a Flutter app with tabs at the bottom

`bottom_tabs` is a module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli). Choose it with `-m` together with a feature, such as the start screen `home`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m home,bottom_tabs --no-input
```

The start screen and the layout both need a router, so `smf create` adds `go_router`, naming the first module that needs it:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding go_router: the only provider of the router role, which home requires.
```

The module writes `lib/core/layout/app_shell.dart` with `AppShell`, a `Scaffold` with a bar at the bottom that has a tab for each destination of the features, such as Home with the home icon. The file draws the bar itself and shows the selected tab in the colour that the theme gives the selected destination of a navigation bar, or in its primary colour. To change the look of the bar, edit that file. The router builds the main navigation around it, and each tab keeps its own stack. This app has a single destination, so the bar stays hidden until a second feature, such as `settings` or a module of your own, adds another one. With `gen_l10n` among the modules, the tabs are in the language of the app.

Without `-m`, `smf create` asks which module provides the layout.

The documentation has more on [the bottom_tabs module](https://doc.saymyframe.com/modules/bottom-tabs) and on [navigation in the generated app](https://doc.saymyframe.com/guides/navigation).
