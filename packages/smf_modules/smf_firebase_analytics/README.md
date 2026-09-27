# smf_firebase_analytics

The SMF module of [Google Analytics for Firebase](https://firebase.google.com/docs/analytics) with [firebase_analytics](https://pub.dev/packages/firebase_analytics). It provides the analytics role of SMF: the app records what its users do through its `AnalyticsService`, and, when the app has a router, a screen view for each screen the user sees.

An app can have several modules that provide analytics, and the service of the app forwards each call to all of them. Analytics works on the Firebase app, so the module depends on [smf_firebase_core](https://pub.dev/packages/smf_firebase_core), which comes with it and sets up Firebase.

## Use with the SMF CLI

`smf create` asks which modules provide the analytics of the app, and the answer may be none. To choose this one without the question:

```bash
smf create my_app -m firebase_analytics
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS and Linux; Windows is not tested yet.

## Documentation

- [The firebase_analytics module](https://doc.saymyframe.com/modules/firebase-analytics)
- [Firebase](https://doc.saymyframe.com/guides/firebase)
