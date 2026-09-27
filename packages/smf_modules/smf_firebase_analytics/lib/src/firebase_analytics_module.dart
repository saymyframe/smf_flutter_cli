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
/// When the app has a router, the module gives it a listener of the screen
/// the user sees, which logs a screen view each time the router tells it
/// that the screen changed: the first screen of the app, a page that a
/// navigation shows, a page that shows again as the pages above it close,
/// the page on top when it shows another location, and the page of a
/// branch of the main navigation that the user switches to, such as a tab.
/// The name of the screen is the full name of its route, such as
/// `home.home`, or, for a screen that is no route of a module, such as the
/// fallback start screen or the error screen of the router, the path of its
/// location, such as `/`, without the query. A navigation that puts several
/// pages on a stack at once, such as going to a page whose parents are not
/// on it yet, logs only the page on top.
///
/// Analytics works on the Firebase app, so the module depends on
/// [FirebaseCoreModule], which initializes Firebase in `bootstrap()`. The
/// service is created on first use, without waiting, and the first screen
/// shows after `bootstrap()`. When the app has a DI container, the role
/// registers the service in it.
final class FirebaseAnalyticsModule extends SmfModule {
  /// Creates the module.
  const FirebaseAnalyticsModule();

  /// The id of the module.
  static const id = ModuleId('firebase_analytics');

  static const _file = ImportRef.app(
    'core/analytics/firebase_analytics_service.dart',
  );

  /// The listener of the screen that the module gives the router. A screen
  /// that is no route of a module is logged under the path of its location:
  /// the query of a location that the app cannot show may hold anything.
  static const _screenListener = '(route, location) => '
      'FirebaseAnalytics.instance.logScreenView('
      'screenName: route ?? Uri.parse(location).path)';

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
        // The router tells the listener about each screen the user sees.
        const SocketContribution.item(
          RouterRole.screenListeners,
          Fragment(
            _screenListener,
            imports: [
              ImportRef(
                'package:firebase_analytics/firebase_analytics.dart',
                show: ['FirebaseAnalytics'],
              ),
            ],
          ),
          when: {routerRole},
        ),
      ];
}
