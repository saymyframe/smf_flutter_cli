import 'package:smf_contracts/lego.dart';
import 'package:smf_firebase_analytics/bundles/firebase_analytics_bundle.dart';
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
/// When the app has a router, the module gives it a factory of
/// `FirebaseAnalyticsObserver`, which the router calls for each navigator
/// it creates. The observer of a navigator logs a screen view with the name
/// of a page when the page enters the stack of the navigator, because it is
/// pushed or replaces the page on top, and when the pages above it are
/// popped: the name of a route of a module, such as `home.home`, or the
/// name that the router gives any other page; a page without a name is not
/// logged. So each page is logged by one observer. A navigation that puts
/// several pages on a stack at once, such as going to a page whose parents
/// are not on it yet, logs each of them, the top one last. Switching
/// between the branches of the main navigation is not a navigation event:
/// a branch logs the pages it starts with when it is first selected, and
/// nothing when it is selected again. When a page shown over the main
/// navigation closes, the observer sees the main navigation come back, not
/// the page of its selected branch, so that page is not logged again
/// either.
///
/// Analytics works on the Firebase app, so the module depends on
/// [FirebaseCoreModule], which initializes Firebase in `bootstrap()`. The
/// service is created on first use, without waiting, and the observers
/// with the router. When the app has a DI container, the role registers
/// the service in it.
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
        // An observer watches one navigator, so the router creates one for
        // each of its navigators.
        const SocketContribution.item(
          RouterRole.observers,
          Fragment(
            '() => FirebaseAnalyticsObserver(analytics: '
            'FirebaseAnalytics.instance)',
            imports: [
              ImportRef(
                'package:firebase_analytics/firebase_analytics.dart',
                show: ['FirebaseAnalytics', 'FirebaseAnalyticsObserver'],
              ),
            ],
          ),
          when: {routerRole},
        ),
      ];
}
