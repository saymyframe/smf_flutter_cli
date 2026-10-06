# smf_bottom_tabs

The SMF module of the main navigation of the app as tabs in a bar at the bottom. It provides the layout role of SMF.

Features declare which of their routes are destinations of the main navigation, each with a label and an icon. This module generates `AppShell`, a `Scaffold` with a bar at the bottom that has a tab for each destination, and the router builds the main navigation around it, with a stack of its own for each tab. With one destination, the bar is hidden.

The generated file draws the bar itself, in the colours of the theme of the app, so that file is where you change its look. A hairline separates the bar from the screen. The icon and the label of the selected tab are in the secondary colour of the theme, and a tab keeps its size when it is selected. When the user switches to another tab, its screen fades in while it rises a little.

Each tab is a button for a screen reader, with the label of its destination. The text size of the device scales the labels up to 1.3 times, and a long press on a tab shows its label in a tooltip at the full size. For a user who asks the device for less motion, the tab and the screen change at once.

The label of a tab is a text of its feature. When a module provides the texts of the app, such as `gen_l10n`, the bar shows each label in the language of the app, also after the user chooses another language. Without such a module the labels are in English.

The bar shows at most five destinations, as the Material Design guidelines advise. With more, `smf create` leaves out the features of the destinations that do not fit, each with a warning, and generates the app without them; with `--strict`, it stops instead.

## Use with the SMF CLI

`smf create` asks which module provides the layout, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m home,bottom_tabs
```

The layout requires a router, which `smf create` adds when only one module provides it.

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The bottom_tabs module](https://doc.saymyframe.com/modules/bottom-tabs)
- [Navigation](https://doc.saymyframe.com/guides/navigation)
