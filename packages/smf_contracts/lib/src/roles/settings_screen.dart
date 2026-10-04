import 'package:meta/meta.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contracts/src/roles/brick_templates.dart';
import 'package:smf_contracts/src/roles/symbol_uses.dart';

/// The settings screen role; see [SettingsScreenRole].
const settingsScreenRole = SettingsScreenRole._();

/// The role of the settings screen: the screen of the app where the user
/// changes what the modules of the app let them change, such as the theme
/// or the language.
///
/// A module with a setting uses the role and contributes a
/// [SettingsEntry], which names the widget of the setting in a file that
/// the module generates; the template of a role that uses this role may
/// contribute one too. The contributor knows nothing of the screen: its
/// widget requires no arguments, so it needs nothing from the provider,
/// which only shows it.
///
/// A provider is a module with a route that shows the screen, which it
/// names with a [SettingsScreenRoute]; the role requires the router. The
/// screen shows every entry of [entriesIn] once, in that order: the
/// entries of the modules, in the order of the modules, and then those of
/// the templates of roles. It shows them one below the other in a list
/// that scrolls, on a `Material`. The screen sets the width of each entry,
/// the same for every entry, between the same left and right edges, and
/// puts no limit on its height, so an entry is as tall as it takes. The
/// entries need not reach the edges of the list, which may inset them.
///
/// The provider creates the widget of each entry in a file other than
/// that of the widget, through an import of that file with a prefix that
/// no import of another file has, such as `entry0` for the first. So
/// widgets of the same name in the files of different contributors never
/// clash with each other or with the names of the file of the provider.
/// The contract harness checks those imports and creations (the rule
/// `settings_screen.entries_rendered`), so the tests of a module that
/// contributes an entry check it through [entriesIn], not in the files of
/// a provider. What only a running app shows is for a test of the role in
/// running apps: each entry once, their order, the list that scrolls, the
/// `Material`, the width and the height of each.
///
/// How the user gets to the screen is up to the provider and the rest of
/// the app: a provider may make its route a destination of the main
/// navigation, which an app with a layout shows.
final class SettingsScreenRole extends Role<SettingsData> {
  const SettingsScreenRole._();

  @override
  String get id => 'settings_screen';

  @override
  String get description => 'Settings screen';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get requires => {routerRole};

  @override
  RoleTemplate<SettingsData> get template => const _SettingsScreenTemplate();

  @override
  List<ModuleRule<SettingsData>> get moduleRules => const [
        ModuleRule(
          id: 'settings_screen.entries',
          description: 'The bricks of a module generate the file of the '
              'widget of each of its settings entries, and only in an app '
              'with a settings screen if the module only uses the role.',
          check: _checkEntries,
        ),
        ModuleRule(
          id: 'settings_screen.route',
          description: 'The provider of the role, and no other module, '
              'names one route of its own that needs no values as the '
              'settings screen.',
          check: _checkRoute,
        ),
      ];

  @override
  List<StructuralRule<SettingsData>> get structuralRules => const [
        StructuralRule(
          id: 'settings_screen.entry_widgets',
          description: 'The widget of every settings entry is a class in a '
              'file of the contributor of the entry, with a const unnamed '
              'constructor that requires no arguments.',
          check: _checkEntryWidgets,
        ),
        StructuralRule(
          id: 'settings_screen.entries_rendered',
          description: 'The files of the provider of the role create the '
              'widget of every settings entry, through an import of its file '
              'with a prefix of its own.',
          check: _checkEntriesRendered,
        ),
      ];

  /// The entries of the settings screen in [input], the input of a hook of
  /// this role, of its provider, or of a role that requires or uses this
  /// role, in the order the screen shows them.
  ///
  /// The order is part of the contract of the role, so that an app has its
  /// settings in the same order whichever module provides the screen. It is
  /// the order of the data of the role ([RoleHookInput.data]): the entries
  /// of the modules, in the order the modules were selected, and then those
  /// of the templates of roles, in the order of the first provider of each
  /// role. The entries of one contributor keep its order.
  List<SettingsEntry> entriesIn(RoleHookInput<Object> input) => [
        for (final data in dataIn(input))
          if (data.value case final SettingsEntry entry) entry,
      ];

  /// The route of the settings screen in [input], the input of a hook of
  /// this role or of its provider: the route that the provider names with
  /// its [SettingsScreenRoute]. It is `null` if no module names one, or if
  /// the module that does has no route of that name, which the module rule
  /// `settings_screen.route` reports.
  ///
  /// The route is one of the routes of the app, which are data of the
  /// router role. So a hook of another role reads it only if that role
  /// requires or uses the router role too, besides this role; otherwise
  /// this throws an [ArgumentError] once a module names the route.
  ///
  /// The hooks of a role see the data of the role but not its provider, so
  /// this route is how code that knows only the role finds the screen, such
  /// as a test of the role in a running app: at [FacadeRoute.fullPath],
  /// which needs no values, the app shows the screen of the route.
  FacadeRoute? screenIn(RoleHookInput<Object> input) {
    for (final data in dataIn(input)) {
      if ((data.value, data.origin)
          case (
            SettingsScreenRoute(:final name),
            ModuleOrigin(:final module)
          )) {
        return _routeOf(input, module, name);
      }
    }
    return null;
  }
}

