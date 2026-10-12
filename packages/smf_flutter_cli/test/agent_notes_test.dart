@TestOn('vm')
library;

import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The modules and the roles that tell a coding agent nothing, each with the
/// reason: a module by `the module <id>`, and a role as the messages name
/// it, such as `the router role`. Every other module of the CLI, and every
/// other role with a template, has a note in the guide for coding agents of
/// every app with it.
const Map<String, String> _withoutNote = {};

/// The modules whose notes are all for the apps with another role, each by
/// `the module <id>`, with that role and the reason. Such a module has a
/// note in every app with it and with the role, and in no other app.
const Map<String, (Role, String)> _onlyWith = {
  'the module firebase_analytics': (
    routerRole,
    'It tells only of the screen views, which it logs through the router. '
        'What an app without a router does with the analytics is in the '
        'note of the analytics role.',
  ),
};

/// Where the repository tells how the notes of the guide are written.
const _convention = 'The convention of the notes is in the AGENTS.md of the '
    'repository, under "Every app gets `AGENTS.md`".';

/// What a module without a note has to do.
const _moduleHint = 'Give `AppEntryRole.agentSections` an `AgentNote` among '
    'the contributions of the module, under the description of its role or, '
    'without a role, under a heading of its own, and keep its text in '
    '`lib/src/agents.dart` of the package. A module with a note only for '
    'the apps with another role goes into `_onlyWith` of this test, with '
    'that role and the reason, and one with nothing to tell a coding agent '
    'into `_withoutNote`, with the reason. $_convention';

/// What a role without a note has to do.
const _roleHint = 'Give `AppEntryRole.agentSections` an '
    '`AgentNote.ofRole` among the contributions of the template of the '
    'role, under the description of the role, that tells what the role '
    'guarantees whichever module provides it. A role with nothing to tell a '
    'coding agent goes into `_withoutNote` of this test and into '
    '`withoutNote` of `test/roles_test.dart` of `smf_contracts`, with the '
    'reason. $_convention';

/// Why a note of a role may not name what a module has.
const _roleNoteReason = 'The note of a role tells what holds whichever '
    'modules provide the roles, so that another provider leaves it true. '
    'What a module has belongs in the note of that module. If the check '
    'takes a name of Dart or of Flutter for one of a package, pass it in '
    '`allowed` with the reason. $_convention';

/// The apps of the cases of every module and of every role of [modules],
/// and their apps with every module, which have each role that the modules
/// can bring together.
Future<List<ContractResult>> _appsOf(List<SmfModule> modules) async {
  final harness = ContractHarness(ModuleRegistry(modules));
  return [
    ...await harness.checkAll(),
    for (final contractCase in harness.casesOfAll())
      await harness.check(contractCase),
  ];
}

/// Who gave the guide for coding agents of the app of [result] a note: the
/// modules, each as `the module <id>`, and the roles, each as the messages
/// name it.
Set<String> _notedIn(ContractResult result) => {
      for (final (origin, _, _)
          in result.app!.entriesOf(AppEntryRole.agentSections))
        switch (origin) {
          ModuleOrigin(:final module) => 'the module $module',
          RoleTemplateOrigin(:final role) => 'the $role',
          _ => '$origin',
        },
    };

/// What the guides for coding agents of the apps of [results] lack: a line
/// for each module of an app, and for each role of an app that has a
/// template, without a note in the guide of an app with it, with the case
/// of the first such app.
///
/// One that [exempt] has, with the reason, needs no note, and gets a line
/// when it has one in an app. A module that [onlyWith] has, with a role
/// and the reason, needs a note only in the apps with that role, and gets a
/// line when it has one in another app. An entry of either for what no app
/// has gets a line too.
List<String> _missingNotes(
  Iterable<ContractResult> results, {
  required Map<String, String> exempt,
  required Map<String, (Role, String)> onlyWith,
}) {
  // What each one that is in an app is told when it lacks a note.
  final hints = <String, String>{};
  // The case of the first app without a note of each that needs one there,
  // and of the first app with a note of each that needs none there.
  final lacking = <String, String>{};
  final needless = <String, String>{};
  for (final result in results) {
    final resolution = result.resolution!;
    final name = result.contractCase.name;
    final here = {
      for (final module in resolution.modules)
        'the module ${module.id}': _moduleHint,
      for (final role in resolution.presentRoles)
        if (role.template != null) 'the $role': _roleHint,
    };
    hints.addAll(here);
    final noted = _notedIn(result);
    for (final who in here.keys) {
      final needsNote = !exempt.containsKey(who) &&
          (onlyWith[who] == null ||
              resolution.presentRoles.contains(onlyWith[who]!.$1));
      if (needsNote && !noted.contains(who)) {
        lacking.putIfAbsent(who, () => name);
      } else if (!needsNote && noted.contains(who)) {
        needless.putIfAbsent(who, () => name);
      }
    }
  }
  return [
    for (final MapEntry(key: who, value: name) in lacking.entries)
      _missing(who, name, hints[who]!),
    for (final who in {...exempt.keys, ...onlyWith.keys})
      if (!hints.containsKey(who))
        _listedButAbsent(who)
      else if (needless[who] case final name?)
        _listedButNoted(who, name),
  ];
}

