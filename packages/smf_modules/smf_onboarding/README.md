# smf_onboarding

The SMF module of the onboarding of the app. It is a feature: a screen with its route, which the module that provides the router renders, and a guard of the routes, which that module asks.

On its first launch, the app shows the onboarding in place of every other screen. The onboarding has two pages: a welcome with the name of the app, and a page that ends it. Below them are Skip and Next, and on the last page Done alone. Skip and Done finish the onboarding. The app then shows the screen that it starts on, and later launches start there.

The module generates three files in `lib/features/onboarding/`:

- `onboarding_screen.dart` has `OnboardingScreen`, at `/onboarding`, which shows the pages one at a time and the buttons below them.
- `onboarding_pages.dart` has the pages: the list that `onboardingPages()` returns. Replace them with your own, and the screen keeps its buttons.
- `onboarding_status.dart` has `onboardingStatus`, which knows whether the user has finished the onboarding. Its `complete()` finishes the onboarding at once and saves that, and its `restart()` starts it again.

The screen does not navigate. The guard keeps the user in the onboarding until it is finished, and the router leaves it then.

To show the onboarding again, call `onboardingStatus.restart()`, for example where the user taps a row of the settings. The app shows the onboarding at once, in place of the screen that the user is on, and saves that it is not finished. Once the user finishes it again, they are back where they were. Do not navigate to `/onboarding` to show it: the guard decides when the app shows the onboarding. If something else shows its screen, such as a link to the route, the onboarding starts again too.

While you edit the pages, the app shows the onboarding once for each install. To see it again, clear the data of the app or install it anew, or call `onboardingStatus.restart()` for the time being.

The module requires a module that provides the preferences, which remember that the onboarding is finished. The app saves it under `onboarding.completed` and reads it before its first frame, so a later launch never shows the onboarding first. Nothing is saved before the user finishes: an app that is closed in the middle of the onboarding starts it from its first page the next time.

The page that the user sees is the state of a `PageController` in the screen, so the module works with any module that manages state, or with none. It adds no package to the app. A page scrolls when it is too small for what it shows, and the buttons go one below the other when they do not fit side by side, as with a large text size on a small phone. A screen reader announces the title of each page as a header.

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
