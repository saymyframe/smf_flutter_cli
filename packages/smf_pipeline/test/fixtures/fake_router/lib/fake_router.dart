/// A fake router for the tests of the SMF pipeline. Not a module to use.
///
/// It implements the router role with plain `Navigator`s whose stacks are
/// lists of locations. With a layout, the destinations form the main
/// navigation: the `AppShell` of the layout, with the list of the
/// destinations that the layout role generates, around a navigator for each
/// branch, which it creates when the branch is first selected. It calls
/// every observer factory once for each navigator, tells the screen
/// listeners about the page on top whenever another is on top, each on its
/// own, so that one that throws keeps no other from hearing it, completes a
/// push with the value that the page pops with, closes with the back button
/// of the system the route on top of the innermost navigator that the user
/// sees, such as a dialog, and annotates every screen and parameter with
/// annotations restricted by `@Target`, so a misplaced tag of an annotation
/// socket fails `flutter analyze`. In an app with guards, it asks them
/// through the `GuardedNavigation` of the router role, which keeps what the
/// router comes back to: about the screen it starts on and about each
/// location that it is asked to show, and it tells them of the pages of its
/// stack when one of them changes, and shows the location that they answer,
/// with new navigators for the branches of the main navigation, so that a
/// main navigation that comes back before the transition to that location
/// is over shares no key with the one that leaves.
library;

import 'package:fake_router/bundles/fake_router_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

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
    final prefixes = <String, ImportRef>{};
    String prefixOf(ImportRef import) => prefixes
        .putIfAbsent(
          import.resolveUri(appName),
          () => import.withPrefix('screen${prefixes.length}'),
        )
        .prefix!;

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
    final destinations =
        input.has(layoutRole) ? facade.destinations : const <FacadeRoute>[];
    return RoleOutput(
      fragments: fragments,
      vars: {
        'start': start == null ? '' : 'const ${start.locationClass}()',
        // The screens come with the imports of their files, which the
        // pipeline adds to the file that reads the variable.
        'screen': Fragment(
          cases.isEmpty
              ? 'const ${AppEntryRole.fallbackStartScreen.name}()'
              : 'switch (location) {\n${cases.join('\n')}\n}',
          imports: [...prefixes.values],
        ),
        'destinations': [
          for (final route in destinations) '${route.locationClass}()',
        ].join(', '),
        'shell': _shellOf(destinations),
        // Whether the modules of the app declare guards, which the router
        // then asks.
        'guards': facade.guards.isNotEmpty,
      },
    );
  }

  /// The layout of the main navigation of an app with [destinations], with
  /// the imports of the layout and of the list of the destinations that the
  /// layout role generates, or only the navigator of the branch without
  /// destinations, when the app has no main navigation.
  static Fragment _shellOf(List<FacadeRoute> destinations) {
    if (destinations.isEmpty) return const Fragment('body');
    return Fragment(
      [
        '${LayoutRole.appShell.name}(',
        '  destinations: ${LayoutRole.appDestinations},',
        '  currentIndex: index,',
        '  onSelect: onSelect,',
        '  body: body,',
        ')',
      ].join('\n'),
      imports: [
        ImportRef.app(
          LayoutRole.appShell.importRef.uri,
          show: [LayoutRole.appShell.name],
        ),
        ImportRef.app(
          LayoutRole.destination.importRef.uri,
          show: const [LayoutRole.appDestinations],
        ),
      ],
    );
  }
}