/// The line of [_missingNotes] for [who], without a note in the guide of the
/// app of the case [name], with the [hint] of what to do.
String _missing(String who, String name, String hint) =>
    'The guide for coding agents of the app of "$name" has no note of $who. '
    '$hint';

/// The line of [_missingNotes] for an entry of `_withoutNote` or of
/// `_onlyWith` for [who], which no app has.
String _listedButAbsent(String who) =>
    'This test lists $who, which is neither a module of an app nor a role '
    'of an app with a template: a module is named by `the module <id>`, and '
    'a role as the messages name it, such as `the router role`. Remove the '
    'entry of `_withoutNote` or of `_onlyWith`.';

/// The line of [_missingNotes] for an entry of `_withoutNote` or of
/// `_onlyWith` for [who], which has a note in the app of the case [name]
/// though the entry says that it has none there.
String _listedButNoted(String who, String name) =>
    'This test lists $who as one without a note in such an app, but the '
    'guide for coding agents of the app of "$name" has a note of it. Remove '
    'the entry of `_withoutNote` or of `_onlyWith`.';

/// The notes that the templates of roles contribute to the guide for coding
/// agents, also those for the apps with other roles (`when:`), that the
/// guide of no app of [results] has: nothing reads such a note. Each as the
/// role and the text.
Set<(Role, String)> _unreadNotes(Iterable<ContractResult> results) =>
    _contributedNotes(results).keys.toSet().difference(_roleNotes(results));

/// The notes of the templates of roles in the guides of the apps of
/// [results]: the role and the text of each.
Set<(Role, String)> _roleNotes(Iterable<ContractResult> results) => {
      for (final result in results)
        for (final (origin, _, note)
            in result.app!.entriesOf(AppEntryRole.agentSections))
          if (origin case RoleTemplateOrigin(:final role)) (role, note.text),
    };

/// The notes that the templates of the roles of the apps of [results]
/// contribute, whether they apply in the app or not: the role and the text
/// of each, with the roles of the apps that the note is for, if it is not
/// for every app with its role.
Map<(Role, String), Set<Role>> _contributedNotes(
  Iterable<ContractResult> results,
) =>
    {
      for (final result in results)
        for (final Collected(:origin, :contribution) in result.collection!.all)
          if ((origin, contribution)
              case (
                RoleTemplateOrigin(:final role),
                SocketContribution(
                  socket: AppEntryRole.agentSections,
                  entryValue: final AgentNote note,
                ),
              ))
            (role, note.text): contribution.when,
    };

/// What the check of the notes of the roles names once [sentence] stands in
/// a note of [role] in the guides of the apps of [results]: in the first
/// note of the role, or in its note with [marker]. Each thing as the note
/// gives it, with the marks of code around it or without.
List<String> _namedWith(
  Iterable<ContractResult> results,
  Role role,
  String sentence, {
  String marker = '',
}) {
  final target = _roleNotes(results)
      .firstWhere((note) => note.$1 == role && note.$2.contains(marker))
      .$2;
  final named = RegExp(r' names (`[^`]+`|\S+?)(?:,| in its text)');
  return [
    for (final line in roleNoteProblems(
      results,
      AppEntryRole.agentSections,
      textOf: (note) =>
          note.text == target ? '${note.text}\n$sentence' : note.text,
    ))
      named.firstMatch(line)![1]!,
  ];
}

