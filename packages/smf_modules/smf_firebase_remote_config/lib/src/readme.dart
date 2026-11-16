import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Firebase Remote Config';

/// The path in the app of the file with the service of the module.
const serviceFile =
    'lib/core/remote_config/firebase_remote_config_service.dart';

/// The API of Google through which the app fetches the values of a Firebase
/// project.
const fetchApi = 'firebaseremoteconfig.googleapis.com';

/// The API of Google through which Firebase tells the app of the values
/// that the project publishes while the app runs.
const realtimeApi = 'firebaseremoteconfigrealtime.googleapis.com';

/// The page of Firebase with the prices of Remote Config.
const pricingPage = 'https://firebase.google.com/docs/remote-config/pricing';

/// The section of the module in the README of the app, which also has the
/// section of the remote config role: where the parameters of the app go
/// in Firebase and how a value differs by platform, the two APIs that the
/// app needs and the restrictions of the API keys of a project, how often
/// the app fetches, what fetches cost, the identifier that each fetch
/// sends, and the privacy policy that the stores ask for.
const String readmeSection = '''
The app reads its values of remote config from [Firebase Remote Config](https://firebase.google.com/docs/remote-config) with [firebase_remote_config](https://pub.dev/packages/firebase_remote_config): `$serviceFile` implements the remote config service of the app on it (see the section ${RemoteConfigRole.readmeHeading}, which lists the parameters of the app).

Create each parameter of the app in the Firebase console of the project of each flavor: open Remote Config, add the parameter with the name, the type and the default that the section ${RemoteConfigRole.readmeHeading} lists, and publish the changes. A value that differs by platform, such as one for Android and one for iOS, gets a condition of the platform in the console. The section ${AppEntryRole.setupHeading} lists this among the steps that you do by hand once the app has a parameter. A value that you publish reaches an app that runs through the real-time updates of Firebase, and an app that starts later with its next fetch.

The app needs two APIs of Google in the project: the Firebase Remote Config API (`$fetchApi`) for its fetches, and the Firebase Remote Config Realtime API (`$realtimeApi`) for the values that you publish while it runs, which answers 403 while it is disabled. If the API keys of the Android and iOS apps of the project have API restrictions, in the Google Cloud console under APIs & Services, Credentials, each key must allow both APIs, or the fetches and the real-time updates of the app fail.

A release build fetches at most every 12 hours, and a debug build at each start and each time you come back to the app, so a value that you change shows at once while you develop. The real-time updates do not wait for that interval. Firebase gives a project 100,000 fetches a day for free; beyond them, a project on the Spark plan is throttled and one on the Blaze plan is billed for each fetch (see the [prices of Remote Config]($pricingPage)). An app without parameters fetches nothing.

Each fetch sends the Firebase installation ID of the app on the device, an identifier of the installation. Declare it in the App Privacy details of App Store Connect and in the Data safety form of Google Play. Both stores also ask for a link to the privacy policy of the app, in the listing of the app and inside the app: name Firebase Remote Config there among the services that the app sends data to.
''';
