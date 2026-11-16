import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/bundles/firebase_analytics_bundle.dart';
import 'package:smf_firebase_analytics/src/agents.dart';
import 'package:smf_firebase_analytics/src/readme.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';

/// The module that records what users do in the app with Firebase
/// Analytics and the firebase_analytics package, and so provides the
/// analytics role.
///
/// The template of the role generates the `AnalyticsService` interface and
/// `createAnalyticsService()`, which returns the one analytics service of
/// the app that forwards every call to the services of all its providers.
/// This module adds `firebase_analytics` to the dependencies of the app and
/// implements the service in
/// `lib/core/analytics/firebase_analytics_service.dart` on
/// `FirebaseAnalytics`.
///
/// When the app has a router, the module gives it `logFirebaseScreenView`
/// of its file, a listener of the screen the user sees, which logs a screen
/// view each time the router tells it that the screen changed: the first
/// screen of the app, a page that a navigation shows, a page that shows
/// again as the pages above it close, the page on top when it shows another
/// location, and the page of a branch of the main navigation that the user
/// switches to, such as a tab. The name of the screen is the full name of
/// its route, such as `home.home`, or `/` for the fallback start screen of
/// the app; the error screen of the router is not logged, as the location
/// that the app cannot show may hold anything. A navigation that puts
/// several pages on a stack at once, such as going to a page whose parents
/// are not on it yet, logs only the page on top. Nothing waits for a screen
/// view, so an error of the platform is printed rather than left to the
/// handler of the uncaught errors of the app.
///
/// In such an app, the manifest of Android and `Info.plist` also turn off
/// the screen views that Firebase Analytics logs itself, one for each
/// activity on Android and each view controller on iOS. Flutter has one of
/// each for the whole app, so such a view names no screen of the app and
/// only adds to the views of the listener, as at each start of the app. An
/// app without a router keeps them, as nothing else logs a screen there.
///
/// Analytics works on the Firebase app, so the module depends on
/// [FirebaseCoreModule], which initializes Firebase in `bootstrap()`. The
/// service is created on first use, without waiting, and the first screen
/// shows after `bootstrap()`. When the app has a DI container, the role
/// registers the service in it.
///
/// Firebase Analytics keeps the setting of `setAnalyticsCollectionEnabled`
/// on the device itself, across starts, as the analytics role asks of every
/// provider. It starts before any Dart code runs and records the first open
/// of the app and the start of a session there, so in an app that collects
/// nothing before its code chose ([AnalyticsCollection.off]), the render hook
/// of its provider turns its collection off by default in the native
/// projects: [androidCollectionKey] in the manifest of Android and
/// [iosCollectionKey] in `Info.plist`, both false. An app that collects from
/// its first start has neither.
///
/// The events of the app reach Google Analytics only once the Firebase
/// project is linked to it, which a project that `flutterfire configure`
/// creates is not, so every app of the module lists the step by hand
/// [googleAnalyticsStep], and its section of the README tells that the step
/// repeats for each Firebase project of the flavors of the app.
///
/// In the guide for coding agents of an app with a router, the module adds
/// to the section of the analytics that the screen views need no code.
final class FirebaseAnalyticsModule extends SmfModule {
  /// Creates the module.
  const FirebaseAnalyticsModule();

  /// The id of the module.
  static const id = ModuleId('firebase_analytics');

  /// The step by hand in which the developer turns on Google Analytics for
  /// the Firebase project, under Project settings > Integrations of the
  /// Firebase console: a project that `flutterfire configure` creates has
  /// none, and the events of the app reach nothing until it is on. Every
  /// app of the module lists it.
  static const googleAnalyticsStep = ManualStep(
    ManualStepId(id, 'google_analytics'),
    'Turn on Google Analytics in the Firebase project, unless it is on '
    'already',
  );

  /// The meta-data of the application in the manifest of Android whose
  /// value false turns the collection of Firebase Analytics off by default:
  /// until the code of the app turns it on, which Firebase Analytics keeps.
  static const androidCollectionKey = 'firebase_analytics_collection_enabled';

  /// The key of `Info.plist` whose value false turns the collection of
  /// Firebase Analytics off by default, as [androidCollectionKey] does on
  /// Android.
  static const iosCollectionKey = 'FIREBASE_ANALYTICS_COLLECTION_ENABLED';

  static const _file = ImportRef.app(
    'core/analytics/firebase_analytics_service.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Firebase Analytics with firebase_analytics',
        kind: ModuleKinds.infrastructure,
        dependsOn: {FirebaseCoreModule.id},
        providers: [_FirebaseAnalyticsProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(firebaseAnalyticsBundle),
        const PubspecContribution.hosted('firebase_analytics', '^12.6.0'),
        analyticsRole.data(
          const RoleImplementation(
            type: TypeRef('FirebaseAnalyticsService', import: _file),
            create: FactoryRef('createFirebaseAnalyticsService', import: _file),
          ),
        ),
        googleAnalyticsStep,
        // The router tells the listener, a function of the file of the
        // module, which the file has only in an app with a router, about
        // each screen the user sees.
        const SocketContribution.item(
          RouterRole.screenListeners,
          Fragment(
            'logFirebaseScreenView',
            imports: [
              ImportRef.app(
                'core/analytics/firebase_analytics_service.dart',
                show: ['logFirebaseScreenView'],
              ),
            ],
          ),
          when: {routerRole},
        ),
        // The listener logs the screens, so Firebase Analytics logs none of
        // its own, which would name the one activity of Flutter on Android
        // and its one view controller on iOS rather than a screen.
        AppEntryRole.androidManifestApplicationMeta.entry(
          'google_analytics_automatic_screen_reporting_enabled',
          const AndroidMetaData.value('false'),
          when: {routerRole},
        ),
        AppEntryRole.infoPlist.entry(
          'FirebaseAutomaticScreenReportingEnabled',
          const PlistBoolean(false),
          when: {routerRole},
        ),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        // Of the listener, which only an app with a router has.
        AppEntryRole.agentSections.entry(
          analyticsRole.description,
          AgentNote(screenViewsAgentNote),
          when: {routerRole},
        ),
      ];
}

/// The provider of the analytics role, whose render hook turns the
/// collection of Firebase Analytics off by default in the native projects of
/// an app that collects nothing before its code chose: Firebase Analytics
/// starts before any Dart code runs, so only the native projects can keep it
/// from collecting at the first start of the app.
final class _FirebaseAnalyticsProvider
    extends RoleProvider<RoleImplementation> {
  const _FirebaseAnalyticsProvider();

  @override
  Role<RoleImplementation> get role => analyticsRole;

  @override
  RoleOutput render(RoleHookInput<RoleImplementation> input) => RoleOutput(
        fragments: [
          if (analyticsRole.collectionIn(input) == AnalyticsCollection.off) ...[
            AppEntryRole.androidManifestApplicationMeta.entry(
              FirebaseAnalyticsModule.androidCollectionKey,
              const AndroidMetaData.value('false'),
            ),
            AppEntryRole.infoPlist.entry(
              FirebaseAnalyticsModule.iosCollectionKey,
              const PlistBoolean(false),
            ),
          ],
        ],
      );
}
