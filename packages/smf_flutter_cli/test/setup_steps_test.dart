@TestOn('vm')
library;

import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/setup_steps.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:test/test.dart';

/// The bells of a test app, which any number of modules may provide.
final class _Bells extends Role<NoDsl> {
  const _Bells();

  @override
  String get id => 'bells';

  @override
  String get description => 'Bells';

  @override
  RoleCardinality get cardinality => RoleCardinality.many;
}

const _bells = _Bells();

/// The keys of a test app, which one module provides: their template lists
/// [_cut] in every app with the role, and two more steps in an app without
/// [_bells].
final class _Keys extends Role<NoDsl> {
  const _Keys();

  @override
  String get id => 'keys';

  @override
  String get description => 'House keys';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get uses => const {_bells};

  @override
  RoleTemplate<NoDsl> get template => const _KeysTemplate();
}

const _keys = _Keys();

/// The step of [_keys] that its template and the module `door` list.
const _cut = ManualStepId.role(_keys, 'cut');

final class _KeysTemplate extends RoleTemplate<NoDsl> {
  const _KeysTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) =>
      const [ManualStep(_cut, 'Cut the keys')];

  @override
  List<ManualStep> manualSteps(RoleHookInput<NoDsl> input) => [
        if (!input.has(_bells)) ...const [
          ManualStep(ManualStepId.role(_keys, 'spare'), 'Keep a spare key'),
          ManualStep(ManualStepId.role(_keys, 'label'), 'Label the keys'),
        ],
      ];
}

/// The step [name] of the module [module], titled [title].
ManualStep _step(String module, String name, String title) =>
    ManualStep(ManualStepId(ModuleId(module), name), title);

/// A test module [id] that provides [provides], requires [requires] and
/// lists [steps], and the steps of [variants] by the provider of [_keys].
final class _Module extends SmfModule {
  const _Module(
    this.id, {
    this.provides = const {},
    this.requires = const {},
    this.steps = const [],
    this.variants,
  });

  final String id;
  final Set<Role> provides;
  final Set<Role> requires;
  final List<ManualStep> steps;
  final Map<String, List<ManualStep>>? variants;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: ModuleId(id),
        description: 'Test',
        kind: const ModuleKind(id: 'test', label: 'Test'),
        requires: requires,
        providers: [for (final role in provides) RoleProvider.plain(role)],
        variants: switch (variants) {
          final variants? => Variants(
              role: _keys,
              byProvider: {
                for (final MapEntry(key: provider, value: steps)
                    in variants.entries)
                  ModuleId(provider): (context) => steps,
              },
            ),
          null => null,
        },
      );

  @override
  List<Contribution> contribute(ModuleContext context) => steps;
}

/// The provider of [_bells].
final _tower = _Module(
  'tower',
  provides: const {_bells},
  steps: [_step('tower', 'hang', 'Hang the bells')],
);

/// The modules of the test apps: the two providers of [_keys], `door`,
/// which requires them and lists their [_cut] itself and a step in its
/// variant for `smith`, and [_tower].
final List<SmfModule> _modules = [
  const FlutterCoreModule(),
  _Module(
    'locksmith',
    provides: const {_keys},
    steps: [_step('locksmith', 'sign_up', 'Sign up with the locksmith')],
  ),
  _Module(
    'smith',
    provides: const {_keys},
    steps: [_step('smith', 'forge', 'Light the forge')],
  ),
  _Module(
    'door',
    requires: const {_keys},
    steps: const [ManualStep(_cut, 'Cut the keys')],
    variants: {
      'locksmith': const [],
      'smith': [_step('door', 'hinges', 'Oil the hinges')],
    },
  ),
  _tower,
];

