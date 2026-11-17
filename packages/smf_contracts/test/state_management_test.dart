import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'support.dart';

/// The file of a counter of the app, which keeps a count and whether the
/// counter is paused.
const _counterFile = ImportRef.app('features/counter/counter.dart');

/// The count of the counter as an entry of the role, of the module
/// `counter`.
const _count = SharedState(
  'counterCount',
  listenable: FunctionRef('counterCountListenable', import: _counterFile),
  type: TypeRef('int'),
  description: 'The count; `counter.add()` changes it.',
);

/// Whether the counter is paused, as an entry of the role, of the module
/// `counter`.
const _paused = SharedState(
  'counterPaused',
  listenable: FunctionRef('counterPausedListenable', import: _counterFile),
  type: TypeRef('bool'),
  description: 'Whether the counter is paused; `counter.pause()` changes it.',
);

/// [state] with its name replaced by [name].
SharedState _named(SharedState state, String name) => SharedState(
      name,
      listenable: state.listenable,
      type: state.type,
      nullable: state.nullable,
      description: state.description,
    );

/// The bridges of a provider of the tests, which reads a bridge as
/// `bridges.<name>Bridge`.
final class _Bridges extends StateBridges {
  const _Bridges();

  @override
  Fragment watch(SharedState entry, String child) =>
      Fragment('($child)(bridges.${entry.name}Bridge)');
}

/// A provider of the role in the tests.
const _provider = ModuleDescriptor(
  id: ModuleId('state_kit'),
  description: 'State kit',
  kind: ModuleKinds.infrastructure,
  providers: [RoleProvider<StateData>.plain(stateManagementRole)],
);

/// The module `counter`, which feeds the role.
const _counter = ModuleDescriptor(
  id: ModuleId('counter'),
  description: 'Counter',
  kind: ModuleKinds.infrastructure,
  feeds: {stateManagementRole},
);

/// The messages of [issues].
List<String> _messages(List<SmfIssue> issues) => [
      for (final issue in issues) issue.message,
    ];

/// The input of the hooks of the role in an app with [data].
RoleHookInput<StateData> _input(List<RoleData<Object>> data) =>
    inputOf(stateManagementRole, data: data);

