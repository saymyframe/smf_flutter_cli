import 'package:smf_contracts/bundles/layout_role_bundle.dart';
import 'package:smf_contracts/lego.dart';

/// The layout role; see [LayoutRole].
const layoutRole = LayoutRole._();

/// The role of the main navigation of the app around its screens, such as
/// a bottom bar with a tab per feature.
///
/// The destinations are the top-level routes with a [Destination], in the
/// order of the features (see [destinationsIn]). The role's template
/// generates `Destination`, a label and an icon, in
/// `lib/core/layout/destination.dart`, and every provider generates the
/// widget [appShell], which shows the selected destination's branch as its
/// `body`. The router builds the shell from the destinations and keeps each
/// branch's stack; without destinations there is no shell.
final class LayoutRole extends Role<NoDsl> {
  const LayoutRole._();

  /// The path of the file with `Destination`.
  static const destinationFile = 'lib/core/layout/destination.dart';

  /// The path of the provider's file with [appShell].
  static const appShellFile = 'lib/core/layout/app_shell.dart';

  /// The widget of the main navigation, created as
  /// `AppShell(destinations: ..., currentIndex: ..., onSelect: ..., body:
  /// ...)`.
  ///
  /// It takes the destinations as a `List<Destination>`, the index of the
  /// selected one, an `onSelect` callback of type `ValueChanged<int>` that
  /// switches to another destination, and the `body`, the widget of the
  /// selected destination's branch.
  static const appShell = RequiredClass(
    'AppShell',
    path: appShellFile,
    namedParameters: ['destinations', 'currentIndex', 'onSelect', 'body'],
  );

  @override
  String get id => 'layout';

  @override
  String get description => 'Layout';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get requires => {routerRole};

  @override
  RoleInterface get interface => const RoleInterface(
        files: [destinationFile],
        symbols: [appShell],
      );

  @override
  RoleTemplate<NoDsl> get template => const _LayoutTemplate();

  /// The routes that are destinations of the main navigation, in order, in
  /// [input], the input of a hook of this role or of its provider.
  List<FacadeRoute> destinationsIn(RoleHookInput<Object> input) =>
      routerRole.facadeOf(input).destinations;
}

final class _LayoutTemplate extends RoleTemplate<NoDsl> {
  const _LayoutTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) =>
      [BrickContribution(layoutRoleBundle)];
}

/// A module's implementation of the [LayoutRole].
///
/// It checks that the app has no more destinations than the layout can
/// show.
abstract base class LayoutProvider extends RoleProvider<NoDsl> {
  /// Allows subclasses to have constant constructors.
  const LayoutProvider();

  @override
  Role<NoDsl> get role => layoutRole;

  /// The most destinations the layout can show, or `null` for any number.
  int? get maxDestinations => null;

  @override
  List<SmfIssue> validate(RoleHookInput<NoDsl> input) {
    final max = maxDestinations;
    final destinations = layoutRole.destinationsIn(input);
    if (max == null || destinations.length <= max) return const [];
    final extra = destinations[max];
    return [
      SmfIssue(
        'The layout can show $max destinations, but the app has '
        '${destinations.length}: '
        '${destinations.map((route) => route.fullPath).join(', ')}.',
        hint: 'Leave out a feature, or remove the destination of a route.',
        origin: ModuleOrigin(extra.feature.module),
      ),
    ];
  }
}
