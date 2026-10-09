# smf_onboarding

The SMF module of the onboarding of the app. It is a feature: a screen with its route, which the module that provides the router renders, and a guard of the routes, which that module asks.

On its first launch, the app shows the onboarding in place of every other screen. The onboarding has two pages: a welcome with the name of the app, and a page that ends it. A page is a picture with a title and a text below it. The picture is a cell of the periodic table among smaller cells, over a grid that fades at its edges. The cell of the first page has the symbol of the app, which SMF makes from its name: `Ma` for `my_app`. The cell of the last page has an icon.

Skip is above the pages. Below them are a mark for each page and one button of the whole width: Next, and Get started on the last page, where Skip is gone. Skip and Get started finish the onboarding. The app then shows the screen that it starts on, and later launches start there.

While the pages turn, the cells move at different speeds, the background blends into the colour of the last page, and the marks follow. No animation runs without end, so a widget test that waits for the screen with `pumpAndSettle()` returns. On a device that asks for less motion, the cells are there at once and Next shows the next page without the turn.

The module generates three files in `lib/features/onboarding/`:

- `onboarding_screen.dart` has `OnboardingScreen`, at `/onboarding`, which shows the pages one at a time, with Skip, the marks and the button around them.
- `onboarding_pages.dart` has the pages: the list that `onboardingPages()` returns, and `OnboardingPage`, the widget of a page, which takes a `symbol` or an `icon` for its cell, a title and a text. Replace the pages with your own, and the screen keeps what is around them. The screen puts an `OnboardingPageScope` around each page. Its `turned` tells how far the pages are turned away from the page, so a page of your own can move with them, as `OnboardingPage` does.
- `onboarding_status.dart` has `onboardingStatus`, which knows whether the user has finished the onboarding. Its `complete()` finishes the onboarding at once and saves that, and its `restart()` starts it again.

The screen does not navigate. The guard keeps the user in the onboarding until it is finished, and the router leaves it then. The guard has the stage `welcome`. In an app with another guard that asks who the user is, such as the guard of a sign-in, the onboarding comes first, whichever order the modules were named in.

To show the onboarding again, call `onboardingStatus.restart()`, for example where the user taps a row of the settings. The app shows the onboarding at once, in place of the screen that the user is on, and saves that it is not finished. Once the user finishes it again, they are back on the screen that they were on. From a page pushed over another screen, they come back to the screen below the pushed pages. Do not navigate to `/onboarding` to show it: the guard decides when the app shows the onboarding. Once the onboarding is finished, a navigation to that route, such as a link, shows the screen that the app starts on, or the screen of another guard of the app while that one does not allow.

While you edit the pages, the app shows the onboarding once for each install. To see it again, clear the data of the app or install it anew. For the time being, you can also call `onboardingStatus.restart()` in `main()` after `bootstrap()`. Before `bootstrap()` the call has no lasting effect, because the start-up takes what the preferences have saved.

The module requires a module that provides the preferences, which remember that the onboarding is finished. The app saves it under `onboarding.completed` and reads it before its first frame, so a later launch never shows the onboarding first. Nothing is saved before the user finishes: an app that is closed in the middle of the onboarding starts it from its first page the next time.

The page that the user sees is the state of a `PageController` in the screen, so the module works with any module that manages state, or with none. It adds no package to the app.

The screen takes its colours and its text styles from the theme of the app, in its light and in its dark mode, so it follows a theme of your own. It names no font but the monospaced one of the device, for the number in a cell.

A page scrolls when it is too small for what it shows, as with a large text size on a small phone, and the buttons grow with their texts. The letters and the number in a cell keep their size, since they are part of the picture. A screen reader announces the title of each page as a header and passes over the picture.

The texts of the screen are in English and in Ukrainian. In an app with a module that provides localization, they follow the language of the app. An app without such a module shows them in English.

## Use with the SMF CLI

`smf create` asks which features the app has. To choose this one without the question, here with a start screen:

```bash
smf create my_app -m home,onboarding
```

The feature requires a router and preferences, and `smf create` adds each when only one module provides it.

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The onboarding module](https://doc.saymyframe.com/modules/onboarding)
- [Navigation](https://doc.saymyframe.com/guides/navigation)