/// What the [SettingsScreenRole] takes from the modules of the app: a
/// [SettingsEntry] from a contributor with a setting, and the
/// [SettingsScreenRoute] from the provider of the role.
@immutable
sealed class SettingsData {
  const SettingsData();
}

/// An entry of the settings screen: a widget of its contributor that shows
/// a setting and lets the user change it, such as the theme of the app, or
/// a few settings that belong together.
///
/// The widget is a class in a file of the app that the contributor
/// generates, with a `const` unnamed constructor that requires no
/// arguments, so that the provider of the [SettingsScreenRole], which
/// knows nothing else of the widget, can create it, in a list of constants
/// too, as `const ThemeSetting()`. The screen puts it on a `Material`,
/// sets its width, the same as that of every other entry, and puts no
/// limit on its height, so it may be a `ListTile`, or a column of them,
/// as tall as it takes. The widget counts on nothing else from the
/// screen: it reads and changes its setting itself.
///
/// ```dart
/// settingsScreenRole.data(
///   const SettingsEntry(
///     widget: TypeRef(
///       'ThemeSetting',
///       import: ImportRef.app('core/theme/theme_setting.dart'),
///     ),
///   ),
/// )
/// ```
///
/// The data needs no condition, since it applies only when the role is
/// present. A module that only uses the role generates the file of the
/// widget in a brick with `when: {settingsScreenRole}`, so that an app
/// without a settings screen does not get it; the module rule
/// `settings_screen.entries` reports a brick without it. The template of a
/// role that uses this role does the same for the widget of its entry.
@immutable
final class SettingsEntry extends SettingsData {
  /// Creates the entry that shows [widget].
  const SettingsEntry({required this.widget});

  /// The class of the widget, with the import of its file, a file of the
  /// app such as `ImportRef.app('core/theme/theme_setting.dart')`.
  ///
  /// The module rule `settings_screen.entries` looks for the file among
  /// those of the bricks of the module by its path as text. So the import
  /// spells the path as the brick does, without `.` or `..` segments, and
  /// the brick has the file at a path without variables.
  ///
  /// The provider imports the file with a prefix of its own, so
  /// [ImportRef.prefix] and [ImportRef.show] do not apply.
  final TypeRef widget;

  /// The path of the file of [widget] relative to the project root, such
  /// as `lib/core/theme/theme_setting.dart`, or `null` if [widget] is not
  /// of a file of the app.
  String? get file => switch (widget.import) {
        final import? when import.isAppFile => 'lib/${import.uri}',
        _ => null,
      };

  /// Describes what is wrong with the entry on its own, or returns an
  /// empty list.
  List<String> problems() {
    final outside = 'The widget ${widget.name} of a settings entry must be a '
        'class of a file of the app, imported with ImportRef.app.';
    return [...widget.problems(), if (file == null) outside];
  }

  @override
  String toString() => 'settings entry ${widget.name}';
}

/// The route that shows the settings screen, which the provider of the
/// [SettingsScreenRole] names among its own routes:
///
/// ```dart
/// routerRole.data(RoutesData([Route('/', name: 'settings', ...)])),
/// settingsScreenRole.data(const SettingsScreenRoute('settings')),
/// ```
///
/// The route needs no values, so that code which knows only the role can
/// go to the screen; see [SettingsScreenRole.screenIn].
@immutable
final class SettingsScreenRoute extends SettingsData {
  /// Names the route [name] of the provider as the settings screen.
  const SettingsScreenRoute(this.name);

  /// The name of the route in the module of the provider, as [Route.name]
  /// has it, such as `settings`.
  final String name;

  @override
  String toString() => 'settings screen route "$name"';
}

/// The template of the [SettingsScreenRole], which adds nothing to the app:
/// it checks the data of the role.
final class _SettingsScreenTemplate extends RoleTemplate<SettingsData> {
  const _SettingsScreenTemplate();

  /// Checks what the module rules of the role cannot see from one module:
  /// the entries of every contributor, the templates of roles included, an
  /// entry that is contributed twice, and a route of the screen that no
  /// module names.
  @override
  List<SmfIssue> validate(RoleHookInput<SettingsData> input) {
    // Who contributed each entry first, by its widget and file.
    final contributors = <String, ContributionOrigin?>{};
    return [
      for (final RoleData(:value, :origin) in input.data)
        ...switch (value) {
          final SettingsEntry entry =>
            _entryIssues(entry, origin, contributors),
          SettingsScreenRoute() => _routeIssues(origin),
        },
    ];
  }