/// What the notes of the providers that modules have variants for name
/// without code that shows it, in the apps of [results]: for each such
/// provider, a line for each name.
///
/// A module with variants writes its code with the package of the provider
/// of their role, as a feature writes the state of its screens with the
/// state manager of the app. The note of such a provider tells how that
/// code is written, and the app of the provider alone has none of it. So a
/// name that the note gives is looked up in the apps in which a module has
/// its variant for the provider: in their Dart files that import a package
/// which the provider adds. A provider that is in no such app is no key of
/// the result, since nothing was looked up for it.
///
/// The names are those of [_namesOfCodeIn], and what a file uses is that of
/// [_usedIn].
Map<ModuleId, List<String>> _unshownNames(Iterable<ContractResult> results) {
  // For each provider: the packages that it adds, its notes by their
  // headings, and what the code with those packages uses.
  final packages = <ModuleId, Set<String>>{};
  final notes = <ModuleId, Set<(String, String)>>{};
  final used = <ModuleId, Set<String>>{};
  // The index of a Dart file, by its text.
  final indexes = <String, DartFileIndex>{};
  for (final result in results) {
    final app = result.app!;
    final providers = {
      for (final module in result.resolution!.modules)
        if (module.variant case final provider?) provider,
    };
    for (final provider in providers) {
      final origin = ModuleOrigin(provider);
      final added = packages.putIfAbsent(provider, () => {})
        ..addAll([
          for (final dependency
              in result.validation!.pubspec.dependencies.values)
            if (dependency.source == PubspecSource.hosted &&
                dependency.origins.contains(origin))
              dependency.package,
        ]);
      notes.putIfAbsent(provider, () => {}).addAll([
        for (final (from, heading, note)
            in app.entriesOf(AppEntryRole.agentSections))
          if (from == origin) (heading, note.text),
      ]);
      final shown = used.putIfAbsent(provider, () => {});
      for (final file in app.files.values) {
        if (!file.isText || !file.path.endsWith('.dart')) continue;
        final index = indexes.putIfAbsent(
          file.text,
          () => DartFileIndexer.index(file.path, file.text),
        );
        final withPackage = index.imports.any(
          (import) => added.any(
            (package) => import.uri.startsWith('package:$package/'),
          ),
        );
        if (withPackage) shown.addAll(_usedIn(index));
      }
    }
  }
  return {
    for (final MapEntry(key: provider, value: ofProvider) in notes.entries)
      provider: [
        for (final (heading, text) in ofProvider)
          for (final name in {..._namesOfCodeIn(text, packages[provider]!)})
            if (!used[provider]!.contains(name))
              _unshown(provider, heading, name, packages[provider]!),
      ],
  };
}

/// The line of [_unshownNames] for [name], which the note of [provider]
/// under [heading] gives and no code with one of [packages] uses.
String _unshown(
  ModuleId provider,
  String heading,
  String name,
  Set<String> packages,
) =>
    'The note of $provider under "$heading" names `$name`, which no Dart '
    'file that imports ${packages.join(' or ')} uses in an app with a '
    'module that has a variant for $provider. Name what the code of such a '
    'variant shows, as that code writes it, or tell it without the name.';

/// The names of code that [markdown] gives in inline code, outside its
/// fenced code blocks: each span as it is, without the `()` of a call, such
/// as `emit` of `emit()`, and `ref.mounted`. A span with a `/` is a path,
/// which the rule `app_entry.agent_guide_paths` checks, and one of
/// [packages] is a package, so neither is a name of code.
Iterable<String> _namesOfCodeIn(String markdown, Set<String> packages) sync* {
  final text = markdown.replaceAll(RegExp(r'```[\s\S]*?```'), '');
  for (final match in RegExp('`([^`]+)`').allMatches(text)) {
    final span = match[1]!;
    if (span.contains('/') || packages.contains(span)) continue;
    yield span.replaceAll('()', '');
  }
}

/// What the code of the Dart file of [index] uses: each type that it
/// names, each name that it reads, and each thing that it calls or
/// accesses, by its name and after its target, such as `mounted` and
/// `ref.mounted`. A file that awaits a call uses `await` too, a keyword
/// that a note gives as code. Comments and the text of strings use
/// nothing.
Set<String> _usedIn(DartFileIndex index) => {
      for (final type in index.typeNames) type.name,
      for (final reference in index.references) reference.name,
      for (final call in index.invocations) ...[
        call.name,
        if (call.target case final target?) '$target.${call.name}',
        if (call.awaited) 'await',
      ],
      for (final access in index.memberAccesses) ...[
        access.name,
        '${access.target}.${access.name}',
      ],
    };

