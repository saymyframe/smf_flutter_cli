import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/src/module.dart';
import 'package:test/test.dart';

void main() {
  final variants = <String,
      ({
    FirebaseAnalyticsModule module,
    String stateManagerDependency,
    String otherStateManagerPackage,
    String featureBundle,
    String stateFile,
  })>{
    'bloc': (
      module: FirebaseAnalyticsBlocModule(),
      stateManagerDependency: 'flutter_bloc: ^9.1.1',
      otherStateManagerPackage: 'flutter_riverpod',
      featureBundle: 'smf_firebase_analytics_bloc',
      stateFile: 'features/analytics/cubit/firebase_analytics_cubit.dart',
    ),
    'riverpod': (
      module: FirebaseAnalyticsRiverpodModule(),
      stateManagerDependency: 'flutter_riverpod: ^2.5.1',
      otherStateManagerPackage: 'flutter_bloc',
      featureBundle: 'smf_firebase_analytics_riverpod',
      stateFile: 'features/analytics/providers/analytics_providers.dart',
    ),
  };

  for (final MapEntry(key: name, value: variant) in variants.entries) {
    group('firebase_analytics ($name)', () {
      final module = variant.module;

      test('describes the firebase_analytics module', () {
        final descriptor = module.moduleDescriptor;

        expect(descriptor.name, kFirebaseAnalytics);
        expect(descriptor.dependsOn, contains(kFirebaseCore));
      });

      test('declares firebase_analytics and its own state manager', () {
        final dependencies = module.moduleDescriptor.pubDependency;

        expect(
          dependencies,
          containsAll([
            'firebase_analytics: ^12.0.1',
            variant.stateManagerDependency,
          ]),
        );
        expect(
          dependencies.where(
            (d) => d.startsWith(variant.otherStateManagerPackage),
          ),
          isEmpty,
        );
      });

      test('renders the shared service brick and its feature brick', () {
        final bundles =
            module.brickContributions.map((b) => b.bundle.name).toList();

        expect(bundles, [
          'smf_firebase_analytics_brick',
          variant.featureBundle,
        ]);
      });

      test('keeps the demo feature out of the shared brick', () {
        final shared = module.brickContributions.first.bundle;

        expect(
          shared.files.map((f) => f.path),
          everyElement(isNot(contains('/lib/features/'))),
        );
      });

      test('feature brick holds the screen and its state layer', () {
        final paths =
            module.brickContributions.last.bundle.files.map((f) => f.path);

        expect(
          paths,
          containsAll([
            endsWith('lib/features/analytics/analytics_screen.dart'),
            endsWith('lib/${variant.stateFile}'),
          ]),
        );
      });

      test('registers the analytics service as a core singleton', () {
        final dependencies = [
          for (final group in module.di)
            if (group.scope == DiScope.core) ...group.diDependencies,
        ];

        expect(dependencies, hasLength(1));
        expect(dependencies.single.abstractType, 'IAnalyticsService');
        expect(dependencies.single.bindingType, DiBindingType.singleton);
      });

      test('adds the analytics screen as a main tab', () {
        final routes = module.routes;
        final nested = routes.routes.whereType<NestedRoute>().single;

        expect(routes.initialRoute, '/analytics');
        expect(nested.shellLink.id, RouteShellLink.toMainTabsShell().id);
        expect(nested.children.single.path, '/analytics');
        expect(nested.children.single.screen?.className, 'AnalyticsScreen');
      });
    });
  }
}