  /// The problems of [entry], which [origin] contributes: those of the
  /// entry alone, or else that it was contributed before, as [contributors]
  /// tell, who contributed each entry first, by its widget and file. An
  /// entry without problems that is new goes into [contributors].
  static List<SmfIssue> _entryIssues(
    SettingsEntry entry,
    ContributionOrigin? origin,
    Map<String, ContributionOrigin?> contributors,
  ) {
    final problems = entry.problems();
    if (problems.isNotEmpty) {
      return [
        for (final problem in problems) SmfIssue(problem, origin: origin),
      ];
    }
    final widget = '${entry.widget.name} of ${entry.file}';
    if (!contributors.containsKey(widget)) {
      contributors[widget] = origin;
      return const [];
    }
    return [
      SmfIssue(
        'The settings entry $widget is contributed twice, by '
        '${contributors[widget]} and by $origin.',
        hint: 'The settings screen shows each entry once, so contribute it '
            'once.',
        origin: origin,
      ),
    ];
  }

  /// The problem of a route of the settings screen that [origin] names,
  /// unless a module does: the routes of an app are those of its modules.
  static List<SmfIssue> _routeIssues(ContributionOrigin? origin) => [
        if (origin is! ModuleOrigin)
          SmfIssue(
            'Only the module that provides the $settingsScreenRole names '
            'the route of the settings screen, not $origin.',
            origin: origin,
          ),
      ];
}

/// The route [name] of the module [module] among the routes of the app in
/// [input], or `null` if the module has no route of that name.
FacadeRoute? _routeOf(
  RoleHookInput<Object> input,
  ModuleId module,
  String name,
) {
  for (final feature in routerRole.facadeOf(input).features) {
    if (feature.module != module) continue;
    for (final route in feature.allRoutes) {
      if (route.route.name == name) return route;
    }
  }
  return null;
}

/// The problems of the files of the widgets of the entries of the module
/// of [input]: a file that the bricks of the module, those that apply in
/// the app, do not generate, and a file that an app without a settings
/// screen gets too.
///
/// The template of the role reports an entry outside the app.
List<SmfIssue> _checkEntries(ModuleRuleInput<SettingsData> input) {
  final module = input.module;
  final bricks = input.contributions.whereType<BrickContribution>();
  // A module that provides or requires the role is only in apps with a
  // settings screen, so its bricks need no condition.
  final onlyUses = !module.provides.contains(settingsScreenRole) &&
      !module.requires.contains(settingsScreenRole);
  return [
    for (final data in input.data)
      if (data.value case final SettingsEntry entry when entry.file != null)
        ..._fileIssues(
          entry,
          ModuleOrigin(module.id),
          [
            for (final brick in bricks)
              if (textTemplatesOf([brick]).containsKey(entry.file)) brick,
          ],
          conditional: onlyUses,
        ),
  ];
}

/// The problems of the file of the widget of [entry], an entry of the
/// module [origin] in a file of the app, which [bricks] of the module
/// generate: no brick, or, when the bricks are [conditional] on the role
/// because the module only uses it, a brick without the role in its
/// [Contribution.when].
List<SmfIssue> _fileIssues(
  SettingsEntry entry,
  ModuleOrigin origin,
  List<BrickContribution> bricks, {
  required bool conditional,
}) {
  final path = entry.file;
  final widget = entry.widget.name;
  if (bricks.isEmpty) {
    return [
      SmfIssue(
        'The widget $widget of a settings entry is in $path, which the '
        'bricks of the module do not generate.',
        hint: 'Generate the file in a brick of the module; with when: '
            '{settingsScreenRole}, only an app with a settings screen gets '
            'it.',
        origin: origin,
        path: path,
      ),
    ];
  }
  return [
    for (final brick in bricks)
      if (conditional && !brick.when.contains(settingsScreenRole))
        SmfIssue(
          'The brick ${brick.bundle.name} of the module generates $path, the '
          'file of the widget $widget of a settings entry, in an app without '
          'a settings screen too: the module only uses the '
          '$settingsScreenRole, and the brick does not name it in its when.',
          hint: 'Contribute the brick with when: {settingsScreenRole}, so '
              'that only an app with a settings screen gets the file.',
          origin: origin,
          path: path,
        ),
  ];
}

