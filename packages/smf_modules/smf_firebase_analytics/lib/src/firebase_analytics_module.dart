import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/bundles/firebase_analytics_bundle.dart';
import 'package:smf_firebase_analytics/src/agents.dart';
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
/// Analytics works on the Firebase app, so the module depends on
/// [FirebaseCoreModule], which initializes Firebase in `bootstrap()`. The
/// service is created on first use, without waiting, and the first screen
/// shows after `bootstrap()`. When the app has a DI container, the role
/// registers the service in it.
///
/// In the guide for coding agents of an app with a router, the module adds
/// to the section of the analytics that the screen views need no code.
final class FirebaseAnalyticsModule extends SmfModule {
  /// Creates the module.
  const FirebaseAnalyticsModule();

  /// The id of the module.
  static const id = ModuleId('firebase_analytics');

  static const _file = ImportRef.app(
    'core/analytics/firebase_analytics_service.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Firebase Analytics with firebase_analytics',
        kind: ModuleKinds.infrastructure,
        dependsOn: {FirebaseCoreModule.id},
        providers: [RoleProvider.plain(analyticsRole)],
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
        // Of the listener, which only an app with a router has.
        AppEntryRole.agentSections.entry(
          analyticsRole.description,
          AgentNote(screenViewsAgentNote),
          when: {routerRole},
        ),
      ];
}
