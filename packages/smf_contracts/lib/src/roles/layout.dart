import 'package:smf_contracts/bundles/layout_role_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// The layout role; see [LayoutRole].
const layoutRole = LayoutRole._();

/// The role of the main navigation of the app around its screens, such as
/// a bottom bar with a tab per feature.
///
/// The destinations are the top-level routes with a [Destination], in the
/// order of the features (see [destinationsIn]). The role's template
/// generates [destinationFile], whichever provider is selected, with the
/// class [destination], a label and an icon, and with the list
/// [appDestinations] of the destinations of the app. Every provider
/// generates the widget [appShell], which shows the selected destination's
/// branch as its `body`. The router builds the shell with that list and
/// keeps each branch's stack; without destinations there is no shell.
///
/// The label of a destination is a text of its module, which the app shows
/// in its language, so the role uses the [LocalizationRole]. In an app with
/// that role, the label reads from the texts of the app when its module
/// gave them the text, and otherwise it is the English text: in an app
/// without that role, and for a module that does not list it among its
/// roles (see [LocalizationRole.expressionOf]). Either way the label of a
/// destination in the app is a function of a `BuildContext`, so the list of
/// the destinations is a constant, and a layout that calls the function
/// when it builds shows the label in the language that the app is in.
final class LayoutRole extends Role<NoDsl> {
  const LayoutRole._();

  /// The path of the file with [destination] and [appDestinations].
  static const destinationFile = 'lib/core/layout/destination.dart';

  /// The class of a destination in the app, which the role's template
  /// generates: `Destination(label: ..., icon: ...)`, with an `IconData`
  /// icon and a label of the type `String Function(BuildContext context)`,
  /// which returns the text of the item in the language of the app.
  ///
  /// Its constructor is `const`, and the template creates the destinations
  /// as constants in [appDestinations], each with a top-level function as
  /// its label, which lets a release build tree-shake the icon fonts.
  static const destination = RequiredClass(
    'Destination',
    path: destinationFile,
    namedParameters: ['label', 'icon'],
    constConstructor: true,
  );

  /// The name of the list of the destinations of the app, which the role's
  /// template generates in [destinationFile] as
  /// `const List<Destination> appDestinations`: a [destination] for each
  /// route of [destinationsIn], in their order, with its icon and with a
  /// function of the file that returns its label.
  ///
  /// The router gives the list to the shell as its `destinations` and has a
  /// branch for each, in the same order, so it renders neither the labels
  /// nor the icons. The list is empty in an app without destinations.
  static const appDestinations = 'appDestinations';

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
  ///
  /// Wherever it shows the label of a destination, as a text or to the
  /// semantics of the app, it calls `label(context)` of the destination in
  /// the `build` of the widget that shows it, with the context of that
  /// widget. The label is then in the language that the app is in, and the
  /// widget builds again, with the new label, when the language changes. A
  /// layout that keeps what a label returned shows it in the language of
  /// before.
  ///
  /// It keeps `destinations`, `currentIndex` and `onSelect` as public fields
  /// or getters, since code that knows only the role reads them from the
  /// shell, whichever layout provides it: a test of the main navigation
  /// finds a destination among `destinations` by its label and icon,
  /// selects it with `onSelect` as the layout does when the user selects
  /// it, and reads the selected one from `currentIndex`. The `body` is the
  /// widget of the router, which the shell only shows; such code finds what
  /// the shell shows in the widget tree, so the provider may keep `body`
  /// private.
  static const appShell = RequiredClass(
    'AppShell',
    path: appShellFile,
    namedParameters: ['destinations', 'currentIndex', 'onSelect', 'body'],
    getters: ['destinations', 'currentIndex', 'onSelect'],
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
  Set<Role> get uses => {localizationRole};

  @override
  RoleInterface get interface => const RoleInterface(
        files: [destinationFile],
        symbols: [destination, appShell],
      );

  @override
  RoleTemplate<NoDsl> get template => const _LayoutTemplate();

  /// The routes that are destinations of the main navigation, in order, in
  /// [input], the input of a hook of this role or of its provider.
  List<FacadeRoute> destinationsIn(RoleHookInput<Object> input) =>
      routerRole.facadeOf(input).destinations;
}

/// The name of the function of [LayoutRole.destinationFile] that returns
/// the label of [destination], one of [LayoutRole.destinationsIn], for a
/// `BuildContext`. It is named after the location class of the route, as
/// `_homeDetailsLabel` is after `HomeDetailsLocation`, so the names of two
/// destinations differ as those classes do, which the template of the
/// router role checks.
String _labelFunctionOf(FacadeRoute destination) {
  final location = destination.locationClass;
  final name = location.substring(0, location.length - 'Location'.length);
  return '_${name[0].toLowerCase()}${name.substring(1)}Label';
}

final class _LayoutTemplate extends RoleTemplate<NoDsl> {
  const _LayoutTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(layoutRoleBundle),
        AppEntryRole.agentSections.entry(
          layoutRole.description,
          AgentNote.ofRole(_agentNote),
        ),
      ];