/// Sentences that a note of a role may have: they name what the roles
/// guarantee, and names of Dart and of Flutter, also where only the file of
/// one module has such a name.
const _accepted = <(Role, String)>[
  (themeRole, '- `createLightTheme(context)` returns a `ThemeData`.'),
  (themeRole, '- The mode is `ThemeMode.light` or `ThemeMode.dark`.'),
  (
    themeRole,
    '- Read a color from `Theme.of(context).colorScheme`, never from a '
        '`Color(0xFF2196F3)` of your own.',
  ),
  (
    routerRole,
    '- From a page shown over the main navigation, `push()` throws a '
        '`StateError`.',
  ),
  (routerRole, '- No guard is asked while `routeGuards.isEmpty`.'),
  (
    routerRole,
    '- Close a dialog with `Navigator.of(context).pop()`, and read a number '
        'of a path with `int.tryParse`. `ModalRoute.of(context)` gives the '
        'page on top.',
  ),
  (
    routerRole,
    '- A screen is a `StatelessWidget` or a `StatefulWidget` with a `const` '
        'constructor, and takes a `BuildContext` only in `build()`.',
  ),
  (
    // Plain words of the descriptions of the rules of the role.
    routerRole,
    '- The `routes` of a feature come first, `then` the `route` of the '
        'start, each with a `key`.',
  ),
  (
    layoutRole,
    '- `onSelect` is a `ValueChanged<int>`, a destination shows an `Icon`, '
        'and the bar has `destinations.length` items. `AppShell` puts its '
        '`body` into a `Scaffold`.',
  ),
  (
    analyticsRole,
    '- Pass the `id` of the user, never a name. The parameters of an event '
        'are a `Map<String, Object>` without a `DateTime`.',
  ),
  (
    crashReportingRole,
    '- Pass the `error` with its stack trace. A `FlutterError` and an error '
        'of the `PlatformDispatcher` reach the crash reporter by '
        'themselves.',
  ),
  (
    diRole,
    '- A factory may return a `FutureOr`, and a service is found by its '
        '`Type`. Keep no service in a `static` field: `resetDependencies()` '
        'could not `dispose` of it.',
  ),
  (
    eventsRole,
    '- `on<T>()` returns a `Stream<T>`: keep no `StreamController` of your '
        'own, and cancel the `StreamSubscription` in `dispose()`.',
  ),
  (
    appEntryRole,
    '- The dependencies are in `pubspec.yaml`, the commands in `README.md`, '
        'the lints in `analysis_options.yaml`, and the tests in `test/`, '
        'each a `testWidgets()`.',
  ),
  (
    appEntryRole,
    '- Start-up code goes into `bootstrap()`, never into `main()`: '
        '`runApp()` runs after it, and '
        '`WidgetsFlutterBinding.ensureInitialized()` before it.',
  ),
  (
    localizationRole,
    '- A `Text` shows `context.l10n.<name>`, and the root `MaterialApp` '
        'needs no `Locale` from you.',
  ),
  (
    preferencesRole,
    '- `getString(key)` returns `null` for a key without a value, and '
        '`setString(key, value)` returns a `Future<void>`.',
  ),
  (
    settingsScreenRole,
    '- An entry is a widget with a `const` constructor, such as a '
        '`ListTile` or a `SwitchListTile`.',
  ),
];

/// Sentences that no note of a role may have, each with what the check
/// names in it.
const _refused = <(Role, String, List<String>)>[
  (
    routerRole,
    '- Navigate with the facade, never with a `redirect` of the `GoRouter` '
        'of go_router.',
    ['`GoRouter`', 'go_router'],
  ),
  (
    localizationRole,
    '- The texts are in the ARB files in `lib/l10n/`, from which `gen-l10n` '
        'writes the code, with `intl` for the plurals.',
    ['`lib/l10n/`', '`gen-l10n`', '`intl`'],
  ),
  (
    settingsScreenRole,
    '- `SettingsScreen` shows the entries, each imported with a prefix such '
        'as `entry0`. Open it with `context.nav.settings.settings()`.',
    ['`SettingsScreen`', '`entry0`', '`settings`'],
  ),
  // What the provider of another role has, and a module that a provider
  // depends on.
  (
    themeRole,
    '- The mode is saved by shared_preferences, in a '
        '`SharedPreferencesWithCache`, see '
        '`lib/core/preferences/shared_app_preferences.dart`.',
    [
      '`SharedPreferencesWithCache`',
      '`lib/core/preferences/shared_app_preferences.dart`',
      'shared_preferences',
    ],
  ),
  (
    layoutRole,
    '- With go_router, the tabs are a `StatefulShellRoute` of its '
        '`GoRouter`.',
    ['`StatefulShellRoute`', '`GoRouter`', 'go_router'],
  ),
  (
    analyticsRole,
    '- With get_it, the file of the service is imported as `di0`.',
    ['`di0`', 'get_it'],
  ),
  (
    crashReportingRole,
    '- It needs `firebase_core`: `DefaultFirebaseOptions` of '
        '`lib/firebase_options.dart`, which `flutterfire configure` writes.',
    [
      '`firebase_core`',
      '`DefaultFirebaseOptions`',
      '`lib/firebase_options.dart`',
    ],
  ),
  // A name that the file of another module has too, in the fragment of the
  // provider.
  (
    localizationRole,
    '- Read a text with `AppLocalizations.of(context)`.',
    ['`AppLocalizations`'],
  ),
  // The id of a module in camel case, inside a longer name and in the text.
  (
    preferencesRole,
    '- `SharedPreferences.getInstance()` opens them, or a '
        '`SharedPreferencesAsync`. On Android, `shared_preferences_android` '
        'saves them.',
    [
      '`SharedPreferences`',
      '`SharedPreferencesAsync`',
      '`shared_preferences_android`',
    ],
  ),
  (routerRole, '- GoRouter builds the pages.', ['GoRouter']),
  // Code with a slash that is no path, and with a type between angle
  // brackets.
  (
    routerRole,
    "- A route is a `GoRoute(path: '/home')` in a `List<GoRoute>`.",
    ['`GoRoute`'],
  ),
  (
    routerRole,
    "- As in:\n\n```dart\nGoRouter.of(context).go('/home');\n```",
    ['`GoRouter`'],
  ),
];

