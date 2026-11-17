import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_posthog/src/posthog_module.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'PostHog';

/// The name of the file with the analytics service of the module.
const serviceFileName = 'posthog_analytics_service.dart';

/// The path in the app of the file with the analytics service of the module.
const serviceFile = 'lib/core/analytics/$serviceFileName';

/// The names of the keys in `.env`.
final String _token = PostHogModule.projectTokenKey.name;
final String _host = PostHogModule.hostKey.name;

/// The file of the values of the app.
const String _env = EnvRole.dotEnvFile;

/// The property of every event with the flavor of the build.
const String _flavor = PostHogModule.flavorProperty;

/// The block of `android/app/build.gradle.kts` that pins the SDK of PostHog
/// for Android.
const _gradlePin = '''
dependencies {
    implementation("com.posthog:posthog-android") {
        version { strictly("<version>") }
    }
}''';

/// The section of the module in the README of the app: the project token
/// and the host, the flavor of each event and the filter on it, the screens,
/// what PostHog is set up to record and what not, the setting of
/// collection and the user, the versions of the SDKs for the platforms and
/// how to pin them, and what the app sends for its privacy policy.
final String readmeSection = '''
The app records its events in [PostHog](https://posthog.com) with [posthog_flutter](https://pub.dev/packages/posthog_flutter). `$serviceFile` starts PostHog in `bootstrap()` with `$_token` and `$_host` of `$_env`, and implements the analytics service of the app on it. While `$_token` has no value in a build, or only spaces or a personal API key, or `$_host` has a value that is no http or https address, the app starts without PostHog and records nothing in it, and a debug build prints why.

Create a project in PostHog and copy its project token, which starts with `phc_`, into `$_token`. Leave `$_host` empty for PostHog's US Cloud, or give it `https://eu.i.posthog.com` for its EU Cloud, or the address of your own PostHog. The section ${AppEntryRole.setupHeading} lists this among the steps that you do by hand. A project token only lets an app send events to its project, and it goes into the app, where anyone can read it, so it is no secret. Never put a personal API key of PostHog, which starts with `phx_`, into `$_env`: the app refuses one, and a build with it has the key inside.

Every event has the property `$_flavor`, the flavor of the build, such as `${AppEntryRole.defaultFlavor.name}` or `${AppEntryRole.releaseFlavor.name}`. A debug build records its events too, so filter the insights and the dashboards of PostHog on `$_flavor` equal to `${AppEntryRole.releaseFlavor.name}` to count only the users of the release.

In an app with a router, the router tells `logPostHogScreen()` of that file each screen that the user sees, which PostHog records as a `\$screen` event under the name of its route. The app has no `PosthogObserver`: one with its defaults would record the screens a second time. Surveys, which the app does not show, need `surveys = true` in the config of `initPostHogAnalytics()` and a `PosthogObserver` among the observers of the navigators: give it `routeFilter: (_) => false`, so that it records no screen of its own.

PostHog is set up to record no more than the analytics of the app need:

- a person profile only for a user whom the app identifies with `setUserId()`, and none for an anonymous user;
- no session replay, no survey, and no request for feature flags at each start;
- nothing about push messages, which the push role handles: `${PostHogModule.pushOpenedKey}` is `false` in `${AppEntryRole.infoPlistFile}`;
- the events of the lifecycle of the app, such as `Application Opened`, and no errors, which the crash reporting of the app reports.

`setAnalyticsCollectionEnabled()` of the analytics service opts PostHog in and out, and PostHog keeps that on the device, as the section ${AnalyticsRole.readmeHeading} tells. PostHog starts from Dart, so `analyticsCollectedFromFirstStart` alone decides what it does before the code chose, and it has no native lines for that: `${PostHogModule.autoInitKey}` is `false` in `${AppEntryRole.androidManifestFile}` and in `${AppEntryRole.infoPlistFile}`, so that its SDKs for the platforms do not start on their own before Dart. On iOS, PostHog keeps nothing when the code chose what `analyticsCollectedFromFirstStart` says already. So an app that changes that constant from `false` to `true` collects on the devices of iOS whose users declined before. PostHog keeps the events that it has not sent yet in a queue on the device, and opting out does not empty it: events that the app logged before `setAnalyticsCollectionEnabled(false)` may still leave with the next batch of PostHog, also at a later start.

`setUserId(null)` starts a new anonymous user in PostHog, so call it when the user signs out, not at each start. A property that `setUserProperty()` sets for a user without an id waits for the next id. PostHog keeps the user on the device from one start to the next, but the analytics service does not know that user: after each start, call `setUserId(id)` for a user who is signed in. Until then, the properties that `setUserProperty()` sets wait in memory, and they are lost if the app closes. While collection is off, PostHog gets neither a new user nor a property, and gets them once collection is on again.

posthog_flutter takes the SDKs of PostHog for Android and iOS in a range of versions, so each build of the app takes the newest of the range, and each release of posthog_flutter raises the lowest. So the app does not pin them, or the next `flutter pub upgrade` would stop its build. To ship a build for a store with versions that you checked, pin the SDK for Android in `android/app/build.gradle.kts`:

```kotlin
$_gradlePin
```

Then raise that version whenever `flutter pub upgrade` raises posthog_flutter: a new posthog_flutter may need a newer SDK than the pin, and Gradle stops the build at a strict version that is too low.

On iOS, Swift Package Manager writes the versions that it resolved into a `Package.resolved` of the Xcode workspace, and CocoaPods, in an app that builds with it, into `ios/Podfile.lock`: keep that file in git for a build for the App Store, and change it on purpose.

For the privacy policy of the app, which the App Store and Google Play ask for in the listing of the app and inside the app: PostHog gets what users do in the app, the screens that they see, an id of the device and the id of the user once the code sets one with the properties of the user, the model and the system of the device, and a coarse location, which PostHog infers from the IP address of the device unless `disableGeoIp` is set when PostHog starts. PostHog keeps the IP address of the device too, unless the settings of the project discard client IP data. The SDKs of PostHog for iOS declare what they collect in their privacy manifests.
''';
