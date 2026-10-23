@TestOn('vm')
library;

import 'package:smf_contracts/bundles/env_role_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';
import 'role_support.dart';
import 'support.dart';

/// A role whose template would read values of the app, as the template of a
/// role that uses the env role could.
final _boardRole = TestRole<NoDsl>('board', uses: {envRole});

/// A role that neither requires nor uses the env role.
final _otherRole = TestRole<NoDsl>('other');

const _shopApple = EnvKey(
  'SHOP_APPLE_KEY',
  description: 'The public key of the shop on iOS',
);
const _shopGoogle = EnvKey(
  'SHOP_GOOGLE_KEY',
  description: 'The public key of the shop on Android',
);
const _feedUrl = EnvKey('FEED_URL', description: 'The address of the feed');
const _boardToken = EnvKey(
  'BOARD_TOKEN',
  description: 'The public token of the board',
);

/// The data [value] of the env role from the template of [role].
RoleData<Object> _ofTemplate(Role role, EnvData value) =>
    envRole.data(value).withOrigin(RoleTemplateOrigin(role));

/// The keys of an app with the modules `shop` and `feed`, whose variant
/// gives a key of the module.
final List<RoleData<Object>> _appKeys = [
  dataOf<EnvData>(envRole, _shopApple, module: 'shop'),
  envRole
      .data(_shopGoogle)
      .withOrigin(const ModuleOrigin(ModuleId('shop'), variant: ModuleId('x'))),
  dataOf<EnvData>(envRole, _feedUrl, module: 'feed'),
];

/// The texts of the issues: each message after the origin of the issue.
List<String> _messages(List<SmfIssue> issues) => [
      for (final issue in issues) '${issue.origin}: ${issue.message}',
    ];

/// The `AppEnv` that a provider generates for the keys `SHOP_APPLE_KEY` and
/// `FEED_URL`, as the role asks: an abstract final class without a
/// constructor, with a static getter for each key that is `null` while the
/// value is missing.
const _appEnvFile = '''
abstract final class AppEnv {
  static String? get shopAppleKey => _value('');

  static String? get feedUrl => _value('https://example.com/feed');

  static String? _value(String value) => value.isEmpty ? null : value;
}
''';

