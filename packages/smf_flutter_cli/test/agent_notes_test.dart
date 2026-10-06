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
/// an app with it.
const Map<String, String> _withoutNote = {};

/// Where the repository tells how the notes of the guide are written.
const _convention = 'The convention of the notes is in the AGENTS.md of the '
    'repository, under "Every app gets `AGENTS.md`".';

/// What a module without a note has to do.
const _moduleHint = 'Give `AppEntryRole.agentSections` an `AgentNote` among '
    'the contributions of the module, under the description of its role or, '
    'without a role, under a heading of its own, and keep its text in '
    '`lib/src/agents.dart` of the package. If the module has nothing to tell '
    'a coding agent, put it into `_withoutNote` of this test with the '
    'reason. $_convention';

/// What a role without a note has to do.
const _roleHint = 'Give `AppEntryRole.agentSections` an '
    '`AgentNote.ofRole` among the contributions of the template of the '
    'role, under the description of the role, that tells what the role '
    'guarantees whichever module provides it. If the role has nothing to '
    'tell a coding agent, put it into `_withoutNote` of this test with the '
    'reason. $_convention';

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
/// template, without a note in the guide of any app with it, with the case
/// of the first such app. One that [exempt] has, with the reason, needs no
/// note, and gets a line when it has one in an app, or when it is in no app.
List<String> _missingNotes(
  Iterable<ContractResult> results, {
  required Map<String, String> exempt,
}) {
  // Each one that has to have a note, with the case of the first app with
  // it and what it is told when it has none.
  final expected = <String, (String, String)>{};
  final noted = <String>{};
  for (final result in results) {
    final resolution = result.resolution!;
    final name = result.contractCase.name;
    for (final module in resolution.modules) {
      final who = 'the module ${module.id}';
      expected.putIfAbsent(who, () => (name, _moduleHint));
    }
    for (final role in resolution.presentRoles) {
      if (role.template == null) continue;
      expected.putIfAbsent('the $role', () => (name, _roleHint));
    }
    noted.addAll(_notedIn(result));
  }
  return [
    for (final MapEntry(key: who, value: (name, hint)) in expected.entries)
      if (!noted.contains(who) && !exempt.containsKey(who))
        _missing(who, name, hint),
    for (final who in exempt.keys)
      if (!expected.containsKey(who))
        _exemptButAbsent(who)
      else if (noted.contains(who))
        _exemptButNoted(who),
  ];
}

/// The line of [_missingNotes] for [who], without a note in the guide of any
/// app, which the app of the case [name] has, with the [hint] of what to do.
String _missing(String who, String name, String hint) =>
    'No app with $who has a note of it in its guide for coding agents: see '
    'the app of "$name". $hint';

/// The line of [_missingNotes] for an exemption of [who], which no app has.
String _exemptButAbsent(String who) =>
    '`_withoutNote` has $who, which no app has: it names a module of the CLI '
    'by `the module <id>`, and a role with a template as the messages name '
    'it. Remove the entry.';

/// The line of [_missingNotes] for an exemption of [who], which has a note.
String _exemptButNoted(String who) =>
    '`_withoutNote` has $who, which has a note in the guide for coding '
    'agents of an app. Remove the entry.';

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
/// agents, or without one, which provides [role], if it is set, with a
/// package and a file of its own.
final class _PageKit extends SmfModule {
  const _PageKit({this.note, this.role});

  /// The file of the module in the app.
  static const file = 'lib/core/pages/pages.dart';

  final String? note;
  final _PagesRole? role;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: const ModuleId('page_kit'),
        description: 'Pages',
        kind: ModuleKinds.infrastructure,
        providers: [if (role case final role?) RoleProvider.plain(role)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        if (note case final note?)
          AppEntryRole.agentSections.entry('Pages', AgentNote(note)),
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

void main() {
  late List<ContractResult> results;

  setUpAll(() async => results = await _appsOf(smfModules));

  test(
      'every module that the CLI offers, and every role with a template, has '
      'a note in the guide for coding agents of an app with it', () {
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

    expect(_missingNotes(results, exempt: _withoutNote), isEmpty);
  });

  test(
      'the note of a role names nothing that only a module that provides the '
      'role has: its id, a package it adds, a name of its code or a file of '
      'its own', () {
    expect(
      roleNoteProblems(
        results,
        AppEntryRole.agentSections,
        textOf: (note) => note.text,
      ),
      isEmpty,
      reason: 'The note of a role tells what holds whichever module provides '
          'the role, so that another provider leaves it true. What only a '
          'provider has belongs in the note of that module. $_convention',
    );
  });

  test(
      'the apps have every note of the roles: those for the apps with '
      'another role, and the one of the router role for an app with guards',
      () {
    final contributed = _contributedNotes(results);

    expect(_unreadNotes(results), isEmpty);
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

      expect(_missingNotes(results, exempt: const {}), [
        _missing('the module page_kit', 'page_kit', _moduleHint),
      ]);
      expect(
        _missing('the module page_kit', 'page_kit', 'Do so.'),
        'No app with the module page_kit has a note of it in its guide for '
        'coding agents: see the app of "page_kit". Do so.',
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
        ),
        isEmpty,
      );
    });

    test('a role with a template and without a note', () async {
      const module = _PageKit(
        note: '- With page_kit.',
        role: _silentPagesRole,
      );
      final results = await _appsOf(const [FlutterCoreModule(), module]);

      expect(_missingNotes(results, exempt: const {}), [
        _missing('the pages role', 'page_kit', _roleHint),
      ]);
      expect(_roleHint, contains('AgentNote.ofRole'));
      expect(_roleHint, contains('AGENTS.md'));
      expect(
        _missingNotes(
          await _appsOf(const [
            FlutterCoreModule(),
            _PageKit(note: '- With page_kit.', role: _pagesRole),
          ]),
          exempt: const {},
        ),
        isEmpty,
      );
    });

    test(
        'an exemption of a module or a role that has a note, or that no app '
        'has', () async {
      final silent = await _appsOf(const [
        FlutterCoreModule(),
        _PageKit(role: _silentPagesRole),
      ]);
      const exempt = {
        'the module page_kit': 'It only adds a package.',
        'the pages role': 'A page is a widget, which the code shows.',
      };

      expect(_missingNotes(silent, exempt: exempt), isEmpty);
      expect(
        _missingNotes(
          await _appsOf(const [
            FlutterCoreModule(),
            _PageKit(note: '- With page_kit.', role: _pagesRole),
          ]),
          exempt: {...exempt, 'the module pages': 'It is gone.'},
        ),
        [
          _exemptButNoted('the module page_kit'),
          _exemptButNoted('the pages role'),
          _exemptButAbsent('the module pages'),
        ],
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

      expect(
        [
          for (final result in results)
            for (final issue in result.errors) issue.message,
        ],
        isEmpty,
      );
      const ofFile =
          'names `${_PageKit.file}`, which only page_kit generates and no role '
          'guarantees';
      expect(
        roleNoteProblems(
          results,
          AppEntryRole.agentSections,
          textOf: (note) => note.text,
        ),
        [
          'names page_kit, the id of a module that provides the role',
          'names page_kit_core, a package that page_kit adds',
          'names `PageKit`, which only ${_PageKit.file} of page_kit uses',
          ofFile,
        ].map(
          (problem) =>
              'The note of the pages role under "Pages" $problem (in the app '
              'of page_kit).',
        ),
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
