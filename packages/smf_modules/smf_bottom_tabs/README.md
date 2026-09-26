# smf_bottom_tabs

The SMF module of the main navigation of the app as tabs in a bar at the bottom. It provides the layout role of the SMF module model.

Features declare which of their routes are destinations of the main navigation, each with a label and an icon, such as Home with the home icon. This module generates the widget of the main navigation, `AppShell`, in `lib/core/layout/app_shell.dart`:

- a `Scaffold` whose body is the screen of the selected destination;
- a Material 3 `NavigationBar` at the bottom, with a tab for each destination, with its icon and label;
- with one destination there is nothing to switch to, so the bar is hidden and the screen fills the app.

The module that provides the router role builds the main navigation around the shell: a branch for each destination, in the order of the features, which keeps its stack while another tab is selected, and the app opens on the tab of its start screen. An app without destinations has no main navigation.

The bar shows at most five destinations, as the Material Design guidelines advise, so `smf create` stops before it generates an app with more.

## Use with SMF CLI

`smf create` asks which module provides the layout of the app, and offers none as well. To choose this one without the question, name it with `-m`:

```bash
smf create my_app -m home,bottom_tabs
```

The layout requires a router, which `smf create` adds when only one module provides it.

This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_bottom_tabs) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
