import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A provider whose hook of the steps by hand throws.
final class _ThrowingSteps extends RoleProvider<NoDsl> {
  _ThrowingSteps(this.role);

  @override
  final Role<NoDsl> role;

  @override
  List<ManualStep> manualSteps(RoleHookInput<NoDsl> input) =>
      throw StateError('no steps');
}

/// Validates an app of [modules], all requested, or of [resolution], for a
/// front end that names the guide of the steps by hand with [setupLink].
ValidationResult _validate(
  List<SmfModule> modules, {
  Resolution? resolution,
  SetupLink? setupLink,
}) {
  final resolved = resolution ?? resolutionOf(modules);
  return validate(
    registry: ModuleRegistry(modules),
    resolution: resolved,
    collection: collect(resolved, testContext),
    context: testContext,
    setupLink: setupLink,
  );
}

/// The issues of [result], each as its origin and message.
List<String> _messages(ValidationResult result) =>
    [for (final issue in result.issues) '${issue.origin}: ${issue.message}'];

/// The steps that [result] planned, each as its id, title and contributors.
List<String> _planned(ValidationResult result) =>
    [for (final step in result.manualSteps) '$step'];

/// The step [name] of the module [module], titled [title].
ManualStep _step(
  String module,
  String name, [
  String title = 'Do it by hand',
]) =>
    ManualStep(ManualStepId(ModuleId(module), name), title);

