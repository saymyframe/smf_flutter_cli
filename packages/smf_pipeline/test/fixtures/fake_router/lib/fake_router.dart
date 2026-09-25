/// A fake router for the tests of the SMF pipeline. Not a module to use.
///
/// It implements the router role with a plain `Navigator` whose stack is a
/// list of locations, calls every observer factory once for its navigator,
/// and annotates every screen and parameter with annotations restricted by
/// `@Target`, so a misplaced tag of an annotation socket fails
/// `flutter analyze`.
library;

import 'package:fake_router/bundles/fake_router_bundle.dart';
import 'package:smf_contracts/lego.dart';

/// A provider of the router role.
final class FakeRouterModule extends SmfModule {
  /// Creates the module.
  const FakeRouterModule();

  /// The id of the module.
  static const id = ModuleId('fake_router');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A plain navigator (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [FakeRouterProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeRouterBundle),
        const PubspecContribution.hosted('meta', 'any'),
      ];
}

/// Renders the screens of the routes and the annotations of the screens.
final class FakeRouterProvider extends RoleProvider<RoutesData> {
  /// Creates the provider.
  const FakeRouterProvider();

  static const _annotations =
      ImportRef.app('core/router/fixture_annotations.dart');

  @override
  Role<RoutesData> get role => routerRole;

  @override
  RoleOutput render(RoleHookInput<RoutesData> input) {
    final facade = routerRole.facadeOf(input);
    final appName = input.context.appName;
    final prefixes = <String, String>{};
    String prefixOf(ImportRef import) => prefixes.putIfAbsent(
          import.resolveUri(appName),
          () => 'screen${prefixes.length}',
        );

    final fragments = <SocketContribution>[];
    final cases = <String>[];
    for (final route in facade.routes) {
      final screen = route.route.screen;
      final own = route.route.params;
      fragments.add(
        SocketContribution.code(
          RouterRole.screenAnnotations(route.screenKey),
          Fragment(
            '@FixtureScreen(${SmfNames.dartString(route.fullName)})',
            imports: const [_annotations],
          ),
        ),
      );
      for (final param in own) {
        fragments.add(
          SocketContribution.code(
            RouterRole.paramAnnotations(route.paramKey(param)),
            Fragment(
              '@FixtureParam(${SmfNames.dartString(param.name)})',
              imports: const [_annotations],
            ),
          ),
        );
      }
      final pattern = own.isEmpty
          ? '${route.locationClass}()'
          : '${route.locationClass}('
              '${own.map((param) => ':final ${param.name}').join(', ')})';
      final widget = '${prefixOf(screen.import)}.${screen.className}';
      final arguments = [
        for (final param in own) '${param.name}: ${param.name}',
      ];
      cases.add(
        arguments.isEmpty
            ? '  $pattern => const $widget(),'
            : '  $pattern => $widget(${arguments.join(', ')}),',
      );
    }

    final start = routerRole.startIn(input);
    return RoleOutput(
      fragments: fragments,
      vars: {
        'imports': [
          for (final MapEntry(key: uri, value: prefix) in prefixes.entries)
            "import '$uri' as $prefix;",
        ].join('\n'),
        'start': start == null ? '' : 'const ${start.locationClass}()',
        'screen': cases.isEmpty
            ? 'const FallbackStartScreen()'
            : 'switch (location) {\n${cases.join('\n')}\n}',
      },
    );
  }
}