/// Sentences about a module that the check does not refuse, because it
/// reads only the files of the apps and the ids of the modules: a widget of
/// Flutter that a provider might show and no file has, a method of a
/// package, and one word of an id of several words.
const _unseen = <(Role, String)>[
  (layoutRole, '- The bar is a `BottomNavigationBar`.'),
  (diRole, '- Register a factory with `registerFactoryParam`.'),
  (analyticsRole, '- Firebase logs the events.'),
];

/// A role whose template has the [note] of the role in the guide for coding
/// agents, or none, and [routerNote] in the guide of an app with a router,
/// which the role then uses.
final class _PagesRole extends Role<NoDsl> {
  const _PagesRole({this.note, this.routerNote});

  /// The note of the role, if it has one.
  final String? note;

  /// The note of the role for the apps with a router, if it has one.
  final String? routerNote;

  @override
  String get id => 'pages';

  @override
  String get description => 'Pages';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get uses => {if (routerNote != null) routerRole};

  @override
  RoleTemplate<NoDsl> get template => _PagesTemplate(this);
}

/// The template of a [_PagesRole], with the notes of [role].
final class _PagesTemplate extends RoleTemplate<NoDsl> {
  const _PagesTemplate(this.role);

  final _PagesRole role;

  @override
  List<Contribution> contribute(ModuleContext context) => [
        if (role.note case final note?)
          AppEntryRole.agentSections.entry('Pages', AgentNote.ofRole(note)),
        if (role.routerNote case final note?)
          AppEntryRole.agentSections.entry(
            'Pages',
            AgentNote.ofRole(note),
            when: {routerRole},
          ),
      ];
}

const _silentPagesRole = _PagesRole();

const _pagesRole = _PagesRole(note: '- A page is a widget.');

/// The role with a note for the apps with a router too.
const _pagesRoleWithRouter = _PagesRole(
  note: '- A page is a widget.',
  routerNote: '- A route shows a page.',
);

/// The role with a note of what only [_PageKit] has: its id, the package it
/// adds, a class of that package and the file it generates.
const _pagesRoleOfPageKit = _PagesRole(
  note: '- The pages are in `${_PageKit.file}`, which page_kit writes with '
      'the `PageKit` of `page_kit_core`.',
);

/// An infrastructure module `page_kit` with [note] in the guide for coding
/// agents, in every app or only in an app with a router ([forRouter]), or
/// without one. It provides [role], if that is set, with a package and a
/// file of its own.
final class _PageKit extends SmfModule {
  const _PageKit({this.note, this.forRouter = false, this.role});

  /// The file of the module in the app.
  static const file = 'lib/core/pages/pages.dart';

  final String? note;
  final bool forRouter;
  final _PagesRole? role;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: const ModuleId('page_kit'),
        description: 'Pages',
        kind: ModuleKinds.infrastructure,
        uses: {if (forRouter) routerRole},
        providers: [if (role case final role?) RoleProvider.plain(role)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        if (note case final note?)
          AppEntryRole.agentSections.entry(
            'Pages',
            AgentNote(note),
            when: {if (forRouter) routerRole},
          ),
        if (role != null) ...[
          const PubspecContribution.hosted('page_kit_core', '^1.0.0'),
          BrickContribution(
            MasonBundle(
              name: 'page_kit',
              description: 'The pages',
              version: '0.1.0',
              files: [
                MasonBundledFile(
                  file,
                  base64.encode(
                    utf8.encode(
                      "import 'package:page_kit_core/page_kit_core.dart';\n"
                      '\n'
                      '/// The pages of the app.\n'
                      'final pages = PageKit();\n',
                    ),
                  ),
                  'text',
                ),
              ],
            ),
          ),
        ],
      ];
}

/// An infrastructure module `state_kit` that provides the state management
/// role with the package `state_kit_core`, and has [note] in the guide for
/// coding agents.
final class _StateKit extends SmfModule {
  const _StateKit(this.note);

  static const id = ModuleId('state_kit');

  final String note;

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'State kit',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(stateManagementRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        const PubspecContribution.hosted('state_kit_core', '^1.0.0'),
        AppEntryRole.agentSections.entry(
          stateManagementRole.description,
          AgentNote(note),
        ),
      ];
}

/// A module `counter` with a variant for [_StateKit], which generates
/// [store], a file with the package of that module, and [log], a file
/// without it.
final class _Counter extends SmfModule {
  const _Counter();

  /// The file of the variant that imports the package.
  static const store = 'lib/core/counter/counter_store.dart';

