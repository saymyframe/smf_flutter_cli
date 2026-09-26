import 'package:smf_contracts/lego_core.dart';
import 'package:test/test.dart';

import 'support.dart';

List<SmfIssue> _flagsResolve(StructuralRuleInput<String> input) => [
      for (final file in input.files.values)
        if (file.uses('resolve'))
          SmfIssue(
            'resolve in ${input.roleInput.data.length} routes',
            origin: input.owners[file.path],
            path: file.path,
          ),
    ];

List<SmfIssue> _flagsModulesWithData(ModuleRuleInput<String> input) => [
      for (final data in input.data)
        SmfIssue(data.value, origin: ModuleOrigin(input.module.id)),
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
          hide: ['locator'],
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
      expect(index.imports.last.hide, ['locator']);
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
      expect(index.uses('locator'), isFalse);
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
      namedParameters: ['observers'],
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
                IndexedParameter(
                  'extra',
                  kind: ParameterKind.optionalPositional,
                ),
              ],
            ),
          ),
        ),
        isEmpty,
      );
    });

    test('imports its file as a file of the app', () {
      expect(symbol.importRef, const ImportRef.app('router.dart'));
      expect(
        const RequiredFunction('f', path: 'tool/f.dart').importRef,
        const ImportRef.app('tool/f.dart'),
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
        '$prefix not require more than 0 positional arguments.',
        '$prefix accept the named parameter observers.',
        '$prefix not require the parameter debug.',
      ]);
      expect(issues.first.path, 'lib/router.dart');
    });

    group('with positional arguments', () {
      const twoArguments = RequiredFunction(
        'f',
        path: 'lib/f.dart',
        positionalArguments: 2,
      );

      List<String> problemsOf(List<ParameterKind> kinds) => twoArguments
          .checkIn({
            'lib/f.dart': DartFileIndex(
              path: 'lib/f.dart',
              declarations: [
                IndexedDeclaration(
                  name: 'f',
                  kind: DeclarationKind.function,
                  parameters: [
                    for (final (i, kind) in kinds.indexed)
                      IndexedParameter('p$i', kind: kind),
                  ],
                ),
              ],
            ),
          })
          .map((issue) => issue.message)
          .toList();

      test('accepts any names, and optional ones after required ones', () {
        expect(
          problemsOf([
            ParameterKind.requiredPositional,
            ParameterKind.requiredPositional,
          ]),
          isEmpty,
        );
        expect(
          problemsOf([
            ParameterKind.requiredPositional,
            ParameterKind.optionalPositional,
            ParameterKind.optionalPositional,
          ]),
          isEmpty,
        );
      });

      test('rejects too few or too many required positional parameters', () {
        const tooFew =
            'function f() in lib/f.dart must accept 2 positional arguments.';
        const tooMany = 'function f() in lib/f.dart must not require more '
            'than 2 positional arguments.';

        expect(problemsOf([ParameterKind.requiredPositional]), [tooFew]);
        expect(
          problemsOf([
            ParameterKind.requiredPositional,
            ParameterKind.requiredPositional,
            ParameterKind.requiredPositional,
          ]),
          [tooMany],
        );
      });
    });
  });

  group('RequiredClass', () {
    const symbol = RequiredClass(
      'AppShell',
      path: 'lib/shell.dart',
      namedParameters: ['destinations', 'body'],
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
                    IndexedParameter(
                      'key',
                      kind: ParameterKind.optionalNamed,
                      type: 'Key?',
                      annotations: ['@override'],
                    ),
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

  group('Role.checkStructure', () {
    const home = ModuleOrigin(ModuleId('home'));
    final role = TestRole<String>(
      'di',
      structuralRules: const [
        StructuralRule(
          id: 'di.resolve_only_in_composition',
          description: 'resolve is called only in composition files.',
          check: _flagsResolve,
        ),
      ],
    );
    final files = {
      'lib/a.dart': const DartFileIndex(
        path: 'lib/a.dart',
        invocations: [IndexedInvocation('resolve')],
      ),
      'lib/b.dart': const DartFileIndex(path: 'lib/b.dart'),
    };

    test('runs the rules over the indexed files and the role data', () {
      final issues = role.checkStructure(
        StructuralRuleRequest(
          hook: RoleHookRequest(
            data: [RoleData<String>(role, 'a'), RoleData<String>(role, 'b')],
            presentRoles: {role},
            context: testContext,
          ),
          files: files,
          owners: const {'lib/a.dart': home},
        ),
      );

      expect(issues.single.message, 'resolve in 2 routes');
      expect(issues.single.origin, home);
      expect(issues.single.path, 'lib/a.dart');
    });

    test('gives the rules the descriptors of the modules', () {
      const descriptor = ModuleDescriptor(
        id: ModuleId('home'),
        description: 'Home',
        kind: plainKind,
      );
      late StructuralRuleInput<String> seen;
      final spy = TestRole<String>(
        'spy',
        structuralRules: [
          StructuralRule(
            id: 'spy.input',
            description: 'Keeps its input.',
            check: (input) {
              seen = input;
              return const [];
            },
          ),
        ],
      );

      spy.checkStructure(
        StructuralRuleRequest(
          hook: RoleHookRequest(
            data: const [],
            presentRoles: {spy},
            context: testContext,
          ),
          files: files,
          modules: const [descriptor],
        ),
      );

      expect(seen.roleInput.role, same(spy));
      expect(seen.files.keys, ['lib/a.dart', 'lib/b.dart']);
      expect(seen.owners, isEmpty);
      expect(seen.modules, [descriptor]);
      expect(seen.module(const ModuleId('home')), same(descriptor));
      expect(seen.module(const ModuleId('other')), isNull);
      expect(spy.structuralRules.single.id, 'spy.input');
      expect(spy.structuralRules.single.description, 'Keeps its input.');
    });
  });

  group('Role.checkModule', () {
    final other = TestRole<NoDsl>('other');
    final role = TestRole<String>(
      'router',
      uses: {other},
      moduleRules: const [
        ModuleRule(
          id: 'router.echo',
          description: 'Reports every route of the module.',
          check: _flagsModulesWithData,
        ),
      ],
    );
    const descriptor = ModuleDescriptor(
      id: ModuleId('home'),
      description: 'Home',
      kind: plainKind,
    );

    test('runs the rules over the data of one module', () {
      final issues = role.checkModule(
        ModuleRuleRequest(
          hook: RoleHookRequest(
            data: [
              RoleData<String>(role, '/home')
                  .withOrigin(const ModuleOrigin(ModuleId('home'))),
              RoleData<String>(role, '/home/bloc').withOrigin(
                const ModuleOrigin(
                  ModuleId('home'),
                  variant: ModuleId('bloc'),
                ),
              ),
              RoleData<String>(role, '/settings')
                  .withOrigin(const ModuleOrigin(ModuleId('settings'))),
            ],
            presentRoles: {role},
            context: testContext,
          ),
          module: descriptor,
          contributions: const [],
        ),
      );

      expect(issues.map((issue) => issue.message), ['/home', '/home/bloc']);
      expect(
        role.moduleRules.single.description,
        'Reports every route of the module.',
      );
    });

    test('gives the rules only the contributions that apply', () {
      late ModuleRuleInput<String> seen;
      final spy = TestRole<String>(
        'spy',
        uses: {other},
        moduleRules: [
          ModuleRule(
            id: 'spy.input',
            description: 'Keeps its input.',
            check: (input) {
              seen = input;
              return const [];
            },
          ),
        ],
      );
      const always = PubspecContribution.hosted('a', 'any');
      final withOther = PubspecContribution.hosted('b', 'any', when: {other});
      final dataOfSpy = RoleData<String>(spy, 'routes');
      final dataOfOther = RoleData<String>(TestRole<String>('absent'), 'x');

      spy.checkModule(
        ModuleRuleRequest(
          hook: RoleHookRequest(
            data: const [],
            presentRoles: {spy},
            context: testContext,
          ),
          module: descriptor,
          contributions: [always, withOther, dataOfSpy, dataOfOther],
        ),
      );

      expect(seen.module, same(descriptor));
      expect(seen.contributions, [always, dataOfSpy]);
      expect(seen.data, isEmpty);
      expect(seen.roleInput.has(other), isFalse);
    });
  });
}