/// The problems of the routes that the module of [input] names as the
/// settings screen: only the provider of the role names one, exactly one,
/// which is a route of its own that needs no values.
List<SmfIssue> _checkRoute(ModuleRuleInput<SettingsData> input) {
  final module = input.module;
  final origin = ModuleOrigin(module.id);
  final named = [
    for (final data in input.data)
      if (data.value case final SettingsScreenRoute route) route,
  ];
  if (!module.provides.contains(settingsScreenRole)) {
    return [
      if (named.isNotEmpty)
        SmfIssue(
          'The module names the route of the settings screen, which only '
          'the provider of the $settingsScreenRole does.',
          origin: origin,
        ),
    ];
  }
  if (named.length != 1) {
    return [
      SmfIssue(
        'The provider of the $settingsScreenRole names exactly one route as '
        'the settings screen, but the module names ${named.length}.',
        hint: 'Contribute one SettingsScreenRoute with the name of the route '
            'of the screen.',
        origin: origin,
      ),
    ];
  }
  final name = named.single.name;
  final route = _routeOf(input.roleInput, module.id, name);
  if (route == null) {
    return [
      SmfIssue(
        'The module names its route "$name" as the settings screen, but '
        'declares no route of that name.',
        origin: origin,
      ),
    ];
  }
  final required = route.params.where((param) => param.isRequired);
  return [
    if (required.isNotEmpty)
      SmfIssue(
        'The route "$name" (${route.fullPath}) of the settings screen needs '
        '${required.join(', ')}; the settings screen is reached without '
        'values.',
        origin: origin,
      ),
  ];
}

/// Whether [owner], who generated a file, is [contributor], who
/// contributed data: the same module, whichever of its variants, or the
/// template of the same role.
bool _isContributor(
  ContributionOrigin owner,
  ContributionOrigin? contributor,
) =>
    switch ((owner, contributor)) {
      (ModuleOrigin(:final module), ModuleOrigin(module: final other)) =>
        module == other,
      _ => owner == contributor,
    };

/// The problems with the widgets that the entries of [input] name: a widget
/// in a file of another contributor, a class missing from its file, and one
/// that the provider cannot create as a constant without arguments.
///
/// The template of the role reports an entry outside the app.
List<SmfIssue> _checkEntryWidgets(StructuralRuleInput<SettingsData> input) {
  final issues = <SmfIssue>[];
  for (final data in input.roleInput.data) {
    final origin = data.origin;
    if (data.value case SettingsEntry(:final widget, file: final path?)) {
      final owner = input.owners[path];
      if (owner != null && !_isContributor(owner, origin)) {
        issues.add(
          SmfIssue(
            'The widget ${widget.name} of a settings entry of $origin is in '
            '$path, a file of $owner; an entry shows a widget of its own '
            'contributor.',
            origin: origin,
            path: path,
          ),
        );
        continue;
      }
      final symbol = RequiredClass(
        widget.name,
        path: path,
        constConstructor: true,
      );
      for (final issue in symbol.checkIn(input.files)) {
        issues.add(
          SmfIssue(
            issue.message,
            hint: 'The provider of the $settingsScreenRole knows nothing '
                'of the widget of an entry but its class, so the widget '
                'requires no arguments and can be a constant.',
            origin: origin,
            path: path,
          ),
        );
      }
    }
  }
  return issues;
}

/// The entries that the provider of the role does not render: those whose
/// widget none of the files of the provider creates through an import of
/// the file of the widget with a prefix of its own, one that no import of
/// another file has.
///
/// So no provider leaves out an entry that a module declares, or takes the
/// widget of one entry for that of another of the same name, and the tests
/// of the modules need not look into the files of any provider. A file
/// does not import itself, so the widget of an entry is in a file other
/// than the one that creates it. Without the descriptor of a provider in
/// [input], no file renders the entries and there is nothing to check. The
/// template of the role reports an entry outside the app.
List<SmfIssue> _checkEntriesRendered(StructuralRuleInput<SettingsData> input) {
  final providers = {
    for (final module in input.modules)
      if (module.provides.contains(settingsScreenRole)) module.id,
  };
  if (providers.isEmpty) return const [];
  final files = [
    for (final MapEntry(key: path, value: file) in input.files.entries)
      if (input.owners[path] case ModuleOrigin(:final module)
          when providers.contains(module))
        file,
  ];
  final screen = settingsScreenRole.screenIn(input.roleInput);
  return [
    for (final data in input.roleInput.data)
      if (data.value
          case SettingsEntry(widget: TypeRef(:final name), file: final path?)
          when !files.any((file) => invokesThroughOwnPrefix(file, name, path)))
        SmfIssue(
          'The provider of the $settingsScreenRole does not render the '
          'settings entry $name: none of its files creates $name through an '
          'import of $path with a prefix of its own.',
          hint: 'Create the widget of every entry of '
              'SettingsScreenRole.entriesIn() through an import of its file '
              'with a prefix that no import of another file has, such as '
              'entry0, so that widgets of the same name in different files '
              'do not clash.',
          origin: data.origin,
          path: screen?.route.screen.file,
        ),
  ];
}