  /// The file of the variant that does not.
  static const log = 'lib/core/counter/counter_log.dart';

  static const Map<String, String> _files = {
    store: "import 'package:state_kit_core/state_kit_core.dart';\n"
        '\n'
        '/// The count, which `Store.dispose()` would end.\n'
        'class CounterStore extends Store<int> {\n'
        '  /// Loads the count with [read].\n'
        '  Future<void> load(Future<int> Function() read) async {\n'
        '    final count = await read();\n'
        '    if (isOpen) put(count);\n'
        '  }\n'
        '}\n',
    log: '/// What the counter did.\n'
        'final counterLog = <String>[];\n'
        '\n'
        '/// Forgets what the counter did.\n'
        'void dispose() => counterLog.clear();\n',
  };

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: ModuleId('counter'),
        description: 'A counter',
        // Infrastructure has no variants; a kind is data.
        kind: ModuleKind(id: 'with_variants', label: 'With variants'),
        variants: Variants(
          role: stateManagementRole,
          byProvider: {_StateKit.id: _withStateKit},
        ),
      );

  static List<Contribution> _withStateKit(ModuleContext context) => [
        const PubspecContribution.hosted('state_kit_core', 'any'),
        BrickContribution(
          MasonBundle(
            name: 'counter_state_kit',
            description: 'The counter',
            version: '0.1.0',
            files: [
              for (final MapEntry(key: path, value: text) in _files.entries)
                MasonBundledFile(
                  path,
                  base64.encode(utf8.encode(text)),
                  'text',
                ),
            ],
          ),
        ),
      ];

  @override
  List<Contribution> contribute(ModuleContext context) => const [];
}