void main() {
  group('the env role', () {
    test(
        'has the id env and at most one provider, and needs no other role, '
        'since its values are the same whatever else the app has', () {
      expect(envRole.id, 'env');
      // The heading of the role in the guide for coding agents of the app,
      // and its line in the explanation of smf create.
      expect(envRole.description, 'Values in .env');
      expect('$envRole', 'values in .env role');
      expect(envRole.presenceFlag, 'has_env');
      expect(envRole.cardinality, RoleCardinality.atMostOne);
      expect(envRole.requires, isEmpty);
      expect(envRole.uses, isEmpty);
      expect(envRole.openToAllModules, isFalse);
      expect(envRole.sockets, isEmpty);
      expect(envRole.options, isEmpty);
    });

    test(
        'guarantees the two files of its template and AppEnv, the class of '
        'the provider that code reads the values from', () {
      expect(EnvRole.dotEnvFile, '.env');
      expect(EnvRole.exampleFile, '.env.example');
      expect(EnvRole.readerFile, 'lib/core/env/app_env.dart');
      expect(EnvRole.readmeHeading, 'Values in .env');
      expect(envRole.interface.files, [
        EnvRole.dotEnvFile,
        EnvRole.exampleFile,
      ]);
      expect(envRole.interface.symbols, [EnvRole.appEnv]);
      expect(EnvRole.appEnv.name, 'AppEnv');
      expect(EnvRole.appEnv.path, EnvRole.readerFile);
      expect(EnvRole.appEnv.importRef.uri, 'core/env/app_env.dart');
      // Code reads only the static getters, so the class has no instance
      // that a constructor would make for it.
      expect(EnvRole.appEnv.constConstructor, isFalse);
      expect(EnvRole.appEnv.getters, isEmpty);
      expect(EnvRole.appEnv.namedParameters, isEmpty);
      expect(EnvRole.appEnv.positionalArguments, 0);
    });

    test('has a rule of the keys of a module and two of the generated code',
        () {
      expect(
        [for (final rule in envRole.moduleRules) rule.id],
        ['env.keys'],
      );
      expect(
        [for (final rule in envRole.structuralRules) rule.id],
        ['env.keys_rendered', 'env.key_access'],
      );
      for (final rule in [
        ...envRole.moduleRules.map((rule) => rule.description),
        ...envRole.structuralRules.map((rule) => rule.description),
      ]) {
        expect(rule, endsWith('.'));
      }
      expect(
        envRole.structuralRules.last.description,
        contains('no value that it reads through another expression'),
      );
    });
  });

  group('a key', () {
    test('is read through the getter of its name in lowerCamelCase', () {
      expect(_shopApple.getter, 'shopAppleKey');
      expect(_feedUrl.getter, 'feedUrl');
      expect(
        const EnvKey('FAKE_L10N_FIRST', description: 'x').getter,
        'fakeL10nFirst',
      );
      expect(const EnvKey('SHOP_2X', description: 'x').getter, 'shop2x');
      expect('$_shopApple', 'key SHOP_APPLE_KEY');
    });

    test('has a name in UPPER_SNAKE_CASE of two words or more', () {
      for (final name in [
        'SHOP_KEY',
        'SHOP_APPLE_KEY',
        'SHOP2_KEY',
        'SHOP_2',
        'A_B',
      ]) {
        expect(
          EnvKey(name, description: 'x').problems(),
          isEmpty,
          reason: name,
        );
      }
      for (final name in [
        '',
        'SHOP',
        'shop_key',
        'Shop_Key',
        '2SHOP_KEY',
        '_SHOP_KEY',
        'SHOP_KEY_',
        'SHOP__KEY',
        'SHOP-KEY',
        'SHOP KEY',
        'ШОП_KEY',
      ]) {
        expect(
          EnvKey(name, description: 'x').problems().single,
          'The key "$name" needs a name in UPPER_SNAKE_CASE of two words or '
          'more that starts with a letter, such as REVENUECAT_APPLE_KEY.',
          reason: name,
        );
      }
    });

    test(
        'does not start with FLUTTER_, and is not read as a member that '
        'every Dart object has', () {
      expect(
        const EnvKey('FLUTTER_VERSION', description: 'x').problems().single,
        'The key "FLUTTER_VERSION" starts with FLUTTER_, under which Flutter '
        'gives the app values of its own, such as FLUTTER_VERSION.',
      );
      expect(
        const EnvKey('FLUTTER_CORE_KEY', description: 'x').problems(),
        hasLength(1),
      );
      for (final (name, getter) in [
        ('HASH_CODE', 'hashCode'),
        ('TO_STRING', 'toString'),
        ('RUNTIME_TYPE', 'runtimeType'),
        ('NO_SUCH_METHOD', 'noSuchMethod'),
      ]) {
        expect(
          EnvKey(name, description: 'x').problems().single,
          'The key "$name" would be read as AppEnv.$getter, which every Dart '
          'object has already.',
        );
      }
    });

    test(
        'has a description of one line of at most 100 characters without a '
        'backslash', () {
      expect(EnvKey('SHOP_KEY', description: 'a' * 100).problems(), isEmpty);
      expect(
        const EnvKey('SHOP_KEY', description: 'The key (appl_…)').problems(),
        isEmpty,
      );
      for (final description in ['', '   ']) {
        expect(EnvKey('SHOP_KEY', description: description).problems(), [
          'The key "SHOP_KEY" has no description.',
        ]);
      }
      for (final description in [' The key', 'The key ', 'The\nkey', 'A\rB']) {
        expect(
          EnvKey('SHOP_KEY', description: description).problems().single,
          'The key "SHOP_KEY" has a description that is not one line of text '
          'without spaces around it.',
        );
      }
      expect(
        EnvKey('SHOP_KEY', description: 'a' * 101).problems().single,
        'The key "SHOP_KEY" has a description of 101 characters; at most 100 '
        'fit on its comment line in .env.',
      );
      expect(
        const EnvKey('SHOP_KEY', description: r'C:\keys').problems().single,
        'The key "SHOP_KEY" has a backslash in its description, which mason '
        'removes before a line break and Markdown reads as an escape.',
      );
      expect(
        EnvKey('shop', description: ' ${'a' * 100}').problems(),
        hasLength(3),
      );
    });
  });

  group('the tool arguments', () {
    test('are lines that are not empty', () {
      const given = EnvToolArguments(['--values=.env', '--debug']);

      expect(given.problems(), isEmpty);
      expect(const EnvToolArguments([]).problems(), isEmpty);
      expect('$given', 'tool arguments --values=.env --debug');
      const empty = 'An argument of the tool arguments of the values in .env '
          'role is empty.';
      const notOneLine = 'An argument of the tool arguments of the values in '
          '.env role is not one line.';
      expect(const EnvToolArguments(['--a', '']).problems(), [empty]);
      for (final arguments in [
        ['--a\n--b'],
        ['--c\r'],
        ['--a\n--b', '--c\r'],
      ]) {
        expect(
          EnvToolArguments(arguments).problems(),
          [notOneLine],
          reason: '$arguments',
        );
      }
    });
  });

  group('the keys and the tool arguments of an app', () {
    test('are the keys of the modules in their order, each with its owner', () {
      final keys = envRole.keysIn(inputOf(envRole, data: _appKeys));

      expect(
        [for (final key in keys) key.name],
        ['SHOP_APPLE_KEY', 'SHOP_GOOGLE_KEY', 'FEED_URL'],
      );
      final owners = [for (final key in keys) key.owner];
      expect(owners, [
        const ModuleOrigin(ModuleId('shop')),
        // A variant gives the keys of its module.
        const ModuleOrigin(ModuleId('shop')),
        const ModuleOrigin(ModuleId('feed')),
      ]);
      expect(keys.first.key, same(_shopApple));
      expect(keys.first.description, _shopApple.description);
      expect(keys.first.getter, 'shopAppleKey');
      expect('${keys.first}', 'key SHOP_APPLE_KEY of the module shop');
    });

    test('are what a role that uses the env role reads too', () {
      final input = inputOf(_boardRole, data: _appKeys, present: {envRole});

      expect(envRole.keysIn(input), hasLength(3));
      expect(envRole.toolArgumentsIn(input), isEmpty);
      expect(
        () => envRole.keysIn(inputOf(_otherRole, data: _appKeys)),
        throwsArgumentError,
      );
    });

    test(
        'have the tool arguments of the provider in their order, as the '
        'role gives them on, and none without them', () {
      final data = [
        ..._appKeys,
        dataOf<EnvData>(
          envRole,
          const EnvToolArguments(['--values=.env', '--debug']),
          module: 'reader',
        ),
      ];

      expect(
        envRole.toolArgumentsIn(inputOf(envRole, data: data)),
        ['--values=.env', '--debug'],
      );
      expect(envRole.keysIn(inputOf(envRole, data: data)), hasLength(3));
      expect(envRole.toolArgumentsIn(inputOf(envRole)), isEmpty);
    });
  });

  group('the variables of the keys of a module', () {
    test(
        'read AppEnv in an app with the role, and are null in an app '
        'without it', () {
      final vars = envRole.varsOf(const ModuleId('shop'), const [
        _shopApple,
        _shopGoogle,
      ]);

      expect(vars.keys, ['env_shop_apple_key', 'env_shop_google_key']);
      final variable = vars['env_shop_apple_key']!;
      expect(variable.role, same(envRole));
      final present = variable.present as Fragment;
      expect(present.code, 'AppEnv.shopAppleKey');
      expect(present.imports, [EnvRole.appEnv.importRef]);
      expect(variable.absent, 'null');
    });

    test('type-check where a String? is expected, with and without the role',
        () async {
      final vars = envRole.varsOf(const ModuleId('feed'), const [_feedUrl]);
      final present = vars['env_feed_url']!.present as Fragment;
      final import = present.imports.single;
      final files = DartFiles.write({
        EnvRole.readerFile: _appEnvFile,
        'lib/feed/with_role.dart': '''
import 'package:my_app/${import.uri}';

String describe(String? url) => url ?? 'none';

final described = describe(${present.code});
''',
        'lib/feed/without_role.dart': '''
String describe(String? url) => url ?? 'none';

final described = describe(${vars['env_feed_url']!.absent});
''',
      });
      addTearDown(files.delete);

      expect(await files.analysisProblems(), isEmpty);
    });

    test('are not made for keys with problems', () {
      expect(
        () => envRole.varsOf(const ModuleId('shop'), const [
          _feedUrl,
          _shopApple,
          _shopApple,
          EnvKey('SHOP_A1_KEY', description: 'x'),
          EnvKey('SHOP_A_1_KEY', description: 'x'),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'The key "FEED_URL" does not start with SHOP_, the id of its '
                'owner in upper case and an underscore. Two keys are named '
                '"SHOP_APPLE_KEY". The keys "SHOP_A1_KEY" and "SHOP_A_1_KEY" '
                'would both be read as AppEnv.shopA1Key.',
          ),
        ),
      );
      expect(
        () => envRole.varsOf(const ModuleId('shop'), const [
          EnvKey('shop_key', description: 'x'),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('the rule env.keys', () {
    const shop = ModuleDescriptor(
      id: ModuleId('shop'),
      description: 'Shop',
      kind: plainKind,
      requires: {envRole},
    );
    const reader = ModuleDescriptor(
      id: ModuleId('reader'),
      description: 'Reader',
      kind: plainKind,
      providers: [RoleProvider.plain(envRole)],
    );
    // A module that depends on the module shop.
    const paywall = ModuleDescriptor(
      id: ModuleId('paywall'),
      description: 'Paywall',
      kind: plainKind,
      dependsOn: {ModuleId('shop')},
      uses: {envRole},
    );

    /// The issues of [module] in an app with the [data] of the role, whose
    /// contributions are its data and [more]. The modules `shop` and `feed`
    /// of the app give the role a key each.
    List<SmfIssue> check(
      ModuleDescriptor module,
      List<EnvData> data, {
      List<Contribution> more = const [],
    }) {
      final given = [
        for (final value in data)
          dataOf<EnvData>(envRole, value, module: module.id.value),
      ];
      return envRole.checkModule(
        ModuleRuleRequest(
          hook: RoleHookRequest(
            data: [
              ...given,
              if (module != shop)
                dataOf<EnvData>(envRole, _shopApple, module: 'shop'),
              dataOf<EnvData>(envRole, _feedUrl, module: 'feed'),
            ],
            presentRoles: {envRole},
            context: testContext,
          ),
          module: module,
          contributions: [...given, ...more],
        ),
      );
    }

    /// A brick of the module with [vars].
    BrickContribution brick(Map<String, Object?> vars) =>
        BrickContribution(envRoleBundle, vars: vars);

    test(
        'passes the keys of a module, the variables that read them, and the '
        'tool arguments of a provider', () {
      expect(
        check(
          shop,
          const [_shopApple],
          more: [
            brick({
              ...envRole.varsOf(const ModuleId('shop'), const [_shopApple]),
              // Variables of other roles, and of this role that read no
              // value, are not the rule's.
              'text_title': const RoleVar(
                localizationRole,
                present: 'context.l10n.shopTitle',
                absent: "'Shop'",
              ),
              'env_other': const RoleVar(
                envRole,
                present: "'fixed'",
                absent: 'null',
              ),
              'plain': 'AppEnv.feedUrl',
            }),
          ],
        ),
        isEmpty,
      );
      expect(
        check(reader, const [
          EnvToolArguments(['--values=.env']),
        ]),
        isEmpty,
      );
    });

    test('reports the problems of the keys of the module', () {
      expect(
        _messages(
          check(shop, const [
            _feedUrl,
            EnvKey('SHOP_KEY', description: ''),
          ]),
        ),
        [
          equals(
            'shop: The key "FEED_URL" does not start with SHOP_, the id of '
            'its owner in upper case and an underscore.',
          ),
          'shop: The key "SHOP_KEY" has no description.',
        ],
      );
    });

    test(
        'passes a variable of a brick that reads a key of a module that the '
        'module depends on', () {
      expect(
        check(
          paywall,
          const [],
          more: [
            brick(envRole.varsOf(const ModuleId('shop'), const [_shopApple])),
          ],
        ),
        isEmpty,
      );
    });

    test(
        'reports a variable of a brick that reads a key of a module that the '
        'module does not depend on, or that the app lacks', () {
      final issues = check(
        paywall,
        const [],
        more: [
          brick({
            ...envRole.varsOf(const ModuleId('feed'), const [_feedUrl]),
            ...envRole.varsOf(const ModuleId('shop'), const [
              EnvKey('SHOP_TOKEN', description: 'A token'),
            ]),
          }),
        ],
      );

      expect(_messages(issues), [
        equals(
          'paywall: The variable env_feed_url of the brick env_role reads '
          'AppEnv.feedUrl, but neither the module nor a module that it '
          'depends on has a key with the getter feedUrl.',
        ),
        equals(
          'paywall: The variable env_shop_token of the brick env_role reads '
          'AppEnv.shopToken, but neither the module nor a module that it '
          'depends on has a key with the getter shopToken.',
        ),
      ]);
      expect(issues.first.hint, contains('envRole.varsOf()'));
    });

    test(
        'reports tool arguments from a module that does not provide the '
        'role, from a provider more than once, and their problems', () {
      final issue = check(shop, const [
        EnvToolArguments(['--values=.env']),
      ]).single;
      expect(
        issue.message,
        'The module gives the values in .env role tool arguments, which only '
        'a provider of the role gives.',
      );
      expect(issue.hint, contains('keys'));
      expect(issue.origin, const ModuleOrigin(ModuleId('shop')));

      expect(
        _messages(
          check(reader, const [
            EnvToolArguments(['--values=.env']),
            EnvToolArguments(['']),
          ]),
        ),
        [
          equals(
            'reader: A provider of the values in .env role gives it tool '
            'arguments at most once, but the module gives them 2 times.',
          ),
          equals(
            'reader: An argument of the tool arguments of the values in .env '
            'role is empty.',
          ),
        ],
      );
    });
  });

  group('the rule env.keys_rendered', () {
    const reader = ModuleDescriptor(
      id: ModuleId('reader'),
      description: 'Reader',
      kind: plainKind,
      providers: [RoleProvider.plain(envRole)],
    );
    const ofReader = ModuleOrigin(ModuleId('reader'));

    /// The issues of an app with the keys of [_appKeys] whose file of
    /// `AppEnv` has [members] in a declaration named [name], and with
    /// [modules].
    List<SmfIssue> check(
      List<IndexedMember>? members, {
      String name = 'AppEnv',
      List<ModuleDescriptor> modules = const [reader],
    }) =>
        envRole.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: _appKeys,
              presentRoles: {envRole},
              context: testContext,
            ),
            files: {
              if (members != null)
                EnvRole.readerFile: DartFileIndex(
                  path: EnvRole.readerFile,
                  declarations: [
                    IndexedDeclaration(
                      name: name,
                      kind: DeclarationKind.classType,
                      members: members,
                    ),
                  ],
                ),
            },
            owners: const {EnvRole.readerFile: ofReader},
            modules: modules,
          ),
        );

    IndexedMember getter(String name) =>
        IndexedMember(name, kind: MemberKind.getter, isStatic: true);

    test('passes an AppEnv with a static getter for every key', () {
      expect(
        check([
          getter('shopAppleKey'),
          getter('shopGoogleKey'),
          getter('feedUrl'),
          // What else the class has is the provider's.
          const IndexedMember('_value', kind: MemberKind.method),
        ]),
        isEmpty,
      );
    });

    test(
        'reports a key without a static getter, also one whose name the '
        'class has for another member', () {
      final issues = check([
        getter('shopAppleKey'),
        const IndexedMember('shopGoogleKey', kind: MemberKind.getter),
        const IndexedMember(
          'feedUrl',
          kind: MemberKind.field,
          isStatic: true,
        ),
      ]);

      expect(_messages(issues), [
        for (final (key, owner, getter) in [
          ('SHOP_GOOGLE_KEY', 'the module shop', 'shopGoogleKey'),
          ('FEED_URL', 'the module feed', 'feedUrl'),
        ])
          equals(
            'reader: The provider of the values in .env role does not render '
            'the key $key of $owner: AppEnv in lib/core/env/app_env.dart '
            'declares no static getter $getter.',
          ),
      ]);
      expect(issues.first.path, EnvRole.readerFile);
      expect(issues.first.hint, contains('EnvKey.getter'));
    });

    test(
        'leaves an app without a provider, and a file or a class that the '
        'check of the interface reports, to others', () {
      expect(check(const [], modules: const []), isEmpty);
      expect(check(null), isEmpty);
      expect(check(const [], name: 'Env'), isEmpty);
    });
  });

  group('the rule env.key_access', () {
    const shop = ModuleDescriptor(
      id: ModuleId('shop'),
      description: 'Shop',
      kind: plainKind,
      requires: {envRole},
    );
    const feed = ModuleDescriptor(
      id: ModuleId('feed'),
      description: 'Feed',
      kind: plainKind,
      uses: {envRole},
    );
    // A module that depends on the module shop.
    const paywall = ModuleDescriptor(
      id: ModuleId('paywall'),
      description: 'Paywall',
      kind: plainKind,
      dependsOn: {ModuleId('shop')},
      uses: {envRole},
    );
    // A module without the role among its roles.
    const plain = ModuleDescriptor(
      id: ModuleId('plain'),
      description: 'Plain',
      kind: plainKind,
    );
    const reader = ModuleDescriptor(
      id: ModuleId('reader'),
      description: 'Reader',
      kind: plainKind,
      providers: [RoleProvider.plain(envRole)],
    );

    /// The issues of an app whose file at `lib/file.dart`, generated by
    /// [owner], has [accesses] and [invocations].
    List<SmfIssue> check(
      ContributionOrigin? owner, {
      List<IndexedMemberAccess> accesses = const [],
      List<IndexedInvocation> invocations = const [],
      List<RoleData<Object>> more = const [],
    }) =>
        envRole.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: [..._appKeys, ...more],
              presentRoles: {envRole, _boardRole},
              context: testContext,
            ),
            files: {
              'lib/file.dart': DartFileIndex(
                path: 'lib/file.dart',
                memberAccesses: accesses,
                invocations: invocations,
              ),
            },
            owners: {if (owner != null) 'lib/file.dart': owner},
            modules: const [shop, feed, paywall, plain, reader],
          ),
        );

    const ofShop = ModuleOrigin(ModuleId('shop'));

    test(
        'lets a module read its own keys and those of the modules it '
        'depends on, with or without a prefix', () {
      expect(
        check(
          ofShop,
          accesses: const [
            IndexedMemberAccess('AppEnv', 'shopAppleKey'),
            IndexedMemberAccess('env.AppEnv', 'shopGoogleKey'),
            // Not AppEnv.
            IndexedMemberAccess('env', 'AppEnv'),
            IndexedMemberAccess('appEnv', 'feedUrl'),
            IndexedMemberAccess('AppEnvX', 'feedUrl'),
            IndexedMemberAccess('AppEnv.shopAppleKey', 'length'),
          ],
          invocations: const [
            IndexedInvocation('trim', target: 'AppEnv.shopAppleKey'),
            IndexedInvocation('AppEnv'),
          ],
        ),
        isEmpty,
      );
      expect(
        check(
          const ModuleOrigin(ModuleId('paywall')),
          accesses: const [IndexedMemberAccess('AppEnv', 'shopAppleKey')],
        ),
        isEmpty,
      );
      expect(
        check(
          const ModuleOrigin(ModuleId('shop'), variant: ModuleId('bloc')),
          accesses: const [IndexedMemberAccess('AppEnv', 'shopAppleKey')],
        ),
        isEmpty,
      );
    });

    test('reports a module that reads a key of another module', () {
      final issue = check(
        const ModuleOrigin(ModuleId('paywall')),
        accesses: const [IndexedMemberAccess('env.AppEnv', 'feedUrl')],
      ).single;

      expect(
        issue.message,
        'lib/file.dart reads env.AppEnv.feedUrl, the key FEED_URL of the '
        'module feed, but the module paywall may only read its own keys and '
        'those of the modules it depends on.',
      );
      expect(issue.origin, const ModuleOrigin(ModuleId('paywall')));
      expect(issue.path, 'lib/file.dart');
      expect(issue.hint, 'Give the role a key of your own.');
    });

    test('reports a getter that no key of the app has, and a call', () {
      final issues = check(
        ofShop,
        accesses: const [IndexedMemberAccess('AppEnv', 'shopAppelKey')],
        invocations: const [
          IndexedInvocation('read', target: 'env.AppEnv'),
        ],
      );

      expect(_messages(issues), [
        equals(
          'shop: lib/file.dart reads AppEnv.shopAppelKey, but no key of the '
          'app has the getter shopAppelKey.',
        ),
        equals(
          'shop: lib/file.dart calls env.AppEnv.read(), but the values of the '
          'app are getters, each named by the role.',
        ),
      ]);
      expect(
        issues.first.hint,
        contains('AppEnv.myServiceKey for MY_SERVICE_KEY'),
      );
      expect(issues.last.hint, contains('without arguments'));
    });

    test(
        'reports what the template of a role, its own too, and the pipeline '
        'read, since only the code of a module reads values', () {
      // Not even a key that the template gave, which validation refuses.
      expect(
        _messages(
          check(
            RoleTemplateOrigin(_boardRole),
            accesses: const [IndexedMemberAccess('AppEnv', 'boardToken')],
            more: [_ofTemplate(_boardRole, _boardToken)],
          ),
        ),
        [
          equals(
            'role:board: lib/file.dart reads AppEnv.boardToken, the key '
            'BOARD_TOKEN of the template of the board role, but only the code '
            'of a module reads the values of the app, not that of the '
            'template of the board role.',
          ),
        ],
      );

      const read = [IndexedMemberAccess('AppEnv', 'shopAppleKey')];

      for (final (owner, named) in [
        (RoleTemplateOrigin(_boardRole), 'the template of the board role'),
        (
          const RoleTemplateOrigin(envRole),
          'the template of the values in .env role',
        ),
        (const PipelineOrigin(), 'the pipeline'),
      ]) {
        final issue = check(owner, accesses: read).single;
        expect(
          issue.message,
          'lib/file.dart reads AppEnv.shopAppleKey, the key SHOP_APPLE_KEY of '
          'the module shop, but only the code of a module reads the values of '
          'the app, not that of $named.',
          reason: '$owner',
        );
        expect(issue.origin, owner);
        expect(issue.hint, contains('module'));
      }
    });

    test(
        'leaves the provider, modules and templates without the role, a '
        'module that the app lacks, and a file without an owner alone', () {
      const read = [IndexedMemberAccess('AppEnv', 'feedUrl')];

      for (final owner in [
        const ModuleOrigin(ModuleId('reader')),
        const ModuleOrigin(ModuleId('plain')),
        const ModuleOrigin(ModuleId('gone')),
        RoleTemplateOrigin(_otherRole),
        null,
      ]) {
        expect(check(owner, accesses: read), isEmpty, reason: '$owner');
      }
    });
  });

  group('the template of the env role', () {
    test(
        'generates the files of the role, keeps the file of the values out '
        'of git, and adds the note of the role', () {
      final contributions = envRole.template.contribute(testContext);

      expect(contributions, hasLength(3));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(envRoleBundle));
      expect(brick.when, isEmpty);
      expect(
        templatesOf(envRoleBundle).keys.toSet(),
        {EnvRole.dotEnvFile, EnvRole.exampleFile},
      );

      final pattern = contributions[1] as SocketContribution;
      expect(pattern.socket, AppEntryRole.gitignore);
      expect(pattern.entryKey, EnvRole.dotEnvFile);
      expect(pattern.when, isEmpty);
      expect(AppEntryRole.gitignore.render([pattern]), {
        AppEntryRole.gitignore.tag: '\n# The values of the app, which each '
            'developer fills in from .env.example\n.env',
      });
      expect(AppEntryRole.gitignore.problemsWith(pattern), isEmpty);

      final note = contributions[2] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, envRole.description);
      expect((note.entryValue! as AgentNote).isOfRole, isTrue);
      expect(note.when, isEmpty);
    });

    test(
        'lists each key with its description in the file of the values and '
        'in the file of the keys, in the order of the keys', () async {
      final rendered = await renderTemplate(envRole, data: _appKeys);

      const keys = '\n'
          '# The public key of the shop on iOS\n'
          'SHOP_APPLE_KEY=\n'
          '\n'
          '# The public key of the shop on Android\n'
          'SHOP_GOOGLE_KEY=\n'
          '\n'
          '# The address of the feed\n'
          'FEED_URL=\n';
      // Every provider reads a value of these two forms alike.
      const forms = '#\n'
          '# Write a value as it is, or in double quotes if it has a space, '
          'a # or a quote.\n';
      expect(rendered.files.keys.toSet(), {
        EnvRole.dotEnvFile,
        EnvRole.exampleFile,
      });
      expect(
        rendered.files[EnvRole.exampleFile],
        '# This file lists the keys of the values that the app reads, each '
        'under a\n'
        '# comment that says what goes there. After a clone, copy it to .env '
        'and fill\n'
        '# in the values there; .env stays out of git. Every value ends up '
        'in the app,\n'
        '# where anyone can read it, so never put a secret into one. An '
        'empty value\n'
        '# counts as missing.\n'
        '$forms'
        '$keys',
      );
      expect(
        rendered.files[EnvRole.dotEnvFile],
        '# The values that the app reads, each under a comment that says '
        'what goes\n'
        '# there. This file stays out of git; .env.example has the same keys '
        'without\n'
        '# values. Every value ends up in the app, where anyone can read it, '
        'so never\n'
        '# put a secret here. An empty value counts as missing.\n'
        '$forms'
        '$keys',
      );
      // Every line is a comment, empty, or a key without a value.
      for (final file in rendered.files.values) {
        for (final line in file.split('\n')) {
          expect(
            line,
            anyOf(
              isEmpty,
              '#',
              startsWith('# '),
              matches(RegExp(r'^[A-Z_]+=$')),
            ),
          );
        }
      }
    });

    test(
        'renders no line of keys in an app without keys, which the pipeline '
        'then leaves out', () {
      final output = envRole.template.render(inputOf(envRole));
      final keys = output.vars['env_keys']! as Fragment;

      expect(keys.code, isEmpty);
      expect(keys.imports, isEmpty);
    });

    test(
        'writes the section of the role in the README, with the keys of the '
        'app and their owners', () {
      final output = envRole.template.render(
        inputOf(envRole, data: _appKeys),
      );
      final section = output.fragments.single;

      expect(section.socket, AppEntryRole.readmeSections);
      expect(section.entryKey, EnvRole.readmeHeading);
      expect(AppEntryRole.readmeSections.problemsWith(section), isEmpty);
      expect(section.entryValue, '''
`.env` at the root of the app holds the values you fill in after generating the app, such as the public key of a service. Code reads each value as a static getter of `AppEnv` in `lib/core/env/app_env.dart`. The getter is `null` while the value is empty or missing, so the app builds and starts before you fill anything in.

`.gitignore` lists `.env`, so it stays out of git. `.env.example` is in git and has the same keys without values: after a clone, run `cp .env.example .env` and fill in `.env`. Every value ends up in the app, where anyone can read it, so never put a secret there, such as the secret key of a server, a password or a private key.

The keys of the app:

- `SHOP_APPLE_KEY`, read as `AppEnv.shopAppleKey`, from the module `shop`: The public key of the shop on iOS
- `SHOP_GOOGLE_KEY`, read as `AppEnv.shopGoogleKey`, from the module `shop`: The public key of the shop on Android
- `FEED_URL`, read as `AppEnv.feedUrl`, from the module `feed`: The address of the feed

To add a key of your own, put it into `.env.example` and `.env` and give `AppEnv` a getter for it. The section of the module that provides the values tells how they get into the app.
''');
    });

    test('says in the README of an app without keys that it has none', () {
      final section = envRole.template
          .render(inputOf(envRole))
          .fragments
          .single
          .entryValue! as String;

      expect(
        section,
        contains(
          'a private key.\n'
          '\n'
          'No module of the app reads a value yet.\n'
          '\n'
          'To add a key of your own',
        ),
      );
      expect(section, isNot(contains('The keys of the app')));
    });

    test(
        'says in the guide how code reads a value, that none is a secret, '
        'and what a new key needs', () {
      final note = agentNoteOf(envRole);

      expectNamesOfCode(
        note,
        {
          EnvRole.readerFile: ['AppEnv'],
        },
        files: const {EnvRole.readerFile: _appEnvFile},
      );
      expect(
        note.text,
        allOf(
          contains('`AppEnv.myServiceKey` for the key `MY_SERVICE_KEY`'),
          contains('`String?`'),
          contains('Never put a secret into `.env`'),
          contains('`.env.example` and `.env`'),
        ),
      );
      final named = const EnvKey('MY_SERVICE_KEY', description: 'x').getter;
      expect(note.text, contains('`AppEnv.$named`'));
    });

    group('checks', () {
      List<String> validate(List<RoleData<Object>> data) =>
          _messages(envRole.template.validate(inputOf(envRole, data: data)));

      test('the keys of the app of different owners', () {
        expect(validate(_appKeys), isEmpty);
      });

      test(
          'a key from the template of a role, which only modules give, and '
          'not the keys of the modules, which their rule checks', () {
        final issues = envRole.template.validate(
          inputOf(
            envRole,
            data: [
              dataOf<EnvData>(
                envRole,
                const EnvKey('feed_url', description: ''),
                module: 'feed',
              ),
              _ofTemplate(_boardRole, _boardToken),
            ],
          ),
        );

        expect(_messages(issues), [
          equals(
            'role:board: The template of the board role gives the values in '
            '.env role the key BOARD_TOKEN, but only modules give the role '
            'keys.',
          ),
        ]);
        expect(issues.single.hint, contains('module'));
      });

      test('the tool arguments of a template, which only a provider gives', () {
        final issue = envRole.template
            .validate(
              inputOf(
                envRole,
                data: [
                  _ofTemplate(_boardRole, const EnvToolArguments(['--a'])),
                ],
              ),
            )
            .single;

        expect(
          issue.message,
          'The template of the board role gives the values in .env role tool '
          'arguments, which only a provider of the role gives.',
        );
        expect(issue.origin, RoleTemplateOrigin(_boardRole));
      });

      test(
          'two owners that give one key, or keys with one getter, since the '
          'id of one owner can start that of another', () {
        final issues = envRole.template.validate(
          inputOf(
            envRole,
            data: [
              dataOf<EnvData>(
                envRole,
                const EnvKey('SHOP_CART_KEY', description: 'x'),
                module: 'shop',
              ),
              dataOf<EnvData>(
                envRole,
                const EnvKey('SHOP_CART_KEY', description: 'y'),
                module: 'shop_cart',
              ),
              dataOf<EnvData>(
                envRole,
                const EnvKey('SHOP1_KEY', description: 'x'),
                module: 'shop1',
              ),
              dataOf<EnvData>(
                envRole,
                const EnvKey('SHOP_1_KEY', description: 'x'),
                module: 'shop',
              ),
            ],
          ),
        );

        expect(_messages(issues), [
          equals(
            'shop_cart: Both the module shop and the module shop_cart give '
            'the values in .env role the key SHOP_CART_KEY.',
          ),
          equals(
            'shop: The key SHOP1_KEY of the module shop1 and the key '
            'SHOP_1_KEY of the module shop would both be read as '
            'AppEnv.shop1Key.',
          ),
        ]);
        expect(issues.first.hint, 'Rename one of the keys.');
        expect(issues.last.hint, 'Rename one of the keys.');
      });
    });
  });
}
