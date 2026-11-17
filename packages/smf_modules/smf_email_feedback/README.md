# smf_email_feedback

The SMF module of feedback by email. It provides the feedback role of SMF: "Write to us" on the settings screen, or a button of the app that calls `appFeedback.open(context)`, opens a new mail to the developer in the mail app of the device, with [url_launcher](https://pub.dev/packages/url_launcher).

What the mail holds:

- It goes to the address in `EMAIL_FEEDBACK_ADDRESS` of `.env`. Until that has one, the app does not offer the way to write, and "Write to us" hides.
- Its subject is "Feedback: " and the name of the app, in the language of the app.
- Its body leaves room for the message, then tells the name, the version, the build number and the flavor of the app, from [package_info_plus](https://pub.dev/packages/package_info_plus), and the system and the model of the device, from [device_info_plus](https://pub.dev/packages/device_info_plus). The mail of the flavor for a release names no flavor.
- The link encodes a space as `%20`, never as `+`, as RFC 6068 asks.

The app asks the device nothing before it opens the mail, so it needs no `<queries>` on Android. Where no mail app opens it, such as on the iOS simulator, a sheet shows the address with a button that copies it.

## Use with the SMF CLI

```bash
smf create my_app -m email_feedback,settings
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The email_feedback module](https://doc.saymyframe.com/modules/email-feedback)