void main() {
  final entry = scaffold();
  final push = TestRole<NoDsl>('push');

  group('a step', () {
    test('has a name in lower snake_case', () {
      final result = _validate([
        entry,
        TestModule(
          'fcm',
          contributions: [
            _step('fcm', 'apns_key'),
            _step('fcm', 'ApnsKey'),
            _step('fcm', 'apns-key'),
          ],
        ),
      ]);

      String badName(String name) =>
          'fcm: The step by hand fcm.$name of fcm has the name "$name", '
          'which is not lower snake_case: the link to the guide of a step '
          'carries its id as it is.';
      expect(_messages(result), [badName('ApnsKey'), badName('apns-key')]);
      expect(result.issues.first.hint, contains('lower snake_case'));
    });

    test(
        'has an id of the module that lists it, whose variant counts as the '
        'module', () {
      final state = TestRole<NoDsl>('state');
      final home = TestModule(
        'home',
        variants: Variants(
          role: state,
          byProvider: {
            const ModuleId('bloc'): (context) => [
                  _step('home', 'of_variant'),
                  _step('bloc', 'of_provider'),
                ],
          },
        ),
        contributions: [_step('home', 'own')],
      );
      final modules = [
        entry,
        home,
        TestModule('bloc', providers: [RoleProvider.plain(state)]),
        TestModule('thief', contributions: [_step('home', 'own')]),
      ];

      final result = _validate(
        modules,
        resolution: Resolution([
          ResolvedModule(entry, const Requested()),
          ResolvedModule(
            home,
            const Requested(),
            variant: const ModuleId('bloc'),
          ),
          for (final module in modules.skip(2))
            ResolvedModule(module, const Requested()),
        ]),
      );

      expect(_messages(result), [
        equals(
          'home (bloc): The step by hand bloc.of_provider of home (bloc) has '
          'an id of the module bloc, but only bloc gives its steps the ids of '
          'bloc.',
        ),
        equals(
          'thief: The step by hand home.own of thief has an id of the module '
          'home, but only home gives its steps the ids of home.',
        ),
      ]);
      expect(
        result.issues.last.hint,
        'Give the step an id of its own module, or list a step of a role by '
        'the id that the role publishes.',
      );
    });

    test('of the template of a role has no id of a module', () {
      final result = _validate([
        entry,
        TestModule(
          'fcm',
          providers: [
            RoleProvider.plain(
              TestRole<NoDsl>(
                'sign',
                uses: {push},
                template: TestTemplate(
                  contributions: [
                    _step('fcm', 'apns_key'),
                    ManualStep(
                      ManualStepId.role(push, 'apns_key'),
                      'Upload the key',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ]);

      // The step of the role that it uses is fine.
      expect(_messages(result), [
        equals(
          'role:sign: The step by hand fcm.apns_key of role:sign has an id of '
          'the module fcm, but only fcm gives its steps the ids of fcm.',
        ),
      ]);
      expect(
        result.issues.single.hint,
        'The template of a role gives its steps ids of a role, with '
        'ManualStepId.role.',
      );
    });

    test(
        'of a role is listed by a contributor that provides, requires or uses '
        'the role, or by any for a role open to all modules', () {
      final shared = ManualStep(
        ManualStepId.role(push, 'ios_app_id'),
        'In Xcode, sign the iOS app with your paid Apple Developer team',
      );
      const ofEntry = ManualStep(
        ManualStepId.role(appEntryRole, 'ios_app_id'),
        'In Xcode, sign the iOS app with your paid Apple Developer team',
      );
      final result = _validate([
        entry,
        TestModule('fcm', providers: [RoleProvider.plain(push)]),
        TestModule('user', uses: {push}, contributions: [shared, ofEntry]),
        TestModule('stranger', contributions: [shared, ofEntry]),
      ]);

      expect(_messages(result), [
        equals(
          'stranger: stranger lists the step by hand push.ios_app_id of the '
          'push role, but does not provide, require or use it.',
        ),
      ]);
      expect(
        result.issues.single.hint,
        'Add the role to the uses of the module.',
      );
    });

    test(
        'has a title of one line of at most 80 characters, without spaces '
        'around it, that starts with an upper-case letter or with iOS, and '
        'has no final period and no backslash', () {
      final titles = {
        'empty': '',
        'blank': '   ',
        'broken': 'Line\nbreak',
        'returned': 'Carriage\rreturn',
        'spaced': ' Spaced',
        'trailing': 'Spaced ',
        'long': '${'A' * 79}xy',
        'lower': 'lower case',
        'digit': '1Password',
        'period': 'Ends with a period.',
        'slash': r'Back\slash',
        'two': 'two problems.',
        // These are good titles.
        'ios': 'iOS: sign the app with a paid team',
        'accent': 'Écrire la clé',
        'eighty': 'A' * 80,
        // 80 characters, but 159 code units.
        'emoji': 'A${'😀' * 79}',
      };
      final result = _validate([
        entry,
        TestModule(
          'fcm',
          contributions: [
            for (final MapEntry(key: name, value: title) in titles.entries)
              _step('fcm', name, title),
          ],
        ),
      ]);

      const rules = 'a title is one line of at most 80 characters, without '
          'spaces around it, that starts with an upper-case letter or with '
          'iOS, and has no final period and no backslash.';
      String problem(String name, String what) =>
          'fcm: The title of the step by hand fcm.$name of fcm $what: $rules';
      expect(_messages(result), [
        problem('empty', 'is blank'),
        problem('blank', 'is blank'),
        problem('broken', 'has a line break'),
        problem('returned', 'has a line break'),
        problem('spaced', 'has a space at its start or end'),
        problem('trailing', 'has a space at its start or end'),
        problem('long', 'is longer than 80 characters'),
        problem('lower', 'starts with neither an upper-case letter nor iOS'),
        problem('digit', 'starts with neither an upper-case letter nor iOS'),
        problem('period', 'ends with a period'),
        problem('slash', 'has a backslash, which mason may remove'),
        problem(
          'two',
          'starts with neither an upper-case letter nor iOS and ends with a '
              'period',
        ),
      ]);
      expect(
        result.issues.first.hint,
        'Tell what the developer does in a few words; the guide of the step '
        'tells how.',
      );
    });

    test('lists the roles of its when among those of its contributor', () {
      final result = _validate([
        entry,
        TestModule(
          'fcm',
          contributions: [
            ManualStep(
              const ManualStepId(ModuleId('fcm'), 'apns_key'),
              'Upload the key',
              when: {push},
            ),
          ],
        ),
      ]);

      expect(
        _messages(result).single,
        'fcm: fcm lists the push role in the condition of a contribution, but '
        'does not provide, require or use it.',
      );
    });
  });

  group('the hooks of a role', () {
    test('list the steps that depend on the data, before the roles choose', () {
      final steps = <ManualStep>[];
      final template = TestTemplate<String>(steps: steps);
      final role = TestRole<String>('sign', template: template);
      steps.add(
        ManualStep(ManualStepId.role(role, 'app_id'), 'Register the App ID'),
      );
      final provider = TestProvider<String>(
        role,
        steps: [_step('fire', 'apple_provider', 'Turn on Sign in with Apple')],
      );
      final open = TestRole<NoDsl>(
        'everyone',
        openToAllModules: true,
        template: TestTemplate<NoDsl>(),
      );

      final result = _validate([
        entry,
        TestModule('fire', providers: [provider]),
        TestModule(
          'apple',
          requires: {role},
          contributions: [role.data('apple.com')],
        ),
        TestModule('all', providers: [RoleProvider.plain(open)]),
      ]);

      expect(result.issues, isEmpty);
      final input = template.listed.single;
      expect(input.choice, isNull);
      expect(input.data.single.value, 'apple.com');
      // The hooks list the steps, so even those of a role open to all
      // modules get none.
      final ofOpen = (open.template! as TestTemplate<NoDsl>).listed.single;
      expect(ofOpen.manualSetup, same(ManualSetup.none));
      expect(_planned(result), [
        'sign.app_id: Register the App ID (role:sign)',
        'fire.apple_provider: Turn on Sign in with Apple (fire)',
      ]);
      expect(
        [for (final step in result.manualSteps) step.step],
        [steps.single, provider.steps.single],
      );
    });

    test('give steps of roles, which apply as the steps of the modules do', () {
      final steps = <ManualStep>[];
      final role = TestRole<NoDsl>(
        'sign',
        uses: {push},
        template: TestTemplate<NoDsl>(
          steps: [
            ManualStep(ManualStepId.role(push, 'apns_key'), 'Upload the key'),
          ],
        ),
      );
      steps.addAll([
        ManualStep(ManualStepId.role(role, 'app_id'), 'Register the App ID'),
        const ManualStep(
          ManualStepId.role(appEntryRole, 'ios_app_id'),
          'In Xcode, sign the iOS app with your paid Apple Developer team',
        ),
      ]);
      final provider = TestProvider<NoDsl>(role, steps: steps);

      final without = _validate([
        entry,
        TestModule('fire', providers: [provider]),
      ]);
      final withPush = _validate([
        entry,
        TestModule('fire', providers: [provider]),
        TestModule('fcm', providers: [RoleProvider.plain(push)]),
      ]);

      const appId = 'app_entry.ios_app_id: In Xcode, sign the iOS app with '
          'your paid Apple Developer team (fire)';
      expect(without.issues, isEmpty);
      // The step of the push role does not apply without the role.
      expect(_planned(without), [
        'sign.app_id: Register the App ID (fire)',
        appId,
      ]);
      expect(withPush.issues, isEmpty);
      expect(_planned(withPush), [
        'sign.app_id: Register the App ID (fire)',
        appId,
        'push.apns_key: Upload the key (role:sign)',
      ]);
    });

    test('follow the rules of their owners, and give no conditions', () {
      final role = TestRole<NoDsl>(
        'sign',
        template: TestTemplate<NoDsl>(
          steps: [
            _step('fire', 'apple', 'Turn it on'),
            ManualStep(ManualStepId.role(push, 'apns_key'), 'Upload the key'),
          ],
        ),
      );
      final provider = TestProvider<NoDsl>(
        role,
        steps: [
          ManualStep(
            const ManualStepId(ModuleId('fire'), 'apple_revocation'),
            'give the key.',
            when: {push},
          ),
        ],
      );

      final result = _validate([
        entry,
        TestModule('fire', providers: [provider]),
        TestModule('fcm', providers: [RoleProvider.plain(push)]),
      ]);

      expect(_messages(result), [
        equals(
          'role:sign: The step by hand fire.apple of role:sign has an id of '
          'the module fire, but only fire gives its steps the ids of fire.',
        ),
        equals(
          'role:sign: role:sign lists the step by hand push.apns_key of the '
          'push role, but does not provide, require or use it.',
        ),
        equals(
          'fire: The step by hand fire.apple_revocation that the hook of fire '
          'returned has conditions of its own, but a hook returns a step only '
          'in the apps that need it.',
        ),
        startsWith(
          'fire: The title of the step by hand fire.apple_revocation of fire '
          'starts with neither an upper-case letter nor iOS and ends with a '
          'period:',
        ),
      ]);
      expect(
        result.issues[2].hint,
        'Ask for the roles with RoleHookInput.has, and leave the conditions '
        'out.',
      );
      // Validation stops on the errors; the plan has what applies. The
      // template of a role comes after its providers.
      expect(_planned(result), [
        'push.apns_key: Upload the key (role:sign)',
        'fire.apple_revocation: give the key. (fire)',
        'fire.apple: Turn it on (role:sign)',
      ]);
    });

    test('that throws is an issue of its owner', () {
      final role = TestRole<NoDsl>('sign');
      final result = _validate([
        entry,
        TestModule('fire', providers: [_ThrowingSteps(role)]),
      ]);

      expect(_messages(result), [
        equals(
          'fire: The hook of fire that lists the steps by hand failed: Bad '
          'state: no steps',
        ),
      ]);
      expect(result.manualSteps, isEmpty);
    });
  });

  group('the plan', () {
    test(
        'orders the steps by their contributors, after the modules they '
        'depend on, with the steps of roles first', () {
      final shared = ManualStep(
        ManualStepId.role(push, 'ios_app_id'),
        'In Xcode, sign the iOS app with your paid Apple Developer team',
      );
      final result = _validate([
        entry,
        // By name it would come first, but it depends on zeta.
        TestModule(
          'alpha',
          dependsOn: {'zeta'},
          contributions: [_step('alpha', 'first_by_name')],
        ),
        TestModule(
          'zeta',
          contributions: [_step('zeta', 'one'), _step('zeta', 'two')],
        ),
        TestModule(
          'apple',
          uses: {push},
          contributions: [_step('apple', 'provider'), shared],
        ),
        TestModule('fcm', providers: [RoleProvider.plain(push)]),
        TestModule('user', uses: {push}, contributions: [shared]),
      ]);

      expect(result.issues, isEmpty);
      expect(_planned(result), [
        equals(
          'push.ios_app_id: In Xcode, sign the iOS app with your paid Apple '
          'Developer team (apple, user)',
        ),
        'apple.provider: Do it by hand (apple)',
        'zeta.one: Do it by hand (zeta)',
        'zeta.two: Do it by hand (zeta)',
        'alpha.first_by_name: Do it by hand (alpha)',
      ]);
      final first = result.manualSteps.first;
      expect(first.step, same(shared));
      expect(first.contributors, const [
        ModuleOrigin(ModuleId('apple')),
        ModuleOrigin(ModuleId('user')),
      ]);
      expect(
        () => first.contributors.add(const PipelineOrigin()),
        throwsUnsupportedError,
      );
      expect(() => result.manualSteps.add(first), throwsUnsupportedError);
    });

    test(
        'lists a step once for every contributor that lists it, with one '
        'title, and blames the later of two titles', () {
      ManualStep shared(String title) =>
          ManualStep(ManualStepId.role(push, 'ios_app_id'), title);
      final state = TestRole<NoDsl>('state');
      final home = TestModule(
        'home',
        uses: {push},
        variants: Variants(
          role: state,
          byProvider: {
            const ModuleId('bloc'): (context) => [_step('home', 'own')],
          },
        ),
        contributions: [
          _step('home', 'own'),
          _step('home', 'own'),
          shared('Sign the app'),
        ],
      );
      final modules = [
        entry,
        home,
        TestModule('bloc', providers: [RoleProvider.plain(state)]),
        TestModule('fcm', providers: [RoleProvider.plain(push)]),
        // By name it would come first, but it depends on home.
        TestModule(
          'apple',
          dependsOn: {'home'},
          uses: {push},
          contributions: [shared('Sign the iOS app'), shared('Sign the app')],
        ),
        TestModule(
          'twice',
          contributions: [
            _step('twice', 'x', 'One'),
            _step('twice', 'x', 'Two'),
          ],
        ),
      ];

      final result = _validate(
        modules,
        resolution: Resolution([
          ResolvedModule(entry, const Requested()),
          ResolvedModule(
            home,
            const Requested(),
            variant: const ModuleId('bloc'),
          ),
          for (final module in modules.skip(2))
            ResolvedModule(module, const Requested()),
        ]),
      );

      expect(_messages(result), [
        equals(
          'apple: Both home and apple list a step by hand with the id '
          'push.ios_app_id, but with the titles "Sign the app" and "Sign the '
          'iOS app"; the app lists the step once, under one title.',
        ),
        equals(
          'twice: Two steps by hand of twice have the id twice.x, but with '
          'the titles "One" and "Two"; the app lists the step once, under one '
          'title.',
        ),
      ]);
      expect(
        result.issues.first.hint,
        'List the step by the constant that its owner publishes.',
      );
      expect(_planned(result), [
        'push.ios_app_id: Sign the app (home, apple)',
        'home.own: Do it by hand (home, home (bloc))',
        'twice.x: One (twice)',
      ]);
    });

    test('takes no cycle of the order of the steps for a problem', () {
      final x = TestRole<NoDsl>('x');
      final y = TestRole<NoDsl>('y');
      final z = TestRole<NoDsl>('z');
      final result = _validate([
        entry,
        TestModule(
          'c',
          requires: {x},
          providers: [RoleProvider.plain(z)],
          contributions: [_step('c', 'step')],
        ),
        TestModule(
          'b',
          requires: {y},
          providers: [RoleProvider.plain(x)],
          contributions: [_step('b', 'step')],
        ),
        TestModule(
          'a',
          requires: {z},
          providers: [RoleProvider.plain(y)],
          contributions: [_step('a', 'step')],
        ),
      ]);

      expect(result.issues, isEmpty);
      // The contributors on the cycle are ordered by name.
      expect(
        [for (final step in result.manualSteps) '${step.step.id}'],
        ['a.step', 'b.step', 'c.step'],
      );
    });

    test('has no steps for an app without any', () {
      expect(_validate([entry]).manualSteps, isEmpty);
    });

    test(
        'has the link that the front end names for the steps, by their ids '
        'in order', () {
      final asked = <List<ManualStepId>>[];
      Uri link(List<ManualStepId> steps) {
        asked.add(steps);
        return guideOf(steps);
      }

      const appId = ManualStepId.role(appEntryRole, 'ios_app_id');
      final modules = [
        entry,
        TestModule(
          'fcm',
          contributions: [
            _step('fcm', 'apns_key'),
            const ManualStep(appId, 'Sign the iOS app'),
          ],
        ),
      ];

      final result = _validate(modules, setupLink: link);

      expect(result.issues, isEmpty);
      // The steps of roles come first, in the link too.
      expect(asked, [
        [appId, const ManualStepId(ModuleId('fcm'), 'apns_key')],
      ]);
      expect(
        result.setupLink,
        Uri.parse(
          'https://guide.example/setup?steps=app_entry.ios_app_id,fcm.apns_key',
        ),
      );
      // The front end cannot change the steps of the plan.
      expect(() => asked.single.clear(), throwsUnsupportedError);
      expect(result.manualSteps, hasLength(2));

      // A front end that names no page gives the steps no link.
      expect(_validate(modules).setupLink, isNull);
      // An app without steps needs no guide, so the front end is not asked.
      expect(_validate([entry], setupLink: link).setupLink, isNull);
      expect(asked, hasLength(1));
    });
  });
}
