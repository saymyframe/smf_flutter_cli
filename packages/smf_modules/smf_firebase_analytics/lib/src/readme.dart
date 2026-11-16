import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/src/firebase_analytics_module.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Firebase Analytics';

/// The section of the module in the README of the app: which file is on the
/// package, what the app needs for its events to show up in Google Analytics,
/// how often the developer of the app does that with several flavors, the
/// native lines with which an app that collects nothing before its code
/// chose keeps Firebase Analytics from collecting at its first start, and
/// the declaration of the advertising ID in Play Console.
const String readmeSection = '''
The app records its events with [firebase_analytics](https://pub.dev/packages/firebase_analytics): `lib/core/analytics/firebase_analytics_service.dart` implements the analytics service of the app on it.

The events of the app reach Google Analytics only once the Firebase project is linked to it, which a project that `flutterfire configure` creates is not. Until then, the app logs its events, but they show up nowhere. Turn it on under Project settings > Integrations in the Firebase console. The section ${AppEntryRole.setupHeading} lists this among the steps that you do by hand.

The link belongs to the project, and every app of the project sends its events there. So repeat this in each Firebase project of your flavors. Flavors that share a project need it once, and their events go to one property.

Firebase Analytics keeps what `setAnalyticsCollectionEnabled()` chose on the device, across starts. It starts before any Dart code runs, and records the first open of the app and the start of a session there. So in an app generated with `--analytics-collection=off`, its collection is off by default in the native projects too: `${FirebaseAnalyticsModule.androidCollectionKey}` is `false` in `${AppEntryRole.androidManifestFile}`, and `${FirebaseAnalyticsModule.iosCollectionKey}` is `false` in `${AppEntryRole.infoPlistFile}`. An app generated without the option has neither line. To change what the app does before its code chose, change those lines together with `analyticsCollectedFromFirstStart`, as the section ${AnalyticsRole.readmeHeading} tells. An install whose user turns collection on later has no `first_open` event.

Firebase Analytics adds the permission `com.google.android.gms.permission.AD_ID` to the Android app, so the declaration of the advertising ID in Play Console applies to the app: declare that it uses the advertising ID, for analytics.
''';
