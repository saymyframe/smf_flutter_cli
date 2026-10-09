# Generate a Flutter app with an onboarding

`onboarding` is the onboarding of the apps that the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) generates: a new user goes through it on the first launch of the app. Choose it with `-m`, here with the start screen `home`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m home,onboarding --no-input
```

The screens need a router, and the onboarding needs preferences to remember that it is finished. So `smf create` adds `go_router` and `shared_preferences`, and names the first module that needs each:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding go_router: the only provider of the router role, which home requires.
Adding shared_preferences: the only provider of the preferences role, which onboarding requires.
```

The module writes three files into `lib/features/onboarding/`. The pages are a list in `onboarding_pages.dart`:

```dart
List<Widget> onboardingPages(BuildContext context) => [
  OnboardingPage(
    symbol: 'Ma',
    title: 'My App',
    text: 'Welcome! We are glad you are here.',
  ),
  OnboardingPage(
    icon: Icons.check_rounded,
    title: 'You are all set',
    text: 'Enjoy the app.',
  ),
];
```

An `OnboardingPage` is a cell of the periodic table among smaller cells, with a title and a text below it. The cell has a `symbol`, here the one that SMF makes from the name of the app, or an `icon`. Change this list to change what the onboarding shows. A page is any widget.

`OnboardingScreen` in `onboarding_screen.dart` shows the pages one at a time. Skip is above them. Below them are a mark for each page and one button: Next, and Get started on the last page. While the pages turn, the cells move at different speeds and the background blends into the colour of the last page. The screen takes its colours and its text styles from the theme of the app.

Skip and Get started call `onboardingStatus.complete()` of `onboarding_status.dart`, which finishes the onboarding and saves that in the preferences, under `onboarding.completed`. The screen does not navigate. On the first launch, the app shows the onboarding at `/onboarding` in place of the start screen at `/home`: a guard of the routes keeps the user there. Once the onboarding is finished, the router shows the start screen, and later launches open on it.

To show the onboarding again, call `onboardingStatus.restart()`. The app shows it at once. Once it is finished, the user is back on the screen that they were on, or, from a page pushed over another screen, on the screen below the pushed pages. A link to `/onboarding` does not: once the onboarding is finished, it shows the start screen. The app remembers that the onboarding is finished, so while you edit the pages, a call in `main()` after `bootstrap()` is how you see them again.

In a test that starts the app to look at another screen, call `onboardingStatus.complete()` before the app starts. Otherwise the test sees the onboarding.

The documentation has more on [the onboarding module](https://doc.saymyframe.com/modules/onboarding) and on [navigation in the generated app](https://doc.saymyframe.com/guides/navigation).
