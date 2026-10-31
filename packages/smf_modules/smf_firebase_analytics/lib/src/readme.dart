import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Firebase Analytics';

/// The section of the module in the README of the app: which file is on the
/// package, what the app needs for its events to show up in Google Analytics,
/// and how often the developer of the app does that with several flavors.
const String readmeSection = '''
The app records its events with [firebase_analytics](https://pub.dev/packages/firebase_analytics): `lib/core/analytics/firebase_analytics_service.dart` implements the analytics service of the app on it.

The events of the app reach Google Analytics only once the Firebase project is linked to it, which a project that `flutterfire configure` creates is not. Until then, the app logs its events, but they show up nowhere. Turn it on under Project settings > Integrations in the Firebase console. The section ${AppEntryRole.setupHeading} lists this among the steps that you do by hand.

The link belongs to the project, and every app of the project sends its events there. So repeat this in each Firebase project of your flavors. Flavors that share a project need it once, and their events go to one property.
''';
