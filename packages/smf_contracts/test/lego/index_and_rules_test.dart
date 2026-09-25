import 'package:smf_contracts/lego_core.dart';
import 'package:test/test.dart';

import 'support.dart';

List<SmfIssue> _flagsResolve(StructuralRuleInput input) => [
      for (final file in input.files.values)
        if (file.uses('resolve')) SmfIssue('resolve', path: file.path),
    ];

List<SmfIssue> _flagsModulesWithData(ModuleRuleInput input) => [
      if (input.contributions.whereType<RoleData<Object>>().isNotEmpty)
        SmfIssue('data', origin: ModuleOrigin(input.module.id)),
    ];

void main() {
  group('DartFileIndex', () {
    const index = DartFileIndex(
      path: 'lib/features/home/home_composition.dart',
      imports: [
        IndexedImport('package:flutter/widgets.dart'),
        IndexedImport(
          'package:my_app/core/di/di.dart',
          prefix: 'di',
          show: ['resolve'],
          hide: ['getIt'],
        ),
      ],
      declarations: [
        IndexedDeclaration(name: 'HomeCubit', kind: DeclarationKind.classType),
        IndexedDeclaration(
          name: 'createHomeCubit',
          kind: DeclarationKind.function,
          type: 'HomeCubit',
        ),
      ],
      invocations: [
        IndexedInvocation(
          'resolve',
          typeArguments: ['AnalyticsService'],
          enclosingDeclaration: 'createHomeCubit',
          offset: 10,
        ),
        IndexedInvocation(
          'details',
          target: 'context.nav.home',
          namedArguments: ['id'],
          enclosingDeclaration: 'HomeCubit',
          offset: 20,
        ),
      ],
      references: [IndexedReference('appRouter', offset: 30)],
      memberAccesses: [
        IndexedMemberAccess(
          'context',
          'nav',
          enclosingDeclaration: 'HomeCubit',
        ),
      ],
    );

    test('answers questions about imports and declarations', () {
      expect(index.importsUri('package:flutter/widgets.dart'), isTrue);
      expect(index.importsUri('package:flutter/material.dart'), isFalse);
      expect(index.imports.last.prefix, 'di');
      expect(index.imports.last.show, ['resolve']);
      expect(index.imports.last.hide, ['getIt']);
      expect(index.declaration('createHomeCubit')?.type, 'HomeCubit');
      expect(index.declaration('Missing'), isNull);
    });

    test('finds invocations, optionally within a declaration', () {
      expect(index.invocationsOf('resolve').single.typeArguments, [
        'AnalyticsService',
      ]);
      expect(index.invocationsOf('resolve', within: 'HomeCubit'), isEmpty);
      final details = index.invocationsOf('details', within: 'HomeCubit');
      expect(details.single.target, 'context.nav.home');
      expect(details.single.namedArguments, ['id']);
      expect(details.single.awaited, isFalse);
    });

    test('knows every name the file uses', () {
      expect(index.uses('resolve'), isTrue);
      expect(index.uses('appRouter'), isTrue);
      expect(index.uses('nav'), isTrue);
      expect(index.uses('getIt'), isFalse);
      expect(index.references.single.enclosingDeclaration, isNull);
      expect(index.memberAccesses.single.target, 'context');
      expect(index.memberAccesses.single.offset, 0);
    });

    test('an empty index has nothing', () {
      const empty = DartFileIndex(path: 'lib/a.dart');
      expect(empty.imports, isEmpty);
      expect(empty.declarations, isEmpty);
      expect(empty.invocations, isEmpty);
      expect(empty.references, isEmpty);
      expect(empty.memberAccesses, isEmpty);
    });
  });

  group('IndexedDeclaration.unnamedConstructor', () {
    test('is the implicit default constructor without declared ones', () {
      const declaration =
          IndexedDeclaration(name: 'A', kind: DeclarationKind.classType);
      final constructor = declaration.unnamedConstructor!;

      expect(constructor.name, isEmpty);
      expect(constructor.parameters, isEmpty);
      expect(constructor.isConst, isFalse);
      expect(constructor.isFactory, isFalse);
    });

    test('is the declared unnamed constructor', () {
      const declaration = IndexedDeclaration(
        name: 'A',
        kind: DeclarationKind.classType,
        constructors: [
          IndexedConstructor(name: 'named'),
          IndexedConstructor(isConst: true),
        ],
      );
      expect(declaration.unnamedConstructor!.isConst, isTrue);
    });

    test('is null with only named constructors', () {
      const declaration = IndexedDeclaration(
        name: 'A',
        kind: DeclarationKind.classType,
        constructors: [IndexedConstructor(name: 'named', isFactory: true)],
      );
      expect(declaration.unnamedConstructor, isNull);
    });
  });

  test('ParameterKind tells named and required parameters apart', () {
    expect(ParameterKind.requiredPositional.isRequired, isTrue);
    expect(ParameterKind.requiredPositional.isNamed, isFalse);
    expect(ParameterKind.optionalPositional.isRequired, isFalse);
    expect(ParameterKind.requiredNamed.isRequired, isTrue);
    expect(ParameterKind.requiredNamed.isNamed, isTrue);
    expect(ParameterKind.optionalNamed.isRequired, isFalse);
    expect(ParameterKind.optionalNamed.isNamed, isTrue);
  });

  group('RequiredFunction', () {
    const symbol = RequiredFunction(
      'createAppRouter',
      path: 'lib/router.dart',
      returnType: 'AppRouter',
      parameters: [RequiredParameter('observers')],
    );

    Map<String, DartFileIndex> declaring(IndexedDeclaration declaration) => {
          'lib/router.dart': DartFileIndex(
            path: 'lib/router.dart',
            declarations: [declaration],
          ),
        };

    test('is satisfied by a matching function', () {
      expect(
        symbol.checkIn(
          declaring(
            const IndexedDeclaration(
              name: 'createAppRouter',
              kind: DeclarationKind.function,
              type: ' AppRouter ',
              parameters: [
                IndexedParameter(
                  'observers',
                  kind: ParameterKind.requiredNamed,
                ),
                IndexedParameter('debug', kind: ParameterKind.optionalNamed),
              ],
            ),
          ),
        ),
        isEmpty,
      );
    });

    test('reports a missing file or declaration', () {
      expect(
        symbol.checkIn(const {}).single.message,
        'lib/router.dart is missing, so it cannot declare function '
        'createAppRouter().',
      );
      expect(
        symbol
            .checkIn(
              declaring(
                const IndexedDeclaration(
                  name: 'other',
                  kind: DeclarationKind.function,
                ),
              ),
            )
            .single
            .message,
        'lib/router.dart does not declare function createAppRouter().',
      );
    });

    test('reports a declaration of another kind', () {
      expect(
        symbol
            .checkIn(
              declaring(
                const IndexedDeclaration(
                  name: 'createAppRouter',
                  kind: DeclarationKind.variable,
                ),
              ),
            )
            .single
            .message,
        'function createAppRouter() in lib/router.dart must be a function, '
        'not a variable.',
      );
    });

    test('reports the wrong return type and parameters', () {
      final issues = symbol.checkIn(
        declaring(
          const IndexedDeclaration(
            name: 'createAppRouter',
            kind: DeclarationKind.function,
            parameters: [
              IndexedParameter(
                'observers',
                kind: ParameterKind.requiredPositional,
              ),
              IndexedParameter('debug', kind: ParameterKind.requiredNamed),
            ],
          ),
        ),
      );

      const prefix = 'function createAppRouter() in lib/router.dart must';
      expect(issues.map((issue) => issue.message), [
        '$prefix return AppRouter, not an undeclared type.',
        '$prefix accept the named parameter observers.',
        '$prefix not require the parameter debug.',
      ]);
      expect(issues.first.path, 'lib/router.dart');
    });

    test('checks positional parameters too', () {
      const positional = RequiredFunction(
        'f',
        path: 'lib/f.dart',
        parameters: [RequiredParameter('a', named: false)],
      );

      expect(
        positional.checkIn(const {
          'lib/f.dart': DartFileIndex(
            path: 'lib/f.dart',
            declarations: [
              IndexedDeclaration(
                name: 'f',
                kind: DeclarationKind.function,
                type: 'void',
                parameters: [
                  IndexedParameter('a', kind: ParameterKind.requiredPositional),
                ],
              ),
            ],
          ),
        }),
        isEmpty,
      );
    });
  });

  group('RequiredClass', () {
    const symbol = RequiredClass(
      'AppShell',
      path: 'lib/shell.dart',
      constructorParameters: [
        RequiredParameter('destinations'),
        RequiredParameter('body'),
      ],
      constConstructor: true,
    );

    Map<String, DartFileIndex> declaring(IndexedDeclaration declaration) => {
          'lib/shell.dart': DartFileIndex(
            path: 'lib/shell.dart',
            declarations: [declaration],
          ),
        };

    test('is satisfied by a matching class', () {
      expect(
        symbol.checkIn(
          declaring(
            const IndexedDeclaration(
              name: 'AppShell',
              kind: DeclarationKind.classType,
              constructors: [
                IndexedConstructor(
                  isConst: true,
                  parameters: [
                    IndexedParameter(
                      'destinations',
                      kind: ParameterKind.requiredNamed,
                    ),
                    IndexedParameter('body', kind: ParameterKind.requiredNamed),
                    IndexedParameter('key', kind: ParameterKind.optionalNamed),
                  ],
                ),
              ],
            ),
          ),
        ),
        isEmpty,
      );
    });

    test('reports a declaration that is not a class', () {
      expect(
        symbol
            .checkIn(
              declaring(
                const IndexedDeclaration(
                  name: 'AppShell',
                  kind: DeclarationKind.typedef,
                ),
              ),
            )
            .single
            .message,
        'class AppShell in lib/shell.dart must be a class, not a typedef.',
      );
    });

    test('reports a missing unnamed constructor', () {
      expect(
        symbol
            .checkIn(
              declaring(
                const IndexedDeclaration(
                  name: 'AppShell',
                  kind: DeclarationKind.classType,
                  constructors: [IndexedConstructor(name: 'create')],
                ),
              ),
            )
            .single
            .message,
        'class AppShell in lib/shell.dart must have an unnamed constructor.',
      );
    });

    test('reports a constructor that is not const or lacks parameters', () {
      final issues = symbol.checkIn(
        declaring(
          const IndexedDeclaration(
            name: 'AppShell',
            kind: DeclarationKind.classType,
          ),
        ),
      );

      const prefix = 'class AppShell in lib/shell.dart must';
      expect(issues.map((issue) => issue.message), [
        '$prefix have a const unnamed constructor.',
        '$prefix accept the named parameter destinations.',
        '$prefix accept the named parameter body.',
      ]);
    });
  });

  group('StructuralRule', () {
    test('runs over the indexed files of an app', () {
      const rule = StructuralRule(
        id: 'di.resolve_only_in_composition',
        description: 'resolve is called only in composition files.',
        check: _flagsResolve,
      );
      const input = StructuralRuleInput(
        files: {
          'lib/a.dart': DartFileIndex(
            path: 'lib/a.dart',
            invocations: [IndexedInvocation('resolve')],
          ),
          'lib/b.dart': DartFileIndex(path: 'lib/b.dart'),
        },
      );

      expect(rule.id, 'di.resolve_only_in_composition');
      expect(rule.description, isNotEmpty);
      expect(rule.check(input).single.path, 'lib/a.dart');
      expect(input.owners, isEmpty);
      expect(input.modules, isEmpty);
      expect(input.presentRoles, isEmpty);
    });

    test('its input finds the descriptors of modules', () {
      const home = ModuleDescriptor(
        id: ModuleId('home'),
        description: 'Home',
        kind: plainKind,
      );
      final router = TestRole<String>('router');
      final input = StructuralRuleInput(
        files: const {},
        owners: const {'lib/a.dart': ModuleOrigin(ModuleId('home'))},
        modules: const [home],
        presentRoles: {router},
      );

      expect(input.module(const ModuleId('home')), same(home));
      expect(input.module(const ModuleId('other')), isNull);
      expect(input.owners['lib/a.dart'], const ModuleOrigin(ModuleId('home')));
      expect(input.presentRoles, {router});
    });
  });

  test('ModuleRule runs over the contributions of a module', () {
    const rule = ModuleRule(
      id: 'test.no_data',
      description: 'Modules contribute no data.',
      check: _flagsModulesWithData,
    );
    final role = TestRole<String>('router');
    const module = ModuleDescriptor(
      id: ModuleId('home'),
      description: 'Home',
      kind: plainKind,
    );

    expect(rule.id, 'test.no_data');
    expect(rule.description, isNotEmpty);
    expect(
      rule.check(const ModuleRuleInput(module: module, contributions: [])),
      isEmpty,
    );
    final input = ModuleRuleInput(
      module: module,
      contributions: [RoleData<String>(role, 'routes')],
      presentRoles: {role},
    );
    expect(
      rule.check(input).single.origin,
      const ModuleOrigin(ModuleId('home')),
    );
    expect(input.presentRoles, {role});
  });
}