/// A step of a catalog, [id] of the module before its dot, titled [title]
/// and needed by [neededBy].
SetupStep _entry(
  String id, {
  String title = 'Do it by hand',
  List<String>? neededBy,
}) {
  final owner = id.split('.').first;
  return SetupStep(
    id: id,
    title: title,
    owner: owner,
    ownerKind: SetupStepOwnerKind.module,
    ownerName: owner,
    neededBy: neededBy ?? [owner],
  );
}

/// The ids of [steps].
List<String> _ids(List<SetupStep> steps) => [
      for (final step in steps) step.id,
    ];

void main() {
  test(
      'setup_steps.json is the catalog of the steps by hand of the modules '
      'of smf create', () async {
    final committed =
        File(setupStepsFile).readAsStringSync().replaceAll('\r\n', '\n');

    final catalog =
        SetupCatalog.parse(committed).next(await setupStepsOf(smfModules));

    expect(
      catalog.render(),
      committed,
      reason: 'The steps by hand of the modules changed. Run '
          '`dart run tool/setup_steps.dart` in packages/smf_flutter_cli, and '
          'copy $setupStepsFile to src/data/setup-steps.json of the site of '
          'SMF, with a guide for each new step.',
    );
  });

  test(
      'the link to the guide names the steps by their wires, in their '
      'order, with commas between them', () {
    final link = setupGuideLinkOf([
      const ManualStepId(ModuleId('firebase_messaging'), 'apns_key'),
      _cut,
    ]);

    expect(
      '$link',
      'https://doc.saymyframe.com/setup?steps=firebase_messaging.apns_key,'
          'keys.cut',
    );
    expect(link.queryParameters, {
      'steps': 'firebase_messaging.apns_key,keys.cut',
    });
    expect(setupGuidePage, 'https://doc.saymyframe.com/setup');
  });

  group('the steps of the modules', () {
    late List<SetupStep> steps;
    setUpAll(() async => steps = await setupStepsOf(_modules));

    test(
        'are those of the first app with every module in its order, the '
        'next ones of the other apps with every module, and the other steps '
        'by id', () {
      expect(_ids(steps), [
        // The first app with every module has the locksmith, and the steps
        // of roles come first.
        'keys.cut',
        'locksmith.sign_up',
        'tower.hang',
        // The second one has the smith, and the variant of the door for it.
        'smith.forge',
        'door.hinges',
        // Only the apps without bells have them.
        'keys.label',
        'keys.spare',
      ]);
    });

    test(
        'are needed by the modules that list them, a variant counting as its '
        'module, and by the providers of a role whose template lists them', () {
      final neededBy = {for (final step in steps) step.id: step.neededBy};

      expect(neededBy, {
        'keys.cut': ['door', 'locksmith', 'smith'],
        'locksmith.sign_up': ['locksmith'],
        'tower.hang': ['tower'],
        'smith.forge': ['smith'],
        'door.hinges': ['door'],
        'keys.label': ['locksmith', 'smith'],
        'keys.spare': ['locksmith', 'smith'],
      });
    });

    test(
        'have the title and the owner of their id: the id of a module, or '
        'the description of a role', () {
      final byId = {for (final step in steps) step.id: step.toJson()};

      expect(byId['keys.cut'], {
        'id': 'keys.cut',
        'title': 'Cut the keys',
        'owner': 'keys',
        'ownerKind': 'role',
        'ownerName': 'House keys',
        'neededBy': ['door', 'locksmith', 'smith'],
      });
      expect(byId['door.hinges'], {
        'id': 'door.hinges',
        'title': 'Oil the hinges',
        'owner': 'door',
        'ownerKind': 'module',
        'ownerName': 'door',
        'neededBy': ['door'],
      });
    });
  });

  test(
      'two titles of one step in different apps, which the pipeline does not '
      'see, fail the catalog', () async {
    const copy = ManualStepId.role(_keys, 'copy');

    await expectLater(
      setupStepsOf([
        const FlutterCoreModule(),
        const _Module(
          'locksmith',
          provides: {_keys},
          steps: [ManualStep(copy, 'Copy the keys')],
        ),
        const _Module(
          'smith',
          provides: {_keys},
          steps: [ManualStep(copy, 'Copy each key')],
        ),
        _tower,
      ]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Steps by hand have two titles, but the catalog has one for each '
              'step:\n'
              'keys.copy: "Copy the keys" in every module (locksmith), "Copy '
              'each key" in every module (smith)',
        ),
      ),
    );
  });

  test('an app with errors fails the catalog', () async {
    await expectLater(
      setupStepsOf([
        const FlutterCoreModule(),
        _Module('broken', steps: [_step('broken', 'fix', 'fix it.')]),
      ]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            startsWith('The apps of the steps by hand have errors:\n'),
            contains('broken: error [broken]: The title of the step by hand '),
          ),
        ),
      ),
    );
  });

  group('the next catalog', () {
    test(
        'retires the steps that left the apps, and keeps the steps retired '
        'before, in the order of their ids', () {
      final previous = SetupCatalog(
        steps: [
          _entry('push.apns_key', title: 'Give Firebase your push key'),
          _entry('auth.google_sha'),
        ],
        retired: [_entry('maps.api_key')],
      );

      final next = previous.next([_entry('auth.google_sha')]);

      expect(_ids(next.steps), ['auth.google_sha']);
      expect(_ids(next.retired), ['maps.api_key', 'push.apns_key']);
      expect(
        next.retired.last.title,
        'Give Firebase your push key',
        reason: 'A retired step keeps what the catalog had of it.',
      );
    });

    test('takes a retired step back when the apps have it again', () {
      final previous = SetupCatalog(
        retired: [
          _entry('push.apns_key', title: 'Old title'),
          _entry('maps.api_key'),
        ],
      );

      final next = previous.next([
        _entry('push.apns_key', title: 'New title', neededBy: ['push', 'fcm']),
      ]);

      expect(_ids(next.steps), ['push.apns_key']);
      expect(next.steps.single.title, 'New title');
      expect(next.steps.single.neededBy, ['push', 'fcm']);
      expect(_ids(next.retired), ['maps.api_key']);
    });
  });

  test(
      'a catalog renders as JSON indented by two spaces, with its keys in '
      'the order of the site, and parses back', () {
    const text = '''
{
  "steps": [
    {
      "id": "firebase_messaging.apns_key",
      "title": "Give Firebase your Apple push key (APNs key)",
      "owner": "firebase_messaging",
      "ownerKind": "module",
      "ownerName": "firebase_messaging",
      "neededBy": [
        "firebase_messaging"
      ]
    }
  ],
  "retired": [
    {
      "id": "app_entry.ios_app_id",
      "title": "Register the App ID of the iOS app",
      "owner": "app_entry",
      "ownerKind": "role",
      "ownerName": "App entry",
      "neededBy": [
        "apple_sign_in",
        "firebase_messaging"
      ]
    }
  ]
}
''';
    const catalog = SetupCatalog(
      steps: [
        SetupStep(
          id: 'firebase_messaging.apns_key',
          title: 'Give Firebase your Apple push key (APNs key)',
          owner: 'firebase_messaging',
          ownerKind: SetupStepOwnerKind.module,
          ownerName: 'firebase_messaging',
          neededBy: ['firebase_messaging'],
        ),
      ],
      retired: [
        SetupStep(
          id: 'app_entry.ios_app_id',
          title: 'Register the App ID of the iOS app',
          owner: 'app_entry',
          ownerKind: SetupStepOwnerKind.role,
          ownerName: 'App entry',
          neededBy: ['apple_sign_in', 'firebase_messaging'],
        ),
      ],
    );

    expect(catalog.render(), text);
    expect(SetupCatalog.parse(text).render(), text);
    expect(
      const SetupCatalog().render(),
      '{\n  "steps": [],\n  "retired": []\n}\n',
    );
  });
}
