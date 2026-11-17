# Generate a Flutter app whose users write to you by email

`email_feedback` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that opens a new mail to you in the mail app of the device. Choose it with `-m`, with a settings screen for the entry "Write to us":

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m email_feedback,settings --no-input
```

The module adds url_launcher, package_info_plus and device_info_plus to the `pubspec.yaml` of the app, and `lib/core/feedback/email_feedback_service.dart`, which opens the mail. Put your address into `.env`:

```
EMAIL_FEEDBACK_ADDRESS=support@example.com
```

The rest of the app uses `appFeedback` of the feedback role, in `lib/core/feedback/app_feedback.dart`. Call it from a button of your own too:

```dart
TextButton(
  onPressed: () => appFeedback.open(context),
  child: const Text('Write to us'),
)
```

The mail tells the version of the app and the device, which the user sees before sending. Where no mail app opens it, such as on the iOS simulator, a sheet shows the address to copy.

The documentation has more on [the email_feedback module](https://doc.saymyframe.com/modules/email-feedback).
