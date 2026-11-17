# Generate a Flutter app that asks for a store review with in_app_review

`in_app_review` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that asks the App Store or Google Play for its review dialog. Choose it with `-m`, with a settings screen for the entry "Rate the app":

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m in_app_review,settings --no-input
```

The module adds in_app_review, url_launcher and package_info_plus to the `pubspec.yaml` of the app, and `lib/core/review/in_app_review_service.dart`, which asks the store for its dialog. The rest of the app uses `appReview` of the review role, in `lib/core/review/app_review.dart`. Call it at a natural break, such as when the user has finished a task:

```dart
Future<void> finishNote(Note note) async {
  await saveNote(note);
  unawaited(appReview.requestIfDue());
}
```

The call asks only when a review is due, and never in the onboarding or a sign-in. It returns nothing, since the store tells no app whether the dialog showed. Never call it from a button: the entry "Rate the app" on the settings screen opens the page of the app in its store instead.

On iOS that page takes the App Store ID of the app, `REVIEW_APP_STORE_ID` in `.env`. Google Play shows the dialog only in an app that it installed, such as from an internal test track: the README of the app tells how.

The documentation has more on [the in_app_review module](https://doc.saymyframe.com/modules/in-app-review).