void main() {
  group('the state management role', () {
    test(
        'takes at most one provider and needs no other role, whose values '
        'its feeders give it', () {
      expect(stateManagementRole.id, 'state_management');
      expect('$stateManagementRole', 'state management role');
      expect(stateManagementRole.cardinality, RoleCardinality.atMostOne);
      expect(stateManagementRole.requires, isEmpty);
      expect(stateManagementRole.uses, isEmpty);
      expect(stateManagementRole.feeds, isEmpty);
      // Nothing of the role is in every app: a provider gives its bridges
      // only in an app with values.
      expect(stateManagementRole.sockets, isEmpty);
      expect(stateManagementRole.interface.files, isEmpty);
      expect(stateManagementRole.interface.symbols, isEmpty);
      expect(
        [for (final rule in stateManagementRole.moduleRules) rule.id],
        ['state_management.shared_state'],
      );
      expect(
        [for (final rule in stateManagementRole.structuralRules) rule.id],
        [
          'state_management.listenable_functions',
          'state_management.bridges_rendered',
        ],
      );
    });

    test(
        'has the entries of the modules in their order, then those of the '
        'templates, each with its owner, and the bridges of the provider', () {
      final input = _input([
        dataOf<StateData>(stateManagementRole, _count, module: 'counter'),
        dataOf<StateData>(stateManagementRole, const _Bridges(), module: 'kit'),
        // A variant gives the entries of its module.
        stateManagementRole.data(_paused).withOrigin(
              const ModuleOrigin(
                ModuleId('counter'),
                variant: ModuleId('kit'),
              ),
            ),
        stateManagementRole
            .data(ThemeRole.modeState)
            .withOrigin(const RoleTemplateOrigin(themeRole)),
      ]);

      expect(
        [
          for (final entry in stateManagementRole.sharedStateIn(input))
            '$entry',
        ],
        [
          'entry counterCount of the module counter',
          'entry counterPaused of the module counter',
          'entry themeMode of the template of the theme role',
        ],
      );
      expect(
        stateManagementRole.sharedStateIn(input).first.owner,
        const ModuleOrigin(ModuleId('counter')),
      );
      expect(stateManagementRole.bridgesIn(input), isA<_Bridges>());
      expect(
        stateManagementRole.bridgesIn(
          _input([
            dataOf<StateData>(stateManagementRole, _count, module: 'counter'),
          ]),
        ),
        isNull,
      );
    });
  });

  group('an entry', () {
    test(
        'names the type of its value as its function returns it, and as '
        'code with a prefix writes it', () {
      expect(_count.listenableType, 'ValueListenable<int>');
      expect(_count.typeWith('state0'), 'int');
      expect(ThemeRole.modeState.listenableType, 'ValueListenable<ThemeMode>');
      expect(ThemeRole.modeState.typeWith('state0'), 'state0.ThemeMode');
      expect(
        LocalizationRole.localeState.listenableType,
        'ValueListenable<Locale?>',
      );
      expect(LocalizationRole.localeState.typeWith('s'), 's.Locale?');
      expect(PushRole.addressState.typeWith('s'), 'String?');
      expect('$_count', 'entry counterCount');
    });

    test('has no problems of its own when it keeps to the form', () {
      for (final entry in [
        _count,
        _paused,
        ThemeRole.modeState,
        LocalizationRole.localeState,
        AuthRole.sessionState,
        PurchasesRole.accessState,
        NotificationsRole.permissionState,
        PushRole.addressState,
      ]) {
        expect(entry.problems(), isEmpty, reason: entry.name);
      }
    });

    test(
        'needs a name of letters and digits in lowerCamelCase, a function '
        'in a file of the app, a type and a description of one line of at '
        'most 100 characters', () {
      SharedState entry({
        String name = 'counterCount',
        FunctionRef listenable = const FunctionRef(
          'counterCountListenable',
          import: _counterFile,
        ),
        TypeRef type = const TypeRef('int'),
        String description = 'The count.',
      }) =>
          SharedState(
            name,
            listenable: listenable,
            type: type,
            description: description,
          );

      for (final name in [
        'CounterCount',
        'counter_count',
        '1count',
        '',
        // A word of Dart is no name.
        'class',
      ]) {
        expect(
          entry(name: name).problems(),
          [
            equals(
              'The entry "$name" needs a name in lowerCamelCase of letters and '
              'digits, such as themeMode.',
            ),
          ],
          reason: name,
        );
      }
      expect(
        entry(
          listenable: const FunctionRef(
            'countListenable',
            import: ImportRef('package:counter/counter.dart'),
          ),
        ).problems(),
        [
          equals(
            'The entry "counterCount" reads its value through '
            'countListenable() of package:counter/counter.dart, which is '
            'no file of the app.',
          ),
        ],
      );
      expect(
        entry(type: const TypeRef('_Count')).problems(),
        ['The type "_Count" is not a public Dart type name.'],
      );
      expect(
        entry(
          listenable: const FunctionRef('count-of', import: _counterFile),
        ).problems(),
        ['The function "count-of" is not a public Dart function name.'],
      );
      expect(
        entry(description: ' ').problems(),
        ['The entry "counterCount" has no description.'],
      );
      for (final description in [' The count.', 'The\ncount.', 'The\rcount']) {
        expect(
          entry(description: description).problems(),
          [
            equals(
              'The entry "counterCount" has a description that is not one line '
              'of text without spaces around it.',
            ),
          ],
          reason: description,
        );
      }
      expect(entry(description: 'a' * 100).problems(), isEmpty);
      expect(
        entry(description: 'a' * 101).problems(),
        [
          equals(
            'The entry "counterCount" has a description of 101 characters; at '
            'most 100 fit.',
          ),
        ],
      );
    });
  });

  group('the rule state_management.shared_state', () {
    /// The issues of [module] in an app with the [data] that it gives the
    /// role, whose contributions are that data, and with the entry of the
    /// theme role.
    List<SmfIssue> check(ModuleDescriptor module, List<StateData> data) {
      final given = [
        for (final value in data)
          dataOf<StateData>(
            stateManagementRole,
            value,
            module: module.id.value,
          ),
      ];
      return stateManagementRole.checkModule(
        ModuleRuleRequest(
          hook: RoleHookRequest(
            data: [
              ...given,
              stateManagementRole
                  .data(ThemeRole.modeState)
                  .withOrigin(const RoleTemplateOrigin(themeRole)),
            ],
            presentRoles: {stateManagementRole},
            context: testContext,
          ),
          module: module,
          contributions: given,
        ),
      );
    }

    test(
        'passes the entries of a module, and the bridges of a provider, '
        'once', () {
      expect(check(_counter, const [_count, _paused]), isEmpty);
      expect(check(_provider, const [_Bridges()]), isEmpty);
      // A provider may keep a value of its own too.
      expect(
        check(_provider, [const _Bridges(), _named(_count, 'stateKitCount')]),
        isEmpty,
      );
    });

    test(
        'reports an entry whose name does not start with the id of its '
        'owner and another word, two entries of one name, and the problems '
        'of an entry on its own, all as problems of the module', () {
      final issues = check(_counter, [
        _named(_count, 'count'),
        _named(_count, 'counter'),
        _named(_count, 'counterscount'),
        _named(_count, 'counter2'),
        _paused,
        _paused,
        _named(_paused, 'counter_paused'),
      ]);

      expect(_messages(issues), [
        equals(
          'The entry "count" does not start with counter, the id of its owner '
          'in lowerCamelCase, and another word.',
        ),
        equals(
          'The entry "counter" does not start with counter, the id of its '
          'owner in lowerCamelCase, and another word.',
        ),
        equals(
          'The entry "counterscount" does not start with counter, the id of '
          'its owner in lowerCamelCase, and another word.',
        ),
        // A digit starts another word.
        'Two entries are named "counterPaused".',
        equals(
          'The entry "counter_paused" needs a name in lowerCamelCase of '
          'letters and digits, such as themeMode.',
        ),
      ]);
      for (final issue in issues) {
        expect(issue.origin, const ModuleOrigin(ModuleId('counter')));
        expect(issue.isError, isTrue);
      }
      // The id of a module of several words starts its entries as one
      // word in lowerCamelCase.
      const shop = ModuleDescriptor(
        id: ModuleId('shop_cart'),
        description: 'Cart',
        kind: ModuleKinds.infrastructure,
        feeds: {stateManagementRole},
      );
      expect(check(shop, [_named(_count, 'shopCartTotal')]), isEmpty);
      expect(
        _messages(check(shop, [_named(_count, 'shopTotal')])),
        [
          equals(
            'The entry "shopTotal" does not start with shopCart, the id of its '
            'owner in lowerCamelCase, and another word.',
          ),
        ],
      );
    });

    test(
        'reports bridges from a module that does not provide the role, and '
        'a provider that gives none or more than one', () {
      final fromFeeder = check(_counter, const [_count, _Bridges()]);
      expect(_messages(fromFeeder), [
        equals(
          'The module gives the state management role StateBridges, which only '
          'a provider of the role gives.',
        ),
      ]);
      expect(fromFeeder.single.origin, const ModuleOrigin(ModuleId('counter')));

      for (final bridges in [
        const <StateData>[],
        const [_Bridges(), _Bridges()],
      ]) {
        final issues = check(_provider, bridges);
        expect(
          _messages(issues),
          [
            equals(
              'A provider of the state management role gives it StateBridges '
              'once, but the module gives them ${bridges.length} times.',
            ),
          ],
        );
        expect(issues.single.hint, contains('watch()'));
        expect(
          issues.single.origin,
          const ModuleOrigin(ModuleId('state_kit')),
        );
      }
    });
  });

  group('the template of the role', () {
    test(
        'tells coding agents how a value of a controller reaches the state '
        'manager, in a note of the role in every app with it', () {
      final contributions =
          stateManagementRole.template.contribute(testContext);
      final note = contributions.single as SocketContribution;

      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, 'State management');
      expect(note.when, isEmpty);
      final value = note.entryValue! as AgentNote;
      expect(value.isOfRole, isTrue);
      expect(agentNoteOf(stateManagementRole), value);
      // It names no file and no code, which depend on the provider.
      expect(codeSpansOf(value.text), isEmpty);
      expect(value.text, contains('bridge'));
      expect(value.text, contains('only through its controller'));
    });

    /// The issues of the template in an app with [data].
    List<SmfIssue> validate(List<RoleData<Object>> data) =>
        stateManagementRole.template.validate(_input(data));

    test(
        'passes the entries of the templates of roles and of modules that '
        'differ in their names', () {
      expect(
        validate([
          dataOf<StateData>(stateManagementRole, _count, module: 'counter'),
          for (final (role, state) in <(Role, SharedState)>[
            (themeRole, ThemeRole.modeState),
            (localizationRole, LocalizationRole.localeState),
            (authRole, AuthRole.sessionState),
            (purchasesRole, PurchasesRole.accessState),
            (notificationsRole, NotificationsRole.permissionState),
            (pushRole, PushRole.addressState),
          ])
            stateManagementRole
                .data(state)
                .withOrigin(RoleTemplateOrigin(role)),
        ]),
        isEmpty,
      );
    });

    test(
        'reports the problems of the entries of a template of a role, and '
        'bridges from it, as problems of the template', () {
      const theme = RoleTemplateOrigin(themeRole);
      final issues = validate([
        stateManagementRole.data(_count).withOrigin(theme),
        stateManagementRole.data(const _Bridges()).withOrigin(theme),
      ]);

      expect(_messages(issues), [
        equals(
          'The template of the theme role gives the state management role '
          'StateBridges, which only a provider of the role gives.',
        ),
        equals(
          'The entry "counterCount" does not start with theme, the id of its '
          'owner in lowerCamelCase, and another word.',
        ),
      ]);
      for (final issue in issues) {
        expect(issue.origin, theme);
      }
    });

    test(
        'reports two entries of one name from different owners, as a '
        'problem of the later module, or of the module when the other is a '
        'template', () {
      // The role push gives pushAddress, and a module push_address may give
      // an entry that starts with its id too.
      final pushAddress = _named(PushRole.addressState, 'pushAddress');
      final modules = validate([
        dataOf<StateData>(stateManagementRole, _count, module: 'counter'),
        dataOf<StateData>(stateManagementRole, _count, module: 'tally'),
      ]);
      expect(_messages(modules), [
        equals(
          'Both the module counter and the module tally give the state '
          'management role the entry counterCount.',
        ),
      ]);
      expect(modules.single.origin, const ModuleOrigin(ModuleId('tally')));
      expect(modules.single.hint, 'Rename one of the entries.');

      final withTemplate = validate([
        dataOf<StateData>(
          stateManagementRole,
          pushAddress,
          module: 'push_address',
        ),
        stateManagementRole
            .data(PushRole.addressState)
            .withOrigin(const RoleTemplateOrigin(pushRole)),
      ]);
      expect(_messages(withTemplate), [
        equals(
          'Both the module push_address and the template of the push messages '
          'role give the state management role the entry pushAddress.',
        ),
      ]);
      expect(
        withTemplate.single.origin,
        const ModuleOrigin(ModuleId('push_address')),
      );
      // Two entries of one name of one module are for the module rule.
      expect(
        validate([
          dataOf<StateData>(stateManagementRole, _count, module: 'counter'),
          dataOf<StateData>(stateManagementRole, _count, module: 'counter'),
        ]),
        isEmpty,
      );
    });
  });

  group('the structural rules', () {
    const counterPath = 'lib/features/counter/counter.dart';
    const bridgesPath = 'lib/core/state/bridges.dart';
    const kit = ModuleOrigin(ModuleId('state_kit'));
    const counter = ModuleOrigin(ModuleId('counter'));

    /// A function [name] of the file of the counter, which returns [type].
    IndexedDeclaration function(
      String name, {
      String? type,
      List<IndexedParameter> parameters = const [],
    }) =>
        IndexedDeclaration(
          name: name,
          kind: DeclarationKind.function,
          type: type,
          parameters: parameters,
        );

    /// The issues of the rules of the role in an app where the module
    /// counter gives the role [entries] and generates [counterFile], and
    /// the provider of the role, unless [withProvider] is `false`,
    /// generates [bridges].
    List<SmfIssue> check({
      List<SharedState> entries = const [_count, _paused],
      DartFileIndex? counterFile,
      DartFileIndex? bridges,
      bool withProvider = true,
    }) =>
        stateManagementRole.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: [
                for (final entry in entries)
                  dataOf<StateData>(
                    stateManagementRole,
                    entry,
                    module: 'counter',
                  ),
              ],
              presentRoles: {stateManagementRole},
              context: testContext,
            ),
            files: {
              counterPath: counterFile ??
                  DartFileIndex(
                    path: counterPath,
                    declarations: [
                      function(
                        'counterCountListenable',
                        type: 'ValueListenable<int>',
                      ),
                      function(
                        'counterPausedListenable',
                        type: 'ValueListenable<bool>',
                      ),
                    ],
                  ),
              if (bridges != null) bridgesPath: bridges,
            },
            owners: {
              counterPath: counter,
              if (bridges != null) bridgesPath: kit,
            },
            modules: [
              if (withProvider) _provider,
              _counter,
            ],
          ),
        );

    /// The file of the bridges of the provider, which imports the file of
    /// the counter with the prefix `state0`, tears off the function of the
    /// count and calls the function of the pause through it.
    const rendered = DartFileIndex(
      path: bridgesPath,
      imports: [
        IndexedImport(
          'package:my_app/features/counter/counter.dart',
          prefix: 'state0',
        ),
      ],
      memberAccesses: [
        IndexedMemberAccess('state0', 'counterCountListenable'),
      ],
      invocations: [
        IndexedInvocation('counterPausedListenable', target: 'state0'),
      ],
    );

    test(
        'pass an app whose functions return the listenables of their entries '
        'and whose provider follows each', () {
      expect(check(bridges: rendered), isEmpty);
      // The file of the bridges may import the file without a prefix.
      expect(
        check(
          bridges: const DartFileIndex(
            path: bridgesPath,
            imports: [IndexedImport('../../features/counter/counter.dart')],
            references: [IndexedReference('counterCountListenable')],
            invocations: [IndexedInvocation('counterPausedListenable')],
          ),
        ),
        isEmpty,
      );
      // Without a provider, nothing renders the entries.
      expect(check(withProvider: false), isEmpty);
    });

    test(
        'report a function that is missing, needs arguments, or returns '
        'another type than a listenable of its entry, as a problem of the '
        'owner of the entry', () {
      final issues = check(
        bridges: rendered,
        counterFile: DartFileIndex(
          path: counterPath,
          declarations: [
            function(
              'counterCountListenable',
              type: 'ValueListenable<bool>',
              parameters: const [
                IndexedParameter(
                  'counter',
                  kind: ParameterKind.requiredPositional,
                ),
              ],
            ),
          ],
        ),
      );

      expect(_messages(issues), [
        equals(
          'The function of the entry counterCount of the module counter: '
          'function counterCountListenable() in $counterPath must return '
          'ValueListenable<int>, not ValueListenable<bool>.',
        ),
        equals(
          'The function of the entry counterCount of the module counter: '
          'function counterCountListenable() in $counterPath must not '
          'require more than 0 positional arguments.',
        ),
        equals(
          'The function of the entry counterPaused of the module counter: '
          '$counterPath does not declare function '
          'counterPausedListenable().',
        ),
      ]);
      for (final issue in issues) {
        expect(issue.origin, counter);
        expect(issue.path, counterPath);
      }
      expect(issues.first.hint, contains('ValueListenable<int>'));
      // A nullable value has the `?` in the type that its function returns.
      expect(
        _messages(
          check(
            entries: [
              SharedState(
                'counterCount',
                listenable: _count.listenable,
                type: _count.type,
                nullable: true,
                description: _count.description,
              ),
            ],
            bridges: rendered,
          ),
        ),
        [
          equals(
            'The function of the entry counterCount of the module counter: '
            'function counterCountListenable() in $counterPath must return '
            'ValueListenable<int?>, not ValueListenable<int>.',
          ),
        ],
      );
    });

    test(
        'report an entry that no file of the provider follows, as a problem '
        'of the provider', () {
      final issues = check(
        bridges: const DartFileIndex(
          path: bridgesPath,
          imports: [
            IndexedImport(
              'package:my_app/features/counter/counter.dart',
              prefix: 'state0',
            ),
          ],
          // A function of the same name of another file is not the one of
          // the entry.
          invocations: [
            IndexedInvocation('counterPausedListenable', target: 'other'),
          ],
          memberAccesses: [
            IndexedMemberAccess('state0', 'counterCountListenable'),
          ],
        ),
      );

      expect(_messages(issues), [
        equals(
          'The provider of the state management role does not render the entry '
          'counterPaused of the module counter: none of its files calls or '
          'tears off counterPausedListenable() of $counterPath.',
        ),
      ]);
      expect(issues.single.origin, kit);
      expect(issues.single.hint, contains('sharedStateIn()'));
      // A provider that renders nothing renders no entry.
      expect(check(), hasLength(2));
    });

    test(
        'leave the function of an entry outside the app to the module rule, '
        'and report a provider that does not follow it', () {
      const outside = SharedState(
        'counterTotal',
        listenable: FunctionRef(
          'totalListenable',
          import: ImportRef('package:counter/counter.dart'),
        ),
        type: TypeRef('int'),
        description: 'The total.',
      );

      expect(_messages(check(entries: [outside], bridges: rendered)), [
        equals(
          'The provider of the state management role does not render the '
          'entry counterTotal of the module counter: none of its files calls '
          'or tears off totalListenable() of package:counter/counter.dart.',
        ),
      ]);
    });
  });
}