  /// The destinations of the app as the items of the list of
  /// [LayoutRole.destinationFile], with the imports of their icons, and the
  /// functions of their labels, each of which reads the text of its module
  /// from the texts of the app, or is its English text; see
  /// [LocalizationRole.expressionOf].
  @override
  RoleOutput render(RoleHookInput<NoDsl> input) {
    final items = <String>[];
    final labels = <String>[];
    final iconImports = <ImportRef>[];
    final textImports = <ImportRef>[];
    for (final route in layoutRole.destinationsIn(input)) {
      final destination = route.route.destination!;
      final function = _labelFunctionOf(route);
      final label = localizationRole.expressionOf(
        input,
        ModuleOrigin(route.feature.module),
        destination.label,
      );
      final icon = destination.icon.code;
      items.add(
        '  ${LayoutRole.destination.name}(label: $function, icon: $icon),',
      );
      labels.add('String $function(BuildContext context) => ${label.code};');
      iconImports.addAll(destination.icon.imports);
      textImports.addAll(label.imports);
    }
    return RoleOutput(
      vars: {
        'destinations': Fragment(items.join('\n'), imports: iconImports),
        // A blank line before each function, the first after the list.
        'labels': Fragment(
          [for (final label in labels) '\n$label'].join('\n'),
          imports: textImports,
        ),
      },
    );
  }
}

/// The parameters of the shell of the main navigation as a note names them:
/// each in inline code, with `and` before the last.
String get _shellParameters {
  final names = [
    for (final name in LayoutRole.appShell.namedParameters) '`$name`',
  ];
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

/// The note of the layout role in the guide for coding agents: who creates
/// the shell of the main navigation, what a destination is and where a new
/// one goes, whichever module provides the role.
final String _agentNote = '''
- `${LayoutRole.appShell.name}` of `${LayoutRole.appShellFile}` only shows the main navigation around the screen of the selected destination. The router creates it, with its $_shellParameters, and keeps the stack of each destination, so keep these parameters. Without destinations, the router creates no `${LayoutRole.appShell.name}`.
- A destination is a `${LayoutRole.destination.name}` in `${LayoutRole.appDestinations}` of `${LayoutRole.destinationFile}`, an icon and a label, for a top-level route that needs no values. The routes below it stay in its stack, and every other top-level route shows over the main navigation.
- The label of a `${LayoutRole.destination.name}` is a top-level function that takes a `BuildContext` and returns the text, so that `${LayoutRole.appDestinations}` stays `const`. Show a label with `destination.label(context)` in the `build` of the widget that shows it, and do not keep what it returned: the text follows the language of the app.
- To add a destination, add its `${LayoutRole.destination.name}` to `${LayoutRole.appDestinations}` with a function for its label, and give the router a branch for it at the same index.
- `go()` to a location in the main navigation selects its destination. From a page shown over the main navigation, `push()` and `replace()` of such a location throw a `StateError`: use `go()`.
''';

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
