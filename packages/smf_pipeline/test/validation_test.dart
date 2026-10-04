import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

final class _Check extends PreflightCheck {
  const _Check(this.id);

  @override
  final String id;

  @override
  String get description => id;

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async =>
      const PreflightPassed();
}

final class _ThrowingProvider extends RoleProvider<String> {
  _ThrowingProvider(this.role);

  @override
  final Role<String> role;

  @override
  List<SmfIssue> validate(RoleHookInput<String> input) =>
      throw StateError('hook broke');
}

String _asIs(String value) => value;

/// The tag of the minimum iOS version.
const _ios = '{{{smf_app_entry__ios_deployment_target}}}';

/// Validates an app of [modules], all requested.
ValidationResult _validate(List<SmfModule> modules) {
  final registry = ModuleRegistry(modules);
  final resolution = resolutionOf(modules);
  return validate(
    registry: registry,
    resolution: resolution,
    collection: collect(resolution, testContext),
    context: testContext,
  );
}

List<String> _messages(ValidationResult result) =>
    [for (final issue in result.issues) '${issue.origin}: ${issue.message}'];

void main() {
  final entry = scaffold();

  test('a valid app has no issues', () {
    final result = _validate([
      scaffold(
        contributions: [
          const SocketContribution.code(
            AppEntryRole.bootstrapEarly,
            Fragment('early();'),
          ),
          const PubspecContribution.sdk('flutter'),
        ],
      ),
    ]);

    expect(result.issues, isEmpty);
    expect(result.hasErrors, isFalse);
    expect(result.socketOrders.keys, [
      AppEntryRole.iosDeploymentTarget,
      AppEntryRole.bootstrapEarly,
    ]);
    expect(result.pubspec.dependencies.keys, ['flutter']);
    expect(result.postGenOrder.contributions, isEmpty);
  });

  group('access', () {
    final nav = TestRole<String>('nav');
    final navSocket =
        SocketRef<CodeSocket>.role(nav, 'observers', const CodeSocket());

    test('when lists only the roles of the contributor', () {
      final result = _validate([
        entry,
        TestModule(
          'home',
          contributions: [
            CodegenRequest(when: {nav}),
          ],
        ),
      ]);

      expect(
        _messages(result),
        [
          equals(
            'home: home lists the nav role in the condition of a '
            'contribution, but does not provide, require or use it.',
          ),
        ],
      );
    });

    test('data goes only to the roles of the contributor', () {
      final template = TestTemplate<String>();
      final routes = TestRole<String>('routes', template: template);
      final result = _validate([
        entry,
        TestModule(
          'home',
          contributions: [routes.data('x')],
        ),
        TestModule('prov', providers: [RoleProvider.plain(routes)]),
      ]);

      expect(
        _messages(result).single,
        'home: home contributes data to the routes role, but does not provide, '
        'require or use it.',
      );
      // The template does not see it.
      expect(template.validated.single.data, isEmpty);
    });

    test('data of the wrong type is reported and not passed to hooks', () {
      final template = TestTemplate<String>();
      final typed = TestRole<String>('typed', template: template);
      final result = _validate([
        entry,
        TestModule(
          'home',
          uses: {typed},
          contributions: [RoleData<Object>(typed, 42)],
        ),
        TestModule('prov', providers: [RoleProvider.plain(typed)]),
      ]);

      expect(
        _messages(result),
        [
          equals(
            'home: home contributes a int to the typed role, which takes '
            'other data.',
          ),
        ],
      );
      expect(template.validated.single.data, isEmpty);
    });

    test('sockets of roles the contributor has, or of open roles', () {
      final sockets = <SocketRef>[];
      final role = TestRole<NoDsl>('owned', sockets: sockets);
      final socket =
          SocketRef<CodeSocket>.role(role, 'code', const CodeSocket());
      sockets.add(socket);
      final undeclared =
          SocketRef<CodeSocket>.role(role, 'other', const CodeSocket());
      final result = _validate([
        entry,
        TestModule(
          'user',
          uses: {role},
          contributions: [
            SocketContribution.code(socket, const Fragment('a();')),
            SocketContribution.code(undeclared, const Fragment('b();')),
            const SocketContribution.code(
              AppEntryRole.bootstrapLate,
              Fragment('late();'),
            ),
          ],
        ),
        TestModule(
          'stranger',
          contributions: [
            SocketContribution.code(socket, const Fragment('c();')),
          ],
        ),
      ]);

      expect(_messages(result), [
        'user: The owned role has no socket owned.other.',
        equals(
            'stranger: stranger puts code into the socket owned.code, but does '
            'not provide, require or use the owned role.'),
      ]);
    });

    test('sockets of modules only for direct dependents', () {
      const parent = SocketRef<CodeSocket>.module(
        ModuleId('parent'),
        'hook',
        CodeSocket(),
      );
      const missing = SocketRef<CodeSocket>.module(
        ModuleId('parent'),
        'missing',
        CodeSocket(),
      );
      final result = _validate([
        entry,
        TestModule('parent', sockets: const [parent]),
        TestModule(
          'child',
          dependsOn: {
            'parent',
          },
          contributions: [
            const SocketContribution.code(parent, Fragment('a();')),
            const SocketContribution.code(missing, Fragment('b();')),
          ],
        ),
        TestModule(
          'grandchild',
          dependsOn: {
            'child',
          },
          contributions: [
            const SocketContribution.code(parent, Fragment('c();')),
          ],
        ),
      ]);

      expect(_messages(result), [
        'child: The module parent has no socket parent.missing.',
        equals(
            'grandchild: grandchild puts code into the socket parent.hook, but '
            'only modules that depend on parent directly may.'),
      ]);
    });

    test('a role template puts no code into a socket of a module', () {
      const parent = SocketRef<CodeSocket>.module(
        ModuleId('parent'),
        'hook',
        CodeSocket(),
      );
      final shelf = TestRole<NoDsl>(
        'shelf',
        template: TestTemplate(
          contributions: [
            const SocketContribution.code(parent, Fragment('a();')),
          ],
        ),
      );

      final result = _validate([
        entry,
        TestModule('parent', sockets: const [parent]),
        TestModule('store', providers: [RoleProvider.plain(shelf)]),
      ]);

      expect(_messages(result), [
        equals(
          'role:shelf: role:shelf puts code into the socket parent.hook, but '
          'only modules that depend on parent directly may.',
        ),
      ]);
    });

    test('socket families accept their members', () {
      final families = <SocketFamily<Object?, SocketKind>>[];
      final familyRole = TestRole<NoDsl>('family', socketFamilies: families);
      final family = SocketFamily<String, CodeSocket>.role(
        familyRole,
        'screens',
        const CodeSocket(),
        keyOf: (key) => [key],
        segments: 1,
      );
      families.add(family);
      final moduleFamily = SocketFamily<String, CodeSocket>.module(
        const ModuleId('parent'),
        'items',
        const CodeSocket(),
        keyOf: (key) => [key],
      );
      final unknown = SocketFamily<String, CodeSocket>.role(
        familyRole,
        'other',
        const CodeSocket(),
        keyOf: (key) => [key],
      );
      final result = _validate([
        entry,
        TestModule(
          'parent',
          socketFamilies: [moduleFamily],
          contributions: [
            BrickContribution(
              bundle(
                'parent',
                files: {'lib/parent.dart': '{{{smf_parent__items__x}}}\n'},
              ),
            ),
          ],
        ),
        TestModule(
          'home',
          dependsOn: {'parent'},
          uses: {familyRole},
          contributions: [
            BrickContribution(
              bundle(
                'home',
                files: {'lib/home.dart': '{{{smf_family__screens__home}}}\n'},
              ),
            ),
            SocketContribution.code(family('home'), const Fragment('@A()')),
            SocketContribution.code(unknown('home'), const Fragment('@B()')),
            SocketContribution.code(moduleFamily('x'), const Fragment('y')),
          ],
        ),
      ]);

      expect(_messages(result), [
        'home: The family role has no socket family.other.home.',
      ]);
    });

    test('a role template may use the sockets of its visible roles', () {
      final di = TestRole<NoDsl>('di_like');
      final service = TestRole<NoDsl>(
        'service',
        uses: {di},
        template: TestTemplate(
          contributions: [
            const SocketContribution.code(
              AppEntryRole.bootstrapPlatform,
              Fragment('init();'),
            ),
            CodegenRequest(when: {di}),
            CodegenRequest(when: {nav}),
            SocketContribution.code(navSocket, const Fragment('x')),
          ],
        ),
      );
      final result = _validate([
        entry,
        TestModule('prov', providers: [RoleProvider.plain(service)]),
      ]);

      expect(_messages(result), [
        equals(
          'role:service: role:service lists the nav role in the condition of '
          'a contribution, but does not provide, require or use it.',
        ),
        equals('role:service: role:service puts code into the socket '
            'nav.observers, but does not provide, require or use the nav '
            'role.'),
      ]);
    });
  });

  group('bricks', () {
    test('without hooks, reserved variables or files outside the kind', () {
      const feature = ModuleKind(
        id: 'feature',
        label: 'Features',
        fileRoots: ['lib/features/<id>/'],
      );
      final result = _validate([
        entry,
        TestModule(
          'home',
          kind: feature,
          contributions: [
            BrickContribution(
              bundle(
                'home',
                paths: ['lib/features/home/a.dart', 'lib/core/home.dart'],
                hooks: true,
              ),
              vars: const {
                'app_name': 1,
                'smf_x': 1,
                'has_y': 1,
                'snakeCase': 1,
                'fine': 1,
              },
            ),
          ],
        ),
      ]);

      expect(_messages(result), [
        equals(
            'home: The brick home of home has mason hooks, which the pipeline '
            'does not run.'),
        equals('home: The brick home of home sets the variable app_name, which '
            'the pipeline sets itself.'),
        equals(
            'home: The brick home of home sets the variable smf_x, which the '
            'pipeline sets itself.'),
        equals(
            'home: The brick home of home sets the variable has_y, which the '
            'pipeline sets itself.'),
        equals(
            'home: The brick home of home sets the variable snakeCase, which '
            'the pipeline sets itself.'),
        equals(
            'home: The module home generates lib/core/home.dart, where modules '
            'of the feature kind may not.'),
      ]);
      expect(result.issues.last.path, 'lib/core/home.dart');
    });

    test('variables that mason would change are errors', () {
      final result = _validate([
        entry,
        TestModule(
          'home',
          contributions: [
            BrickContribution(
              bundle('home', paths: ['lib/a.dart']),
              vars: {
                'text': 'a\\\nb',
                'items': const ['fine', r'caf\é'],
                'map': const {'k': 'fine'},
                'number': 1,
                'lambda': (Object? context) => 'x',
                'object': Object(),
              },
            ),
          ],
        ),
      ]);

      expect(_messages(result), [
        equals(
          'home: The variable text of the brick home of home has a backslash '
          'before a line break or a non-ASCII character, which mason removes.',
        ),
        equals(
          'home: The variable items of the brick home of home has a '
          'backslash before a line break or a non-ASCII character, which '
          'mason removes.',
        ),
        equals(
          'home: The variable lambda of the brick home of home is not plain '
          'data: strings, numbers, booleans, and lists and maps of them.',
        ),
        equals(
          'home: The variable object of the brick home of home is not plain '
          'data: strings, numbers, booleans, and lists and maps of them.',
        ),
      ]);
    });

    test('a variable that depends on a role names a role of its contributor',
        () {
      final nav = TestRole<NoDsl>('nav');
      final other = TestRole<NoDsl>('other');
      // The template of a role may name the roles that its role uses.
      final shelf = TestRole<String>(
        'shelf',
        uses: {nav},
        template: TestTemplate<String>(
          contributions: [
            BrickContribution(
              bundle('shelf', paths: ['lib/shelf.dart']),
              vars: {
                'of_nav': RoleVar(nav, present: 'a', absent: 'b'),
                'of_other': RoleVar(other, present: 'a', absent: 'b'),
              },
            ),
          ],
        ),
      );
      final result = _validate([
        entry,
        TestModule('go', providers: [RoleProvider.plain(nav)]),
        TestModule('elsewhere', providers: [RoleProvider.plain(other)]),
        TestModule('store', providers: [RoleProvider.plain(shelf)]),
        TestModule(
          'home',
          uses: {nav},
          contributions: [
            BrickContribution(
              bundle('home', paths: ['lib/home.dart']),
              vars: {
                'of_nav': RoleVar(nav, present: 'a', absent: 'b'),
                'of_other': RoleVar(other, present: 'a', absent: 'b'),
                // A role open to all modules gives every module its
                // sockets and its presence flag, but a condition names
                // only a role that the module lists.
                'of_entry': const RoleVar(
                  appEntryRole,
                  present: 'a',
                  absent: 'b',
                ),
              },
            ),
          ],
        ),
      ]);

      expect(_messages(result), [
        equals(
          'home: The variable of_other of the brick home of home depends on '
          'the other role, but home does not provide, require or use it.',
        ),
        equals(
          'home: The variable of_entry of the brick home of home depends on '
          'the app entry role, but home does not provide, require or use it.',
        ),
        equals(
          'role:shelf: The variable of_other of the brick shelf of '
          'role:shelf depends on the other role, but role:shelf does not '
          'provide, require or use it.',
        ),
      ]);
      expect(
        result.issues.first.hint,
        'Add the role to the uses of the module.',
      );
    });

    test(
        'the values of a variable that depends on a role are code: fragments '
        'or strings', () {
      final nav = TestRole<NoDsl>('nav');
      const zeta = ImportRef('package:zeta/zeta.dart');
      final result = _validate([
        entry,
        TestModule(
          'home',
          uses: {nav},
          contributions: [
            BrickContribution(
              bundle('home', paths: ['lib/a.dart']),
              vars: {
                // Code: a fragment, or a string that needs no imports.
                'code': RoleVar(
                  nav,
                  present: const Fragment('Zeta()', imports: [zeta]),
                  absent: "'none'",
                ),
                'fragments': RoleVar(
                  nav,
                  present: const Fragment('a();'),
                  absent: const Fragment(''),
                ),
                'strings': RoleVar(nav, present: 'a();', absent: ''),
                'has_x': RoleVar(nav, present: 'a', absent: 'b'),
                'slash': RoleVar(
                  nav,
                  present: const Fragment('a\\\nb'),
                  absent: 'c',
                ),
                'accent': RoleVar(nav, present: 'c', absent: r'caf\é'),
                // Plain data that a template would test or iterate.
                'flag': RoleVar(nav, present: true, absent: false),
                'number': RoleVar(nav, present: 'a', absent: 1),
                'list': RoleVar(nav, present: const ['a'], absent: 'a'),
                'map': RoleVar(nav, present: 'a', absent: const {'k': 'v'}),
                'object': RoleVar(nav, present: Object(), absent: 'a'),
                'nested': RoleVar(
                  nav,
                  present: 'a',
                  absent: RoleVar(nav, present: 'a', absent: 'b'),
                ),
                'wrapper': RoleVar(
                  nav,
                  present: const Fragment.wrap('Wrap(child: ', ')'),
                  absent: '',
                ),
                'import': RoleVar(
                  nav,
                  present: '',
                  absent: const Fragment('x', imports: [ImportRef('z.dart')]),
                ),
                // Only the whole value of a variable depends on a role.
                'items': [RoleVar(nav, present: 'a', absent: 'b')],
              },
            ),
          ],
        ),
      ]);

      String notCode(String name, String state) =>
          'home: The value of the variable $name of the brick home of home '
          '$state the nav role is not code: give a fragment, or a string of '
          'code that needs no imports.';
      expect(_messages(result), [
        equals(
          'home: The brick home of home sets the variable has_x, which the '
          'pipeline sets itself.',
        ),
        equals(
          'home: The variable slash of the brick home of home has a backslash '
          'before a line break or a non-ASCII character, which mason removes.',
        ),
        equals(
          'home: The variable accent of the brick home of home has a '
          'backslash before a line break or a non-ASCII character, which '
          'mason removes.',
        ),
        equals(
          'home: The variable items of the brick home of home is not plain '
          'data: strings, numbers, booleans, and lists and maps of them.',
        ),
        notCode('flag', 'with'),
        notCode('flag', 'without'),
        notCode('number', 'without'),
        notCode('list', 'with'),
        notCode('map', 'without'),
        notCode('object', 'with'),
        notCode('nested', 'without'),
        equals(
          'home: The value of the variable wrapper of the brick home of home '
          'with the nav role is a Fragment.wrap, but a variable takes a '
          'Fragment of code.',
        ),
        startsWith(
          'home: The value of the variable import of the brick home of home '
          'without the nav role has an invalid import. The import "z.dart" '
          'must be a dart: or package: URI',
        ),
      ]);
    });

    test('files of one machine or build are errors', () {
      final result = _validate([
        entry,
        TestModule(
          'ios',
          contributions: [
            BrickContribution(
              bundle(
                'ios',
                paths: [
                  'ios/Runner.xcodeproj/xcuserdata/me.xcuserdatad/x.plist',
                  'lib/.DS_Store',
                  'ios/Pods/Manifest.lock',
                  'lib/{{name}}/.DS_Store',
                  'lib/ios.dart',
                ],
              ),
            ),
          ],
        ),
      ]);

      expect(_messages(result), [
        equals('ios: The brick ios of ios generates '
            'ios/Runner.xcodeproj/xcuserdata/me.xcuserdatad/x.plist, which '
            'holds the Xcode settings of one user.'),
        equals('ios: The brick ios of ios generates lib/.DS_Store, which is '
            'left behind by the operating system.'),
        equals('ios: The brick ios of ios generates ios/Pods/Manifest.lock, '
            'which is written when the pods of the app are installed.'),
      ]);
      expect(result.issues.first.path, startsWith('ios/Runner.xcodeproj/'));
      expect(result.issues.first.hint, 'Remove the file from the brick.');
    });

    test('paths with variables are left to the rendering', () {
      final result = _validate([
        entry,
        TestModule(
          'a',
          contributions: [
            BrickContribution(bundle('a', paths: ['lib/{{name}}.dart'])),
          ],
        ),
        TestModule(
          'b',
          contributions: [
            BrickContribution(bundle('b', paths: ['lib/{{name}}.dart'])),
          ],
        ),
      ]);

      expect(result.issues, isEmpty);
    });

    test('every file has one brick', () {
      final result = _validate([
        // Its brick generates lib/main.dart.
        scaffold(),
        TestModule(
          'other',
          contributions: [
            BrickContribution(bundle('b', paths: ['lib/main.dart'])),
            BrickContribution(bundle('c', paths: ['lib/c.dart'])),
            BrickContribution(bundle('d', paths: ['lib/c.dart'])),
          ],
        ),
      ]);

      expect(_messages(result), [
        equals(
          'other: Both scaffold and other generate lib/main.dart; every file '
          'has one brick.',
        ),
        equals(
          'other: Two bricks of other generate lib/c.dart; every file has one '
          'brick.',
        ),
      ]);
    });
  });

  test('preflight checks need snake_case ids unique for the module', () {
    final result = _validate([
      scaffold(
        contributions: const [
          Preflight([_Check('tool'), _Check('Bad')]),
          Preflight([_Check('tool')]),
        ],
      ),
      TestModule(
        'other',
        contributions: const [
          Preflight([_Check('tool')]),
        ],
      ),
    ]);

    expect(_messages(result), [
      contains('"Bad" of scaffold'),
      contains('"tool" of scaffold'),
    ]);
  });

  test('a post-generation step needs checks of its own module', () {
    final nav = TestRole<String>('nav');
    final result = _validate([
      scaffold(
        contributions: const [
          Preflight([_Check('tool')]),
          PostGenStep(ToolRef('tool'), ['a'], needs: ['tool']),
          PostGenStep(
            ToolRef('tool'),
            ['b'],
            description: 'Step b',
            needs: ['login'],
          ),
        ],
      ),
      TestModule(
        'other',
        uses: {nav},
        contributions: [
          const Preflight([_Check('login')]),
          // A check that does not apply is still one of the module.
          Preflight(const [_Check('late')], when: {nav}),
          const PostGenStep(ToolRef('x'), ['c'], needs: ['login', 'late']),
          const PostGenStep(ToolRef('x'), ['d'], needs: ['tool']),
        ],
      ),
    ]);

    expect(_messages(result), [
      equals('scaffold: The step Step b of scaffold needs the preflight check '
          '"login", which scaffold does not have.'),
      equals('other: The step x of other needs the preflight check "tool", '
          'which other does not have.'),
    ]);
  });

  group('steps that continue other steps', () {
    const configure = PostGenStepId(ModuleId('core'), 'configure');
    const fix = PostGenStepId(ModuleId('crash'), 'fix');

    /// The module core, with its step [configure], which runs the tool
    /// configure, and [more].
    TestModule core({List<Contribution> more = const []}) => TestModule(
          'core',
          contributions: [
            const PostGenStep(ToolRef('configure'), [], id: configure),
            ...more,
          ],
        );

    /// The tools of the steps that apply in [result], in their order.
    List<String> tools(ValidationResult result) => [
          for (final collected in result.postGenOrder.contributions)
            (collected.contribution as PostGenStep).tool.executable,
        ];

    test(
        'continue the steps of their module and of the modules that it '
        'depends on directly', () {
      final result = _validate([
        entry,
        core(
          more: const [
            PostGenStep(ToolRef('check'), [], followUpOf: configure),
          ],
        ),
        TestModule(
          'crash',
          dependsOn: {'core'},
          contributions: const [
            PostGenStep(ToolRef('fix'), [], id: fix, followUpOf: configure),
            PostGenStep(ToolRef('verify'), [], followUpOf: fix),
          ],
        ),
      ]);

      expect(result.issues, isEmpty);
      expect(tools(result), ['configure', 'check', 'fix', 'verify']);
    });

    test(
        'may not continue the steps of a module that their module does not '
        'depend on directly', () {
      final nav = TestRole<String>(
        'nav',
        template: TestTemplate(
          contributions: const [
            PostGenStep(ToolRef('t'), [], followUpOf: configure),
          ],
        ),
      );
      final result = _validate([
        entry,
        core(),
        TestModule('crash', dependsOn: {'core'}),
        TestModule(
          'other',
          contributions: const [
            PostGenStep(
              ToolRef('a'),
              [],
              description: 'Step a',
              followUpOf: configure,
            ),
          ],
        ),
        TestModule(
          'indirect',
          dependsOn: {'crash'},
          contributions: const [
            PostGenStep(ToolRef('b'), [], followUpOf: configure),
          ],
        ),
        TestModule('prov', providers: [RoleProvider.plain(nav)]),
      ]);

      expect(_messages(result), [
        equals(
          'other: The step Step a of other continues the step '
          'core.configure, but only core and the modules that depend on it '
          'directly may.',
        ),
        equals(
          'indirect: The step b of indirect continues the step '
          'core.configure, but only core and the modules that depend on it '
          'directly may.',
        ),
        equals(
          'role:nav: The step t of role:nav continues the step '
          'core.configure, but only core and the modules that depend on it '
          'directly may.',
        ),
      ]);
    });

    test('continue a step that the module whose step it is has', () {
      final result = _validate([
        entry,
        core(),
        TestModule(
          'crash',
          dependsOn: {'core'},
          contributions: const [
            PostGenStep(
              ToolRef('fix'),
              [],
              description: 'Fix',
              followUpOf: PostGenStepId(ModuleId('core'), 'deploy'),
            ),
            PostGenStep(
              ToolRef('check'),
              [],
              followUpOf: PostGenStepId(ModuleId('crash'), 'missing'),
            ),
          ],
        ),
      ]);

      expect(_messages(result), [
        equals(
          'crash: The step Fix of crash continues the step core.deploy, but '
          'core has no step with that id.',
        ),
        equals(
          'crash: The step check of crash continues the step crash.missing, '
          'but crash has no step with that id.',
        ),
      ]);
      expect(tools(result), ['configure']);
    });

    test(
        'do not apply when the step they continue does not, and need '
        'nothing of the run then', () {
      final nav = TestRole<String>('nav');
      final modules = [
        entry,
        TestModule(
          'core',
          uses: {nav},
          contributions: [
            PostGenStep(
              const ToolRef('configure'),
              const [],
              id: configure,
              when: {nav},
            ),
          ],
        ),
        TestModule(
          'crash',
          dependsOn: {'core'},
          contributions: const [
            PostGenStep(
              ToolRef('fix'),
              [],
              id: fix,
              followUpOf: configure,
              interactive: true,
            ),
            PostGenStep(ToolRef('check'), [], followUpOf: fix, external: true),
          ],
        ),
      ];
      final resolution = resolutionOf(modules);
      final result = validate(
        registry: ModuleRegistry(modules),
        resolution: resolution,
        collection: collect(resolution, testContext),
        context: testContext,
        interactive: false,
        skipExternalSetup: true,
      );

      expect(result.issues, isEmpty);
      expect(result.postGenOrder.contributions, isEmpty);
    });

    test('have no conditions of their own', () {
      final nav = TestRole<String>('nav');
      final result = _validate([
        entry,
        TestModule(
          'core',
          uses: {nav},
          contributions: [
            PostGenStep(
              const ToolRef('configure'),
              const [],
              id: configure,
              when: {nav},
            ),
          ],
        ),
        TestModule(
          'crash',
          dependsOn: {'core'},
          uses: {nav},
          contributions: [
            const PostGenStep(ToolRef('fix'), [], followUpOf: configure),
            PostGenStep(
              const ToolRef('check'),
              const [],
              description: 'Check',
              followUpOf: configure,
              when: {nav},
            ),
          ],
        ),
      ]);

      expect(
        _messages(result).single,
        'crash: The step Check of crash continues another step, but has '
        'conditions of its own.',
      );
      expect(
        result.issues.single.hint,
        'A step that continues another applies whenever that step does.',
      );
    });

    test('need checks of their own module', () {
      final result = _validate([
        entry,
        core(
          more: const [
            Preflight([_Check('login')]),
          ],
        ),
        TestModule(
          'crash',
          dependsOn: {'core'},
          contributions: const [
            Preflight([_Check('tool')]),
            PostGenStep(
              ToolRef('fix'),
              [],
              followUpOf: configure,
              needs: ['tool'],
            ),
            PostGenStep(
              ToolRef('check'),
              [],
              description: 'Check',
              followUpOf: configure,
              needs: ['login'],
            ),
          ],
        ),
      ]);

      expect(
        _messages(result).single,
        'crash: The step Check of crash needs the preflight check "login", '
        'which crash does not have.',
      );
    });

    test('continue each other in a cycle, and would never run', () {
      const a = PostGenStepId(ModuleId('core'), 'a');
      const b = PostGenStepId(ModuleId('core'), 'b');
      const self = PostGenStepId(ModuleId('core'), 'self');
      final result = _validate([
        entry,
        core(
          more: const [
            PostGenStep(ToolRef('a'), [], id: a, followUpOf: b),
            PostGenStep(ToolRef('b'), [], id: b, followUpOf: a),
            PostGenStep(ToolRef('self'), [], id: self, followUpOf: self),
            // It continues a step of the cycle, but is not on it.
            PostGenStep(ToolRef('c'), [], followUpOf: a),
          ],
        ),
      ]);

      expect(_messages(result), [
        equals(
          'core: The steps core.a and core.b of core continue each other in a '
          'cycle, so none of them would run.',
        ),
        equals(
          'core: The step core.self of core continues itself, so it would '
          'never run.',
        ),
      ]);
      expect(tools(result), ['configure']);
    });
  });

  test(
      'a post-generation step has an id of its own module, which no other '
      'step has', () {
    const configure = PostGenStepId(ModuleId('core'), 'configure');
    final nav = TestRole<String>(
      'nav',
      template: TestTemplate(
        contributions: const [
          PostGenStep(
            ToolRef('t'),
            [],
            id: PostGenStepId(ModuleId('nav'), 'setup'),
          ),
        ],
      ),
    );
    final result = _validate([
      entry,
      TestModule(
        'core',
        contributions: const [
          PostGenStep(ToolRef('configure'), [], id: configure),
          PostGenStep(ToolRef('again'), [], id: configure),
        ],
      ),
      TestModule(
        'other',
        contributions: const [
          PostGenStep(ToolRef('mine'), [], description: 'Mine', id: configure),
        ],
      ),
      TestModule('prov', providers: [RoleProvider.plain(nav)]),
    ]);

    expect(_messages(result), [
      equals(
        'other: The step Mine of other has the id core.configure, but only '
        'core gives its steps the ids of core.',
      ),
      equals(
        'role:nav: The step t of role:nav has the id nav.setup, but only '
        'nav gives its steps the ids of nav.',
      ),
      equals(
        'core: Two steps of core have the id core.configure; a step '
        'continues the one step with its id.',
      ),
      equals(
        'other: Both core and other have a step with the id '
        'core.configure; a step continues the one step with its id.',
      ),
    ]);
  });

  test('kinds require and forbid data', () {
    final nav = TestRole<String>('nav');
    final feature = ModuleKind(
      id: 'feature',
      label: 'Features',
      requiredData: {nav},
    );
    final infra = ModuleKind(
      id: 'infra',
      label: 'Infrastructure',
      forbiddenData: {nav},
    );
    final result = _validate([
      entry,
      TestModule('home', kind: feature, uses: {nav}),
      TestModule(
        'sneaky',
        kind: infra,
        uses: {
          nav,
        },
        contributions: [
          nav.data('/x'),
        ],
      ),
    ]);

    expect(_messages(result), [
      equals(
          'home: The module home is of the feature kind, so it must contribute '
          'data to the nav role.'),
      equals('sneaky: The module sneaky is of the infra kind, so it must not '
          'contribute data to the nav role.'),
    ]);
  });

  group('packages of providers', () {
    final state = TestRole<String>('state');
    final nav = TestRole<String>('nav');
    const pinned = PubspecContribution.hosted('flutter_bloc', '^9.1.1');
    const taken = PubspecContribution.hosted('flutter_bloc', 'any');

    TestModule provider(
      String id,
      Role<Object> role, {
      Set<String> dependsOn = const {},
      List<Contribution> contributions = const [],
    }) =>
        TestModule(
          id,
          dependsOn: dependsOn,
          providers: [RoleProvider.plain(role)],
          contributions: contributions,
        );

    /// Validates an app of [modules], all requested, in which the module
    /// named by a key of [variants] has its variant for the provider of the
    /// value.
    ValidationResult validateWith(
      List<SmfModule> modules, {
      Map<String, String> variants = const {},
    }) {
      final resolution = Resolution([
        for (final module in modules)
          ResolvedModule(
            module,
            const Requested(),
            variant: switch (variants[module.descriptor.id.value]) {
              final id? => ModuleId(id),
              null => null,
            },
          ),
      ]);
      return validate(
        registry: ModuleRegistry(modules),
        resolution: resolution,
        collection: collect(resolution, testContext),
        context: testContext,
      );
    }

    test('a module takes one in its variant for it or by depending on it', () {
      final base = TestRole<String>('base');
      final theme = TestRole<String>('theme');
      final result = validateWith(
        [
          entry,
          provider('bloc', state, contributions: const [pinned]),
          TestModule(
            'feature',
            variants: Variants(
              role: state,
              byProvider: {
                const ModuleId('bloc'): (_) => const [taken],
              },
            ),
          ),
          TestModule('direct', dependsOn: {'bloc'}, contributions: [taken]),
          TestModule(
            'through',
            dependsOn: {'direct'},
            contributions: const [
              PubspecContribution.hosted('flutter_bloc', '^9.1.0', dev: true),
            ],
          ),
          // A variant for a provider that depends on the provider of the
          // package.
          provider(
            'router_base',
            base,
            contributions: const [
              PubspecContribution.hosted('router_lib', '^1.0.0'),
            ],
          ),
          provider('auto', nav, dependsOn: {'router_base'}),
          TestModule(
            'page',
            variants: Variants(
              role: nav,
              byProvider: {
                const ModuleId('auto'): (_) => const [
                      PubspecContribution.hosted('router_lib', 'any'),
                    ],
              },
            ),
          ),
          // A provider whose variant for bloc has a constraint of its own:
          // a variant brings nothing, so the package stays of bloc.
          TestModule(
            'styles',
            providers: [RoleProvider.plain(theme)],
            variants: Variants(
              role: state,
              byProvider: {
                const ModuleId('bloc'): (_) => const [
                      PubspecContribution.hosted('flutter_bloc', '^9.1.0'),
                    ],
              },
            ),
          ),
        ],
        variants: {'feature': 'bloc', 'page': 'auto', 'styles': 'bloc'},
      );

      expect(result.issues, isEmpty);
    });

    test('any other module that contributes one is at fault', () {
      final absent = TestRole<String>('absent');
      final result = validateWith(
        [
          entry,
          provider('bloc', state, contributions: const [pinned]),
          provider('go', nav),
          TestModule('rogue', contributions: [taken]),
          // With a constraint of its own, as a dev dependency, and in a
          // contribution that does not apply in the app.
          TestModule(
            'pinned',
            uses: {absent},
            contributions: [
              PubspecContribution.hosted(
                'flutter_bloc',
                '^9.1.1',
                dev: true,
                when: {absent},
              ),
            ],
          ),
          // Twice, as a dependency and as a dev dependency: one problem.
          TestModule(
            'twice',
            contributions: const [
              taken,
              PubspecContribution.hosted('flutter_bloc', 'any', dev: true),
            ],
          ),
          // In its variant for another provider.
          TestModule(
            'page',
            variants: Variants(
              role: nav,
              byProvider: {
                const ModuleId('go'): (_) => const [taken],
              },
            ),
          ),
          // Outside its variant for the provider.
          TestModule(
            'feature',
            variants: Variants(
              role: state,
              byProvider: {
                const ModuleId('bloc'): (_) => const [taken],
              },
            ),
            contributions: [taken],
          ),
        ],
        variants: {'page': 'go', 'feature': 'bloc'},
      );

      String problem(String origin, String module) =>
          '$origin: $origin contributes flutter_bloc, a package of bloc, '
          'which provides the state role, but $module neither has a variant '
          'for it nor depends on it.';
      expect(_messages(result), [
        problem('rogue', 'rogue'),
        problem('pinned', 'pinned'),
        problem('twice', 'twice'),
        problem('page (go)', 'page'),
        equals(
          'feature: feature contributes flutter_bloc, a package of bloc, '
          'which provides the state role, outside its variant for bloc.',
        ),
      ]);
      expect(
        result.issues.first.hint,
        'A module takes the package of a provider of a role only in its '
        'variant for the provider, with the constraint any, or by depending '
        'on the provider.',
      );
      expect(
        result.issues[3].origin,
        const ModuleOrigin(ModuleId('page'), variant: ModuleId('go')),
      );
      expect(
        result.issues.last.hint,
        'Contribute flutter_bloc in the variant of feature for bloc, with the '
        'constraint any.',
      );
      expect(
        result.issues.last.origin,
        const ModuleOrigin(ModuleId('feature')),
      );
    });

    test('packages that no provider of a role brings are shared', () {
      final result = validateWith([
        entry,
        provider(
          'go',
          nav,
          contributions: const [
            PubspecContribution.hosted('collection', 'any'),
            PubspecContribution.sdk('flutter_localizations'),
          ],
        ),
        TestModule(
          'a',
          contributions: const [
            PubspecContribution.hosted('collection', 'any'),
            PubspecContribution.hosted('json_annotation', '^4.9.0'),
            PubspecContribution.sdk('flutter_localizations'),
          ],
        ),
        TestModule(
          'b',
          contributions: const [
            PubspecContribution.hosted('json_annotation', '^4.9.0'),
          ],
        ),
      ]);

      expect(result.issues, isEmpty);
    });

    test('a provider that repeats a package of its dependency does not own it',
        () {
      final tracking = TestRole<String>(
        'tracking',
        cardinality: RoleCardinality.many,
      );
      final crashes = TestRole<String>(
        'crashes',
        cardinality: RoleCardinality.many,
      );
      const core = PubspecContribution.hosted('firebase_core', '^4.15.0');
      final result = validateWith([
        entry,
        TestModule('firebase', contributions: const [core]),
        provider(
          'analytics',
          tracking,
          dependsOn: {'firebase'},
          contributions: const [core],
        ),
        provider(
          'crash',
          crashes,
          dependsOn: {'firebase'},
          contributions: const [core],
        ),
      ]);

      expect(result.issues, isEmpty);
    });

    test('two providers that bring a package take it from each other', () {
      const shared = PubspecContribution.hosted('shared_lib', '^1.0.0');
      const user = PubspecContribution.hosted('shared_lib', 'any');
      final result = validateWith([
        entry,
        provider('bloc', state, contributions: const [shared]),
        provider('go', nav, contributions: const [shared]),
        TestModule('user', contributions: const [user]),
        // Depends on one of the two: enough.
        TestModule('near', dependsOn: {'go'}, contributions: const [user]),
      ]);

      expect(_messages(result), [
        equals(
          'bloc: bloc contributes shared_lib, a package of go, which provides '
          'the nav role, but bloc neither has a variant for it nor depends on '
          'it.',
        ),
        equals(
          'go: go contributes shared_lib, a package of bloc, which provides '
          'the state role, but go neither has a variant for it nor depends on '
          'it.',
        ),
        equals(
          'user: user contributes shared_lib, a package of bloc, which '
          'provides the state role, and of go, which provides the nav role, '
          'but user '
          'neither has a variant for any of them nor depends on any of them.',
        ),
      ]);

      // Once one depends on the other, the package is of the other alone.
      expect(
        validateWith([
          entry,
          provider('bloc', state, contributions: const [shared]),
          provider(
            'go',
            nav,
            dependsOn: {'bloc'},
            contributions: const [shared],
          ),
          TestModule('user', dependsOn: {'go'}, contributions: const [user]),
        ]).issues,
        isEmpty,
      );
    });

    test('names every role of a provider', () {
      final result = validateWith([
        entry,
        TestModule(
          'kit',
          providers: [
            RoleProvider.plain(state),
            RoleProvider.plain(nav),
            RoleProvider.plain(TestRole<String>('theme')),
          ],
          contributions: const [pinned],
        ),
        TestModule('rogue', contributions: [taken]),
      ]);

      expect(
        result.issues.single.message,
        'rogue contributes flutter_bloc, a package of kit, which provides the '
        'state role, the nav role and the theme role, but rogue neither has a '
        'variant for it nor depends on it.',
      );
    });
  });

  test('the app may not be named like a dependency', () {
    final registry = ModuleRegistry([
      scaffold(
        contributions: const [PubspecContribution.hosted('my_app', 'any')],
      ),
    ]);
    final resolution = resolutionOf(registry.modules);

    final result = validate(
      registry: registry,
      resolution: resolution,
      collection: collect(resolution, testContext),
      context: testContext,
    );

    expect(
      result.issues.single.message,
      'The app is named my_app, like its dependency from scaffold, and a '
      'package cannot depend on itself.',
    );
    expect(result.issues.single.origin, isNull);
  });

  test('the pubspec needs a Dart SDK constraint', () {
    final result = _validate([
      TestModule(
        'bare',
        kind: ModuleKinds.scaffold,
        providers: [const RoleProvider.plain(appEntryRole)],
        contributions: [
          AppEntryRole.iosDeploymentTarget.value('13.0'),
          BrickContribution(
            bundle('ios', files: {'ios/Podfile': "platform :ios, '$_ios'"}),
          ),
        ],
      ),
    ]);

    expect(
      result.issues.single.message,
      'No module sets the Dart SDK constraint of the app, which pub needs in '
      'every pubspec.yaml.',
    );
    expect(result.issues.single.origin, isNull);
  });

  test('a section of the pubspec with entries needs its tag', () {
    BrickContribution pubspec(String text) =>
        BrickContribution(bundle('app', files: {'pubspec.yaml': text}));
    const withoutFlutter = 'name: app\n'
        '{{{smf_pubspec_environment}}}\n'
        '{{{smf_pubspec_dependencies}}}\n'
        '{{{smf_pubspec_dev_dependencies}}}\n';

    final podfile = BrickContribution(
      bundle('ios', files: {'ios/Podfile': "platform :ios, '$_ios'"}),
    );
    expect(
      _messages(
        _validate([
          scaffold(
            bricks: false,
            contributions: [
              pubspec(withoutFlutter),
              podfile,
              const PubspecContribution.flutter(assets: ['assets/']),
            ],
          ),
        ]),
      ),
      [
        equals(
          'scaffold: The pubspec.yaml of scaffold has no tag '
          'smf_pubspec_flutter, so that section of the pubspec would be '
          'lost.',
        ),
      ],
    );
    expect(
      _validate([
        scaffold(
          bricks: false,
          contributions: [pubspec(withoutFlutter), podfile],
        ),
      ]).issues,
      isEmpty,
    );
  });

  test('the outputs of code generation are Dart files inside the app', () {
    String problem(String output) =>
        'scaffold: The output $output of the code generation of scaffold is '
        'not the path of a Dart file inside the app, such as '
        'lib/core/di/dependencies.config.dart.';

    expect(
      _messages(
        _validate([
          scaffold(
            contributions: const [
              CodegenRequest(
                outputs: [
                  'lib/di.config.dart',
                  '../outside.dart',
                  'lib/notes.txt',
                  r'lib\win.dart',
                ],
              ),
            ],
          ),
        ]),
      ),
      [
        problem('../outside.dart'),
        problem('lib/notes.txt'),
        problem(r'lib\win.dart'),
      ],
    );
  });

  test('code generation adds build_runner to the dev dependencies', () {
    final result = _validate([
      scaffold(
        contributions: const [
          CodegenRequest(),
          PubspecContribution.hosted('json_serializable', '^6.9.0', dev: true),
        ],
      ),
    ]);
    final without = _validate([entry]);

    expect(result.issues, isEmpty);
    final builder = result.pubspec.devDependencies['build_runner']!;
    expect(builder.constraintText, '^2.10.0');
    expect(builder.origins, [const PipelineOrigin()]);
    expect(without.pubspec.devDependencies, isNot(contains('build_runner')));

    // A module that needs an older build_runner is at fault.
    final older = _validate([
      scaffold(
        contributions: const [
          CodegenRequest(),
          PubspecContribution.hosted(
            'build_runner',
            '>=2.4.0 <2.10.0',
            dev: true,
          ),
        ],
      ),
    ]);
    expect(older.issues.single.message, contains('have no version in common'));
    expect(
      older.issues.single.origin,
      const ModuleOrigin(ModuleId('scaffold')),
    );
  });

  test('a constraint that is not one is reported once, by the merge', () {
    final result = _validate([
      entry,
      TestModule(
        'store',
        contributions: const [PubspecContribution.hosted('y', 'not a version')],
      ),
    ]);

    expect(_messages(result), [
      'store: The constraint "not a version" of y is invalid.',
    ]);
  });

  test('pubspec problems are reported', () {
    final result = _validate([
      scaffold(
        contributions: const [
          PubspecContribution.hosted('x', '^1.0.0'),
          PubspecContribution.hosted('x', '^2.0.0'),
        ],
      ),
    ]);

    expect(result.issues.single.message, contains('no version in common'));
  });

  group('hooks', () {
    test('runs the template, providers and module rules of present roles', () {
      final template = TestTemplate<String>(
        issues: const [SmfIssue('template says no')],
      );
      final hooked = TestRole<String>(
        'hooked',
        template: template,
        moduleRules: const [
          ModuleRule(id: 'hooked.count', description: 'Counts', check: _count),
        ],
      );
      final provider = TestProvider<String>(
        hooked,
        issues: const [SmfIssue.warning('provider says maybe')],
      );
      final result = _validate([
        entry,
        TestModule(
          'home',
          requires: {
            hooked,
          },
          contributions: [
            hooked.data('from home'),
          ],
        ),
        TestModule('prov', providers: [provider]),
      ]);

      expect(_messages(result), [
        'role:hooked: template says no',
        'prov: provider says maybe',
        'home: home has 1 data',
      ]);
      expect(result.issues[1].isError, isFalse);
      expect(template.validated.single.data.single.value, 'from home');
      expect(provider.validated.single.data.single.value, 'from home');
    });

    test('a hook that throws is an issue of its owner', () {
      final role = TestRole<String>('broken');
      final result = _validate([
        entry,
        TestModule('prov', providers: [_ThrowingProvider(role)]),
      ]);

      expect(
        _messages(result).single,
        startsWith('prov: A check of prov failed: Bad state: hook broke'),
      );
    });
  });

  test('a step that cannot run must be skippable', () {
    const d = PostGenStepId(ModuleId('scaffold'), 'd');
    final modules = [
      scaffold(
        contributions: const [
          PostGenStep(ToolRef('a'), [], interactive: true),
          PostGenStep(ToolRef('b'), [], external: true, description: 'Log in'),
          PostGenStep(ToolRef('c'), [], interactive: true, skippable: true),
          PostGenStep(ToolRef('d'), [], id: d, skippable: true),
        ],
      ),
      // Steps that continue a step of the module that they depend on.
      TestModule(
        'other',
        dependsOn: {'scaffold'},
        contributions: const [
          PostGenStep(
            ToolRef('e'),
            [],
            followUpOf: d,
            external: true,
            skippable: true,
          ),
          PostGenStep(ToolRef('f'), [], followUpOf: d, interactive: true),
        ],
      ),
    ];
    final registry = ModuleRegistry(modules);
    final resolution = resolutionOf(modules);
    ValidationResult run({required bool interactive, bool skip = false}) =>
        validate(
          registry: registry,
          resolution: resolution,
          collection: collect(resolution, testContext),
          context: testContext,
          interactive: interactive,
          skipExternalSetup: skip,
        );

    expect(run(interactive: true).issues, isEmpty);
    expect(
      run(interactive: false, skip: true).issues.map((i) => i.message),
      [
        equals(
          'The step a of scaffold cannot run without a terminal, and the app '
          'is not complete without it.',
        ),
        equals(
          'The step Log in of scaffold cannot run with --skip-external-setup, '
          'and the app is not complete without it.',
        ),
        // A step that continues another too, of its own module.
        equals(
          'The step f of other cannot run without a terminal, and the app is '
          'not complete without it.',
        ),
      ],
    );
  });

  group('sockets', () {
    test('code for a socket without a tag is an error of its owner', () {
      final sockets = <SocketRef>[];
      final nav = TestRole<NoDsl>('tabs', sockets: sockets);
      final observers = SocketRef<FactoryListSocket>.role(
        nav,
        'observers',
        const FactoryListSocket(),
      );
      sockets.add(observers);
      const hook = SocketRef<CodeSocket>.module(
        ModuleId('parent'),
        'hook',
        CodeSocket(),
      );

      expect(
        _messages(
          _validate([
            entry,
            TestModule('go', providers: [RoleProvider.plain(nav)]),
            TestModule('parent', sockets: const [hook]),
            TestModule(
              'child',
              dependsOn: {'parent'},
              uses: {nav},
              contributions: [
                SocketContribution.item(
                  observers,
                  const Fragment('() => Watcher()'),
                ),
                const SocketContribution.code(hook, Fragment('a();')),
              ],
            ),
          ]),
        ),
        [
          equals(
            'go: child contributes to the socket tabs.observers, but no '
            'template of the app has its tag smf_tabs__observers, so what '
            'they contribute would be lost.',
          ),
          equals(
            'parent: child contributes to the socket parent.hook, but no '
            'template of the app has its tag smf_parent__hook, so what they '
            'contribute would be lost.',
          ),
        ],
      );
    });

    test('a required value of a module is an error of the module', () {
      const version = SocketRef<ValueSocket<String>>.module(
        ModuleId('lib_x'),
        'version',
        ValueSocket(policy: MaxPolicy(), renderer: _asIs, required: true),
      );

      expect(
        _messages(
          _validate([
            entry,
            TestModule('lib_x', sockets: const [version]),
          ]),
        ),
        [
          equals(
            'lib_x: The socket lib_x.version needs a value, but nothing '
            'contributes one; the module lib_x contributes its base value.',
          ),
        ],
      );
    });

    test(
        'a required value that nothing contributes is an error of the '
        'provider', () {
      final result = _validate([
        TestModule(
          'bare',
          kind: ModuleKinds.scaffold,
          providers: [const RoleProvider.plain(appEntryRole)],
          contributions: [
            const PubspecContribution.environment(sdk: '^3.8.1'),
          ],
        ),
      ]);

      expect(
        _messages(result).single,
        'bare: The ${AppEntryRole.iosDeploymentTarget} needs a value, but '
        'nothing contributes one; the provider of the app entry role '
        'contributes '
        'its base value.',
      );
      expect(result.hasErrors, isTrue);
    });

    test('are ordered, and conflicts name their contributors', () {
      final result = _validate([
        entry,
        TestModule(
          'a',
          contributions: [
            AppEntryRole.iosDeploymentTarget.value('13.0'),
            AppEntryRole.infoPlist.entry(
              'Name',
              const PlistString('A'),
            ),
          ],
        ),
        TestModule(
          'b',
          contributions: [
            AppEntryRole.iosDeploymentTarget.value('15.0'),
            AppEntryRole.infoPlist.entry(
              'Name',
              const PlistString('B'),
            ),
          ],
        ),
      ]);

      expect(
        result.socketOrders[AppEntryRole.iosDeploymentTarget]!.contributions
            .map((c) => '${c.origin}'),
        ['a', 'b', 'scaffold'],
      );
      expect(result.issues.single.origin, const ModuleOrigin(ModuleId('b')));
      expect(result.issues.single.message, contains('from a and b'));
    });

    test('invalid contributions are reported once and not rendered', () {
      final result = _validate([
        scaffold(
          contributions: [
            AppEntryRole.iosDeploymentTarget.value('not a version'),
          ],
        ),
      ]);

      expect(result.issues.single.message, contains('cannot be compared'));
    });

    test('text that mason would change once joined is an error', () {
      final result = _validate([
        scaffold(
          contributions: [
            const SocketContribution.code(
              AppEntryRole.bootstrapLate,
              Fragment(r'a \\'),
            ),
            const SocketContribution.code(
              AppEntryRole.bootstrapLate,
              Fragment('b'),
            ),
          ],
        ),
      ]);

      expect(
        result.issues.single.message,
        contains('socket app_entry.bootstrap_late cannot be rendered'),
      );
    });

    test('edges both ways between two modules are no cycle', () {
      final x = TestRole<NoDsl>('x');
      final y = TestRole<NoDsl>('y');
      final result = _validate([
        entry,
        TestModule(
          'a',
          requires: {x},
          providers: [RoleProvider.plain(y)],
          contributions: [
            const SocketContribution.code(
              AppEntryRole.bootstrapLate,
              Fragment('a();'),
            ),
            const PostGenStep(ToolRef('a'), []),
          ],
        ),
        TestModule(
          'b',
          requires: {y},
          providers: [RoleProvider.plain(x)],
          contributions: [
            const SocketContribution.code(
              AppEntryRole.bootstrapLate,
              Fragment('b();'),
            ),
            const PostGenStep(ToolRef('b'), []),
          ],
        ),
      ]);

      // Edges both ways cancel out, so two modules never form a cycle.
      expect(result.issues, isEmpty);
      expect(
        result.postGenOrder.contributions.map((c) => '${c.origin}'),
        ['a', 'b'],
      );
    });

    test('a cycle of three is reported for sockets and steps', () {
      final x = TestRole<NoDsl>('x');
      final y = TestRole<NoDsl>('y');
      final z = TestRole<NoDsl>('z');
      List<Contribution> both(String name) => [
            SocketContribution.code(
              AppEntryRole.bootstrapLate,
              Fragment('$name();'),
            ),
            PostGenStep(ToolRef(name), const []),
          ];
      final result = _validate([
        entry,
        TestModule(
          'a',
          requires: {x},
          providers: [RoleProvider.plain(z)],
          contributions: both('a'),
        ),
        TestModule(
          'b',
          requires: {y},
          providers: [RoleProvider.plain(x)],
          contributions: both('b'),
        ),
        TestModule(
          'c',
          requires: {z},
          providers: [RoleProvider.plain(y)],
          contributions: both('c'),
        ),
      ]);

      expect(result.issues, hasLength(2));
      expect(result.issues.first.message, contains('socket app_entry'));
      expect(result.issues.last.message, contains('post-generation steps'));
    });
  });
}

List<SmfIssue> _count(ModuleRuleInput<String> input) => [
      if (input.data.isNotEmpty)
        SmfIssue.warning('${input.module.id} has ${input.data.length} data'),
    ];
