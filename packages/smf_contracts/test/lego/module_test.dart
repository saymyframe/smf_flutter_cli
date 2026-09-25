import 'package:smf_contracts/lego_core.dart';
import 'package:test/test.dart';

import 'support.dart';

List<Contribution> _blocVariant(ModuleContext context) =>
    const [PubspecContribution.hosted('flutter_bloc', 'any')];

void main() {
  final router = TestRole<String>('router');
  final layout = TestRole<NoDsl>('layout', requires: {router});
  final routerWithUses = TestRole<String>('router_uses', uses: {layout});
  final di = TestRole<String>('di');
  final stateManagement = TestRole<NoDsl>('state_management');
  final analytics = TestRole<String>('analytics', uses: {di});

  group('ModuleDescriptor', () {
    test('defaults to no relations', () {
      const descriptor = ModuleDescriptor(
        id: ModuleId('home'),
        description: 'Home',
        kind: plainKind,
      );

      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.providers, isEmpty);
      expect(descriptor.variants, isNull);
      expect(descriptor.sockets, isEmpty);
      expect(descriptor.provides, isEmpty);
      expect(descriptor.roles, isEmpty);
    });

    test('derives the provided roles from its providers', () {
      final descriptor = ModuleDescriptor(
        id: const ModuleId('go_router'),
        description: 'go_router',
        kind: plainKind,
        providers: [RoleProvider<String>.plain(routerWithUses)],
      );

      expect(descriptor.provides, {routerWithUses});
    });

    test('a provider requires and uses what its role does', () {
      final descriptor = ModuleDescriptor(
        id: const ModuleId('bottom_tabs'),
        description: 'Bottom tabs',
        kind: plainKind,
        providers: [RoleProvider<NoDsl>.plain(layout)],
      );

      expect(descriptor.effectiveRequires, {router});
      expect(descriptor.roles, {layout, router});

      final routerModule = ModuleDescriptor(
        id: const ModuleId('go_router'),
        description: 'go_router',
        kind: plainKind,
        providers: [RoleProvider<String>.plain(routerWithUses)],
      );
      expect(routerModule.effectiveUses, {layout});
    });

    test('adds the roles its kind implies and its variants need', () {
      final featureKind = ModuleKind(
        id: 'feature',
        label: 'Features',
        impliedRequires: {router},
      );
      final descriptor = ModuleDescriptor(
        id: const ModuleId('home'),
        description: 'Home',
        kind: featureKind,
        uses: {di, router},
        variants: Variants(
          role: stateManagement,
          byProvider: const {ModuleId('bloc'): _blocVariant},
        ),
      );

      expect(descriptor.effectiveRequires, {router, stateManagement});
      expect(descriptor.effectiveUses, {di}, reason: 'required wins over used');
      expect(descriptor.roles, {router, stateManagement, di});
    });

    test('a role it provides is neither required nor used', () {
      final descriptor = ModuleDescriptor(
        id: const ModuleId('firebase_analytics'),
        description: 'Analytics',
        kind: plainKind,
        requires: {analytics},
        uses: {analytics},
        providers: [RoleProvider<String>.plain(analytics)],
      );

      expect(descriptor.provides, {analytics});
      expect(descriptor.effectiveRequires, isEmpty);
      expect(descriptor.effectiveUses, {di});
    });
  });

  test('Variants holds the contributions of each provider', () {
    final variants = Variants(
      role: stateManagement,
      byProvider: const {ModuleId('bloc'): _blocVariant},
    );

    expect(variants.role, same(stateManagement));
    expect(
      variants.byProvider[const ModuleId('bloc')]!(testContext).single,
      isA<PubspecDependency>(),
    );
  });

  test('SmfModule contributes nothing by default', () {
    const module = TestModule(
      ModuleDescriptor(id: ModuleId('a'), description: 'A', kind: plainKind),
    );

    expect(module.contribute(testContext), isEmpty);
    expect(module.descriptor.id, const ModuleId('a'));
  });

  group('ModuleKind', () {
    const feature = ModuleKind(
      id: 'feature',
      label: 'Features',
      fileRoots: ['lib/features/<id>/'],
      compositionFile: 'lib/features/<id>/<id>_composition.dart',
    );
    const infrastructure = ModuleKind(
      id: 'infrastructure',
      label: 'Infrastructure',
      forbiddenFileRoots: ['lib/features'],
      allowsVariants: false,
    );
    const home = ModuleId('home');

    test('defaults to no rules', () {
      expect(plainKind.impliedProvides, isEmpty);
      expect(plainKind.impliedRequires, isEmpty);
      expect(plainKind.requiredData, isEmpty);
      expect(plainKind.forbiddenData, isEmpty);
      expect(plainKind.allowsVariants, isTrue);
      expect(plainKind.compositionFileOf(home), isNull);
      expect(plainKind.allowsFile(home, 'anything/at/all.dart'), isTrue);
      expect('$plainKind', 'module kind plain');
    });

    test('expands paths for a module', () {
      expect(feature.fileRootsOf(home), ['lib/features/home/']);
      expect(
        feature.compositionFileOf(home),
        'lib/features/home/home_composition.dart',
      );
      expect(infrastructure.forbiddenFileRootsOf(home), ['lib/features']);
      expect(infrastructure.allowsVariants, isFalse);
    });

    test('checks where a module may put files', () {
      expect(feature.allowsFile(home, 'lib/features/home/home.dart'), isTrue);
      expect(feature.allowsFile(home, 'lib/features/other/a.dart'), isFalse);
      expect(feature.allowsFile(home, 'lib/main.dart'), isFalse);
      expect(feature.allowsFile(home, 'lib/features/homepage/a.dart'), isFalse);
      expect(infrastructure.allowsFile(home, 'lib/features_x/a.dart'), isTrue);
      expect(infrastructure.allowsFile(home, 'lib/core/a.dart'), isTrue);
      expect(
        infrastructure.allowsFile(home, 'lib/features/home/a.dart'),
        isFalse,
      );
    });
  });

  test('ModuleContext describes the app', () {
    expect(testContext.appName, 'my_app');
    expect(testContext.orgName, 'com.example');
    expect(testContext.appIdentity.androidApplicationId, 'com.example.my_app');
    expect(testContext.appIdentity.iosBundleId, 'com.example.my-app');
    expect(testContext.appIdentity.androidNamespace, 'com.example.my_app');
  });
}