void main() {
  late List<ContractResult> results;

  setUpAll(() async => results = await _appsOf(smfModules));

  test(
      'every module that the CLI offers, and every role with a template, has '
      'a note in the guide for coding agents of every app with it', () {
    // Every case rendered its app, and every module is in one.
    expect(
      [
        for (final result in results)
          if (result.app == null) result.contractCase.name,
      ],
      isEmpty,
    );
    expect(
      {
        for (final result in results)
          for (final module in result.resolution!.modules) module.id,
      },
      {for (final module in smfModules) module.descriptor.id},
    );

    expect(
      _missingNotes(results, exempt: _withoutNote, onlyWith: _onlyWith),
      isEmpty,
    );
  });

  group('the note of a role', () {
    test(
        'names nothing of the modules behind the roles: no id, no package, '
        'no name of their code and no file of theirs', () {
      expect(
        roleNoteProblems(
          results,
          AppEntryRole.agentSections,
          textOf: (note) => note.text,
        ),
        isEmpty,
        reason: _roleNoteReason,
      );
    });

    test(
        'may name what the roles guarantee, and Dart and Flutter, also what '
        'only the file of one module has of them', () {
      for (final (role, sentence) in _accepted) {
        expect(
          _namedWith(results, role, sentence),
          isEmpty,
          reason: 'The $role: $sentence',
        );
      }
    });

    test(
        'may not name a provider of any role or a module that one depends '
        'on, in any spelling of its id, nor what the code has of its '
        'package', () {
      for (final (role, sentence, named) in _refused) {
        expect(
          _namedWith(results, role, sentence),
          named,
          reason: 'The $role: $sentence',
        );
      }
    });

    test('is read from the render hook of its role too', () {
      expect(
        _namedWith(
          results,
          routerRole,
          '- The top-level `redirect` of the `GoRouter` in `_GoAppRouter` '
          'asks the guards.',
          marker: 'redirectTo',
        ),
        ['`GoRouter`', '`_GoAppRouter`'],
      );
    });

    test('may still tell of a module in words that the check cannot see', () {
      for (final (role, sentence) in _unseen) {
        expect(
          _namedWith(results, role, sentence),
          isEmpty,
          reason: 'The $role: $sentence',
        );
      }
    });
  });

  test(
      'the note of a provider that modules have variants for, as that of a '
      'module that manages state, names only what the code of such a '
      'variant uses', () {
    final roles = {
      for (final module in smfModules)
        if (module.descriptor.variants case final variants?) variants.role,
    };
    final unshown = _unshownNames(results);

    // The screens of a feature keep their state as its variant for the
    // state manager of the app writes it, so the notes of the state
    // managers have code to be held against.
    expect(roles, contains(stateManagementRole));
    // Every provider of such a role is in an app with a module that has a
    // variant for it, so the check read its note.
    expect(unshown.keys.toSet(), {
      for (final module in smfModules)
        if (module.descriptor.provides.any(roles.contains))
          module.descriptor.id,
    });
    expect(
      unshown.values.expand((lines) => lines),
      isEmpty,
      reason: 'The note of such a provider tells how code is written with '
          'its package, and no app of the provider alone has that code. A '
          'name that no module writes in its variant for the provider is '
          'one that nothing checks. $_convention',
    );
  });

  test(
      'the apps have every note of the roles: those for the apps with '
      'another role, and the one of the router role for an app with guards',
      () {
    final contributed = _contributedNotes(results);

    expect(
      _unreadNotes(results),
      isEmpty,
      reason: 'No app has these notes, each of a role and for the apps with '
          'another role (`when:`), so no test reads them. A module of the '
          'CLI has to provide that other role in an app with the role of '
          'the note.',
    );
    // Some are for the apps with another role, as the note of the
    // localization role on the setting of the language is for those with a
    // settings screen.
    expect(
      {
        for (final MapEntry(key: (role, _), value: others)
            in contributed.entries)
          if (others.isNotEmpty) role,
      },
      contains(localizationRole),
    );
    // A note that no template contributes comes from a render hook: the
    // router role tells of the guards only in an app with one.
    final guarded = [
      for (final result in results)
        if (result.resolution!.presentRoles.contains(routerRole) &&
            routerRole
                .facadeOf(routerRole.hookInput(result.hook!))
                .guards
                .isNotEmpty)
          result,
    ];
    expect(guarded, isNotEmpty);
    expect(
      {
        for (final (role, _)
            in _roleNotes(guarded).difference(contributed.keys.toSet()))
          role,
      },
      contains(routerRole),
    );
  });

  group('the check fails on', () {
    test('a module without a note, and tells what to add and where', () async {
      final results = await _appsOf(const [FlutterCoreModule(), _PageKit()]);

      expect(_missingNotes(results, exempt: const {}, onlyWith: const {}), [
        _missing('the module page_kit', 'page_kit', _moduleHint),
      ]);
      expect(
        _missing('the module page_kit', 'page_kit', 'Do so.'),
        'The guide for coding agents of the app of "page_kit" has no note of '
        'the module page_kit. Do so.',
      );
      expect(_moduleHint, contains('AppEntryRole.agentSections'));
      expect(_moduleHint, contains('lib/src/agents.dart'));
      expect(_moduleHint, contains('AGENTS.md'));
      expect(
        _missingNotes(
          await _appsOf(const [
            FlutterCoreModule(),
            _PageKit(note: '- The pages are widgets.'),
          ]),
          exempt: const {},
          onlyWith: const {},
        ),
        isEmpty,
      );
    });

    test(
        'a module whose only note is for the apps with another role, unless '
        'the test lists it with that role', () async {
      const module = _PageKit(note: '- A route shows a page.', forRouter: true);
      final results = await _appsOf(const [
        FlutterCoreModule(),
        module,
        GoRouterModule(),
      ]);
      const listed = {
        'the module page_kit': (routerRole, 'It only tells of the routes.'),
      };

      expect(_missingNotes(results, exempt: const {}, onlyWith: const {}), [
        _missing('the module page_kit', 'page_kit', _moduleHint),
      ]);
      expect(
        _missingNotes(results, exempt: const {}, onlyWith: listed),
        isEmpty,
      );
      // With the role, the module still has to have its note.
      expect(
        _missingNotes(
          await _appsOf(const [
            FlutterCoreModule(),
            _PageKit(),
            GoRouterModule(),
          ]),
          exempt: const {},
          onlyWith: listed,
        ),
        [_missing('the module page_kit', 'every module', _moduleHint)],
      );
    });

    test('a role with a template and without a note', () async {
      const module = _PageKit(
        note: '- With page_kit.',
        role: _silentPagesRole,
      );
      final results = await _appsOf(const [FlutterCoreModule(), module]);

      expect(_missingNotes(results, exempt: const {}, onlyWith: const {}), [
        _missing('the pages role', 'page_kit', _roleHint),
      ]);
      expect(_roleHint, contains('AgentNote.ofRole'));
      expect(_roleHint, contains('test/roles_test.dart'));
      expect(_roleHint, contains('AGENTS.md'));
      expect(
        _missingNotes(
          await _appsOf(const [
            FlutterCoreModule(),
            _PageKit(note: '- With page_kit.', role: _pagesRole),
          ]),
          exempt: const {},
          onlyWith: const {},
        ),
        isEmpty,
      );
    });

    test(
        'an entry of its lists for a module or a role that has a note '
        'where the entry says that it has none, or that no app has', () async {
      final silent = await _appsOf(const [
        FlutterCoreModule(),
        _PageKit(role: _silentPagesRole),
      ]);
      const exempt = {
        'the module page_kit': 'It only adds a package.',
        'the pages role': 'A page is a widget, which the code shows.',
      };
      final noted = await _appsOf(const [
        FlutterCoreModule(),
        _PageKit(note: '- With page_kit.', role: _pagesRole),
        GoRouterModule(),
      ]);

      expect(
        _missingNotes(silent, exempt: exempt, onlyWith: const {}),
        isEmpty,
      );
      expect(
        _missingNotes(
          noted,
          // A role without a template is no role that could have a note.
          exempt: {...exempt, 'the state management role': 'It has none.'},
          onlyWith: const {
            'the module pages': (routerRole, 'It is gone.'),
          },
        ),
        [
          _listedButNoted('the module page_kit', 'page_kit'),
          _listedButNoted('the pages role', 'page_kit'),
          _listedButAbsent('the state management role'),
          _listedButAbsent('the module pages'),
        ],
      );
      // The note of the module is in the apps without a router too.
      expect(
        _missingNotes(
          noted,
          exempt: const {},
          onlyWith: const {
            'the module page_kit': (routerRole, 'It tells of the routes.'),
          },
        ),
        [_listedButNoted('the module page_kit', 'page_kit')],
      );
    });

    test(
        'the note of a role that names its provider, the package and the '
        'class of the provider, and the file that only the provider '
        'generates', () async {
      final results = await _appsOf(const [
        FlutterCoreModule(),
        _PageKit(note: '- With page_kit.', role: _pagesRoleOfPageKit),
      ]);
      const provides = 'a module that provides the pages role';
      const file =
          '`${_PageKit.file}`, which only page_kit generates and no role '
          'guarantees';
      const type =
          '`PageKit`, which only code that imports package:page_kit_core '
          'uses, a package of page_kit, $provides';
      const package =
          '`page_kit_core`, which has the words of page_kit, the id of '
          '$provides';

      expect(
        [
          for (final result in results)
            for (final issue in result.errors) issue.message,
        ],
        isEmpty,
      );
      expect(
        roleNoteProblems(
          results,
          AppEntryRole.agentSections,
          textOf: (note) => note.text,
        ),
        [file, type, package, 'page_kit in its text, the id of $provides'].map(
          (problem) =>
              'The note of the pages role under "Pages" names $problem (in '
              'the app of page_kit).',
        ),
      );
      // What the caller allows is no problem, and what it allows without a
      // need is one.
      expect(
        roleNoteProblems(
          results,
          AppEntryRole.agentSections,
          textOf: (note) => note.text,
          allowed: const {
            _PageKit.file: 'The role is about to guarantee the file.',
            'PageKit': 'The same.',
            'page_kit_core': 'The same.',
            'page_kit': 'The same.',
            'Widget': 'A class of Flutter.',
          },
        ).single,
        '`allowed` has `Widget` ("A class of Flutter."), which no note of a '
        'role names in a way that the check refuses. Remove the entry.',
      );
    });

    test(
        'a name in the note of a provider that no module writes with the '
        'package of the provider in its variant for it', () async {
      const note = '''
With `state_kit_core`:

- The state of a screen is a `Store`, which needs no widget in `${AppEntryRole.mainFile}`.
- After an `await`, a `Store` checks `isOpen` before it calls `put()`. It never calls `Store.dispose()` or `dispose()` itself.

```dart
store.close();
```
''';
      final results = await _appsOf(const [
        FlutterCoreModule(),
        _StateKit(note),
        _Counter(),
      ]);

      expect(
        [
          for (final result in results)
            for (final issue in result.errors) issue.message,
        ],
        isEmpty,
      );
      // The names of the comment of the one file and of the code of the
      // other, which does not import the package. The package, the path
      // and the code of the block are no names that the check reads.
      expect(_unshownNames(results), {
        _StateKit.id: [
          for (final name in ['Store.dispose', 'dispose'])
            _unshown(
              _StateKit.id,
              'State management',
              name,
              {'state_kit_core'},
            ),
        ],
      });
      expect(
        _unshown(_StateKit.id, 'State management', 'dispose', {'a', 'b'}),
        'The note of state_kit under "State management" names `dispose`, '
        'which no Dart file that imports a or b uses in an app with a module '
        'that has a variant for state_kit. Name what the code of such a '
        'variant shows, as that code writes it, or tell it without the name.',
      );
      // Without a module with a variant for it, nothing shows how code is
      // written with the provider, and the check reads no note of it.
      expect(
        _unshownNames(
          await _appsOf(const [FlutterCoreModule(), _StateKit(note)]),
        ),
        isEmpty,
      );
    });

    test('a note of a role for the apps with a role that no app has', () async {
      const module = _PageKit(
        note: '- With page_kit.',
        role: _pagesRoleWithRouter,
      );

      expect(
        _unreadNotes(await _appsOf(const [FlutterCoreModule(), module])),
        {(_pagesRoleWithRouter, '- A route shows a page.')},
      );
      expect(
        _unreadNotes(
          await _appsOf(const [
            FlutterCoreModule(),
            module,
            GoRouterModule(),
          ]),
        ),
        isEmpty,
      );
    });
  });
}
