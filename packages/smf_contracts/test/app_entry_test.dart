import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'support.dart';

/// The file of the provider with the root widget of the app.
const _appFile = 'lib/app.dart';

/// What the section of the steps by hand says below the list of the steps.
const _repeatStep = 'Repeat a step for each flavor that needs it: a service '
    'knows each id as an app of its own.';

/// A method `build` with the positional [parameters], each a name and a
/// type: by default `build(BuildContext context)`, as that of a widget.
IndexedMember _build([
  List<(String, String)> parameters = const [('context', 'BuildContext')],
]) =>
    _buildOf(MemberKind.method, parameters);

/// A member `build` of [kind] with the positional [parameters], each a name
/// and a type: by default `BuildContext context`.
IndexedMember _buildOf(
  MemberKind kind, [
  List<(String, String)> parameters = const [('context', 'BuildContext')],
]) =>
    IndexedMember(
      'build',
      kind: kind,
      parameters: [
        for (final (name, type) in parameters)
          IndexedParameter(
            name,
            kind: ParameterKind.requiredPositional,
            type: type,
          ),
      ],
    );

/// The root widget `App` of the provider, a class with [members]: by
/// default, with `build(BuildContext context)`.
IndexedDeclaration _appWidget([List<IndexedMember>? members]) =>
    IndexedDeclaration(
      name: 'App',
      kind: DeclarationKind.classType,
      members: members ?? [_build()],
    );

/// A creation of a `MaterialApp`, or of a `MaterialApp.router` if [router],
/// in the method [member] of `App`.
IndexedInvocation _root({bool router = false, String? member = 'build'}) =>
    IndexedInvocation(
      router ? 'router' : 'MaterialApp',
      target: router ? 'MaterialApp' : null,
      enclosingDeclaration: 'App',
      enclosingMember: member,
    );

/// Indexes of a minimal app that satisfies the app entry role: its root
/// widget, `App` unless [appDeclarations] says otherwise, creates a
/// `MaterialApp.router` in its `build`, unless [appCalls] says otherwise.
Map<String, DartFileIndex> _app({
  List<IndexedImport> bootstrapImports = const [
    IndexedImport('package:flutter/foundation.dart'),
  ],
  List<IndexedInvocation> mainCalls = const [
    IndexedInvocation(
      'ensureInitialized',
      target: 'WidgetsFlutterBinding',
      enclosingDeclaration: 'main',
      offset: 10,
    ),
    IndexedInvocation(
      'bootstrap',
      enclosingDeclaration: 'main',
      awaited: true,
      offset: 20,
    ),
    IndexedInvocation('runApp', enclosingDeclaration: 'main', offset: 30),
  ],
  List<IndexedInvocation>? appCalls,
  List<IndexedDeclaration>? appDeclarations,
}) {
  return {
    _appFile: DartFileIndex(
      path: _appFile,
      declarations: appDeclarations ?? [_appWidget()],
      invocations: appCalls ?? [_root(router: true)],
    ),
    AppEntryRole.mainFile: DartFileIndex(
      path: AppEntryRole.mainFile,
      declarations: const [
        IndexedDeclaration(
          name: 'main',
          kind: DeclarationKind.function,
          type: 'Future<void>',
          isAsync: true,
        ),
      ],
      invocations: mainCalls,
    ),
    AppEntryRole.bootstrapFile: DartFileIndex(
      path: AppEntryRole.bootstrapFile,
      imports: bootstrapImports,
      declarations: const [
        IndexedDeclaration(
          name: 'bootstrap',
          kind: DeclarationKind.function,
          type: 'Future<void>',
          isAsync: true,
        ),
      ],
    ),
    AppEntryRole.fallbackStartScreenFile: const DartFileIndex(
      path: AppEntryRole.fallbackStartScreenFile,
      declarations: [
        IndexedDeclaration(
          name: 'FallbackStartScreen',
          kind: DeclarationKind.classType,
          constructors: [
            IndexedConstructor(
              isConst: true,
              parameters: [
                IndexedParameter('key', kind: ParameterKind.optionalNamed),
              ],
            ),
          ],
        ),
      ],
    ),
  };
}

/// The indexes of [_app] whose root widget has a `build` with [parameters],
/// each a name and a type.
Map<String, DartFileIndex> _appWithBuildOf(List<(String, String)> parameters) =>
    _app(
      appDeclarations: [
        _appWidget([_build(parameters)]),
      ],
    );

/// What the rule of the role says of a `MaterialApp` that the provider
/// creates in the file at [path] outside a `build(BuildContext context)`.
String _outsideBuild(String path) =>
    '$path creates a MaterialApp outside a method build(BuildContext '
    'context) of a class. Every MaterialApp that the provider creates in '
    'lib/ counts, since each may be the root of the app, whose arguments '
    'from the modules read the context of such a build.';

/// Checks [files] of an app whose app entry flutter_core provides; it owns
/// each file, unless [owners] names another owner.
///
/// The app has no router unless [router] is the choice of its router.
List<SmfIssue> _check(
  Map<String, DartFileIndex> files, {
  Map<String, ContributionOrigin> owners = const {},
  RouterChoice? router,
}) {
  final request = StructuralRuleRequest(
    hook: RoleHookRequest(
      data: const [],
      presentRoles: {appEntryRole, if (router != null) routerRole},
      context: testContext,
      choices: {if (router != null) routerRole: router},
    ),
    files: files,
    owners: {
      for (final path in files.keys)
        path: const ModuleOrigin(ModuleId('flutter_core')),
      ...owners,
    },
    modules: const [
      ModuleDescriptor(
        id: ModuleId('flutter_core'),
        description: 'Flutter core',
        kind: ModuleKinds.scaffold,
        providers: [RoleProvider.plain(appEntryRole)],
      ),
      ModuleDescriptor(
        id: ModuleId('home'),
        description: 'Home',
        kind: ModuleKinds.feature,
      ),
    ],
  );
  return [
    ...appEntryRole.interface.checkSymbols(files, request.hook),
    ...appEntryRole.checkStructure(request),
  ];
}

Map<String, String> _render<V extends Object>(
  SocketRef<KeyedSocket<V>> socket,
  List<(String, V)> entries,
) =>
    socket.render([
      for (final (key, value) in entries) socket.entry(key, value),
    ]);

void main() {
  group('AppEntryRole', () {
    test('is the one entry of every app', () {
      expect(appEntryRole.id, 'app_entry');
      expect(appEntryRole.description, 'App entry');
      expect(appEntryRole.cardinality, RoleCardinality.exactlyOne);
      expect(appEntryRole.requires, isEmpty);
      // The fallback start screen depends on what the router chose.
      expect(appEntryRole.uses, {routerRole});
      expect(appEntryRole.options, isEmpty);
      expect(appEntryRole.presenceFlag, 'has_app_entry');
    });

    test('is open to every module', () {
      expect(appEntryRole.openToAllModules, isTrue);
    });

    test('has its native files in the projects of Android and iOS', () {
      // The directory of each project has the name of its platform in
      // AppIdentity.platforms, which is that of flutter create --platforms.
      final projects = {
        for (final file in const [
          AppEntryRole.androidManifestFile,
          AppEntryRole.gradleSettingsFile,
          AppEntryRole.gradleAppFile,
          AppEntryRole.infoPlistFile,
          AppEntryRole.xcodeProjectFile,
          AppEntryRole.iosEntitlementsFile,
          AppEntryRole.appDelegateFile,
        ])
          file.split('/').first,
      };

      expect(projects, {'android', 'ios'});
    });

    test('owns all its sockets, with valid and distinct tags', () {
      final sockets = appEntryRole.sockets;
      final tags = [for (final socket in sockets) ...socket.tags];

      expect(sockets, hasLength(23));
      for (final socket in sockets) {
        expect(socket.role, same(appEntryRole), reason: '$socket');
        expect(socket.problems(), isEmpty, reason: '$socket');
      }
      expect(tags.toSet(), hasLength(tags.length));
      expect(tags, contains('smf_app_entry__bootstrap_platform'));
      expect(tags, contains('smf_app_entry__root_wrappers_open'));
      expect(tags, contains('smf_app_entry__agent_sections'));
      expect(
        tags,
        containsAll([
          'smf_app_entry__android_core_library_desugaring_enabled',
          'smf_app_entry__android_core_library_desugaring_library',
          'smf_app_entry__ios_app_delegate_launch',
          'smf_app_entry__android_manifest_application_components',
          'smf_app_entry__gitignore',
        ]),
      );
    });

    test('bootstrap phases are separate sockets in start-up order', () {
      expect(
        appEntryRole.sockets.take(4).map((socket) => socket.name),
        [
          'bootstrap_early',
          'bootstrap_platform',
          'bootstrap_di',
          'bootstrap_late',
        ],
      );
    });

    test('requires main(), bootstrap() and FallbackStartScreen', () {
      expect(
        appEntryRole.interface.symbols.map((symbol) => '$symbol'),
        [
          'function main()',
          'function bootstrap()',
          'class FallbackStartScreen',
        ],
      );
      expect(
        AppEntryRole.fallbackStartScreen.importRef.resolveUri('my_app'),
        'package:my_app/core/app/fallback_start_screen.dart',
      );
      expect(
        AppEntryRole.fallbackStartScreen.whenChosen,
        {RouterRole.noStartRoute},
      );
      expect(AppEntryRole.main.whenChosen, isEmpty);
      expect(AppEntryRole.bootstrap.whenChosen, isEmpty);
      expect(
        appEntryRole.structuralRules.map((rule) => rule.id),
        [
          'app_entry.bootstrap_without_material',
          'app_entry.main_sequence',
          'app_entry.material_root',
          'app_entry.root_in_build',
          'app_entry.native_keys',
          'app_entry.ios_entitlements_signed',
          'app_entry.ios_app_id_step',
          'app_entry.flavors',
          'app_entry.agent_guide_paths',
          'app_entry.readme_generated_with',
        ],
      );
      expect(
        appEntryRole.moduleRules.map((rule) => rule.id),
        [
          'app_entry.bootstrap_phases',
          'app_entry.root_wrappers_in_main',
          'app_entry.launch_code_place',
          'app_entry.manifest_tag_places',
          'app_entry.tag_lines',
          'app_entry.ios_deployment_target_tag',
        ],
      );
    });
  });

  group('AppEntryRole rules', () {
    test('accept a correct app', () {
      expect(_check(_app()), isEmpty);
    });

    test('report missing files through the required symbols only', () {
      final issues = _check(const {});

      expect(issues, hasLength(3));
      expect(
        issues.every((issue) => issue.message.contains('is missing')),
        isTrue,
      );
    });

    test(
        'need the fallback start screen only in an app that no route '
        'starts, and no file of it in any other app', () {
      const start = RouterChoice(startPath: '/home');
      final withoutScreen = _app()
        ..remove(AppEntryRole.fallbackStartScreenFile);

      expect(_check(_app(), router: const RouterChoice()), isEmpty);
      expect(_check(withoutScreen, router: start), isEmpty);
      expect(
        [for (final issue in _check(_app(), router: start)) issue.message],
        [
          equals(
            'The app has lib/core/app/fallback_start_screen.dart, the file of '
            'class FallbackStartScreen, which only an app where no route '
            'starts the app needs.',
          ),
        ],
      );
      expect(
        [
          for (final issue in _check(
            withoutScreen,
            router: const RouterChoice(),
          ))
            issue.message,
        ],
        [contains('lib/core/app/fallback_start_screen.dart is missing')],
      );
    });

    test('reject design libraries in bootstrap.dart', () {
      final issues = _check(
        _app(
          bootstrapImports: const [
            IndexedImport('package:flutter/material.dart'),
            IndexedImport('package:flutter/cupertino.dart'),
          ],
        ),
      );

      expect(issues, hasLength(2));
      expect(issues.first.path, AppEntryRole.bootstrapFile);
      expect(issues.first.origin, const ModuleOrigin(ModuleId('flutter_core')));
      expect(issues.first.hint, contains('widgets.dart'));
    });

    test('require the start-up sequence in main()', () {
      final issues = _check(
        _app(
          mainCalls: const [
            IndexedInvocation('bootstrap', enclosingDeclaration: 'main'),
            IndexedInvocation('runApp', enclosingDeclaration: 'other'),
          ],
        ),
      );

      expect(issues.map((issue) => issue.message), [
        'main() does not call WidgetsFlutterBinding.ensureInitialized().',
        'main() does not await bootstrap().',
        'main() does not call runApp().',
      ]);
      expect(issues.first.path, AppEntryRole.mainFile);
    });

    test('require a call of bootstrap() in main()', () {
      final issues = _check(
        _app(
          mainCalls: const [
            IndexedInvocation(
              'ensureInitialized',
              target: 'WidgetsFlutterBinding',
              enclosingDeclaration: 'main',
            ),
            IndexedInvocation('runApp', enclosingDeclaration: 'main'),
          ],
        ),
      );

      expect(issues.single.message, 'main() does not call bootstrap().');
    });

    test('require the calls in order', () {
      final issues = _check(
        _app(
          mainCalls: const [
            IndexedInvocation(
              'bootstrap',
              enclosingDeclaration: 'main',
              awaited: true,
              offset: 10,
            ),
            IndexedInvocation(
              'ensureInitialized',
              target: 'WidgetsFlutterBinding',
              enclosingDeclaration: 'main',
              offset: 20,
            ),
            IndexedInvocation(
              'runApp',
              enclosingDeclaration: 'main',
              offset: 30,
            ),
          ],
        ),
      );

      expect(issues.single.message, contains('in this order'));
    });

    test('ignore an ensureInitialized() of another target', () {
      final issues = _check(
        _app(
          mainCalls: const [
            IndexedInvocation(
              'ensureInitialized',
              target: 'SomethingElse',
              enclosingDeclaration: 'main',
            ),
            IndexedInvocation(
              'bootstrap',
              enclosingDeclaration: 'main',
              awaited: true,
            ),
            IndexedInvocation('runApp', enclosingDeclaration: 'main'),
          ],
        ),
      );

      expect(issues.single.message, contains('ensureInitialized'));
    });

    test('require a MaterialApp at the root of the app', () {
      final issues = _check(
        _app(
          appCalls: const [
            IndexedInvocation('CupertinoApp', enclosingDeclaration: 'App'),
          ],
        ),
      );

      expect(issues.map((issue) => issue.message), [
        equals(
          'The root of the app must be a MaterialApp, but the module '
          'flutter_core creates none in lib/.',
        ),
      ]);
      expect(
        issues.single.origin,
        const ModuleOrigin(ModuleId('flutter_core')),
      );
      expect(issues.single.hint, contains('MaterialApp.router'));
    });

    test('accept a MaterialApp or a MaterialApp.router at the root', () {
      expect(_check(_app(appCalls: [_root()])), isEmpty);
      // The index records MaterialApp.router() as router() on MaterialApp.
      expect(_check(_app(appCalls: [_root(router: true)])), isEmpty);
    });

    test('count only a MaterialApp that the provider creates in lib/', () {
      const material = [IndexedInvocation('MaterialApp')];
      const screen = 'lib/features/home/home_screen.dart';
      final issues = _check(
        {
          ..._app(
            appCalls: const [
              IndexedInvocation('router', target: 'CupertinoApp'),
            ],
          ),
          // A widget test of the provider, outside lib/.
          'test/app_test.dart': const DartFileIndex(
            path: 'test/app_test.dart',
            invocations: material,
          ),
          screen: const DartFileIndex(path: screen, invocations: material),
          RouterRole.appRouterFile: const DartFileIndex(
            path: RouterRole.appRouterFile,
            invocations: material,
          ),
        },
        owners: {
          screen: const ModuleOrigin(ModuleId('home')),
          RouterRole.appRouterFile: const RoleTemplateOrigin(routerRole),
        },
      );

      expect(issues.map((issue) => issue.message), [
        contains('must be a MaterialApp'),
      ]);
    });

    test(
        'accept the root in the build(BuildContext context) of a class, '
        'among its other members and the other declarations of its file', () {
      expect(
        _check(
          _app(
            appDeclarations: [
              const IndexedDeclaration(
                name: 'createTitle',
                kind: DeclarationKind.function,
              ),
              _appWidget([
                const IndexedMember('title', kind: MemberKind.field),
                _build(),
              ]),
            ],
          ),
        ),
        isEmpty,
      );
      // A build() may take more after its context.
      expect(
        _check(
          _appWithBuildOf(const [
            ('context', 'BuildContext'),
            ('child', 'Widget'),
          ]),
        ),
        isEmpty,
      );
    });

    test(
        'require a MaterialApp of the provider in a build(BuildContext '
        'context) of a class, where the arguments of the modules read the '
        'context', () {
      final apps = {
        'in another method of the widget': _app(
          appCalls: [_root(member: '_root')],
        ),
        'in a helper of the widget that takes the context of its build': _app(
          appDeclarations: [
            _appWidget([
              _build(),
              const IndexedMember(
                '_root',
                kind: MemberKind.method,
                parameters: [
                  IndexedParameter(
                    'context',
                    kind: ParameterKind.requiredPositional,
                    type: 'BuildContext',
                  ),
                ],
              ),
            ]),
          ],
          appCalls: [_root(member: '_root')],
        ),
        'in a top-level function': _app(
          appCalls: const [
            IndexedInvocation('MaterialApp', enclosingDeclaration: 'createApp'),
          ],
        ),
        'in the build of a declaration without members, such as a mixin': _app(
          appDeclarations: const [
            IndexedDeclaration(name: 'App', kind: DeclarationKind.mixinType),
          ],
        ),
        'in a build without parameters': _appWithBuildOf(const []),
        'in a build whose context has another name': _appWithBuildOf(
          const [('ctx', 'BuildContext')],
        ),
        'in a build whose context is of another type': _appWithBuildOf(
          const [('context', 'Object')],
        ),
        'in a build whose context is a named parameter': _app(
          appDeclarations: [
            _appWidget(const [
              IndexedMember(
                'build',
                kind: MemberKind.method,
                parameters: [
                  IndexedParameter(
                    'context',
                    kind: ParameterKind.requiredNamed,
                    type: 'BuildContext',
                  ),
                ],
              ),
            ]),
          ],
        ),
        'in a getter named build, next to its setter with a context': _app(
          appDeclarations: [
            _appWidget([
              const IndexedMember('build', kind: MemberKind.getter),
              _buildOf(MemberKind.setter),
            ]),
          ],
        ),
      };
      for (final MapEntry(key: reason, value: files) in apps.entries) {
        final issues = _check(files);

        expect(
          issues.map((issue) => issue.message),
          [_outsideBuild(_appFile)],
          reason: reason,
        );
        expect(issues.single.path, _appFile, reason: reason);
        expect(
          issues.single.origin,
          const ModuleOrigin(ModuleId('flutter_core')),
          reason: reason,
        );
        expect(
          issues.single.hint,
          'Create it in the build(BuildContext context) of a widget. main() '
          'runs the widget that creates the root inside the root wrappers.',
          reason: reason,
        );
      }
    });

    test(
        'require every MaterialApp of the provider in such a build, not '
        'only one of them', () {
      const helpers = 'lib/testing/pump_app.dart';
      final issues = _check({
        // Next to the root in the build of App, one in a function.
        ..._app(
          appCalls: [
            _root(router: true),
            const IndexedInvocation(
              'MaterialApp',
              enclosingDeclaration: 'createPreview',
            ),
          ],
        ),
        // And one in another file of the provider in lib/.
        helpers: const DartFileIndex(
          path: helpers,
          invocations: [
            IndexedInvocation('MaterialApp', enclosingDeclaration: 'pumpApp'),
          ],
        ),
      });

      expect(
        issues.map((issue) => issue.message),
        [_outsideBuild(_appFile), _outsideBuild(helpers)],
      );
      expect(issues.map((issue) => issue.path), [_appFile, helpers]);
    });

    test(
        'look for the build(BuildContext context) in the class that creates '
        'the MaterialApp, not in another class of its file', () {
      final issues = _check(
        _app(
          appDeclarations: [
            _appWidget(),
            IndexedDeclaration(
              name: '_Root',
              kind: DeclarationKind.classType,
              members: [_build(const [])],
            ),
          ],
          appCalls: const [
            IndexedInvocation(
              'MaterialApp',
              enclosingDeclaration: '_Root',
              enclosingMember: 'build',
            ),
          ],
        ),
      );

      expect(issues.map((issue) => issue.message), [_outsideBuild(_appFile)]);
    });

    test(
        'check where the provider creates a MaterialApp in lib/ only, not '
        'where other modules or its tests do', () {
      const elsewhere = [IndexedInvocation('MaterialApp')];
      const screen = 'lib/features/home/home_screen.dart';

      expect(
        _check(
          {
            ..._app(),
            'test/app_test.dart': const DartFileIndex(
              path: 'test/app_test.dart',
              invocations: elsewhere,
            ),
            screen: const DartFileIndex(path: screen, invocations: elsewhere),
          },
          owners: {screen: const ModuleOrigin(ModuleId('home'))},
        ),
        isEmpty,
      );
    });
  });

  group('AppEntryRole arguments of the root MaterialApp', () {
    const socket = AppEntryRole.appArgs;

    SocketContribution arg(String name, String expression) =>
        SocketContribution.arg(socket, name, Fragment(expression));

    test(
        'are one theme, dark theme, theme mode and locale, the delegates of '
        'the localizations of every contributor, and the supported locales '
        'of one contributor', () {
      expect(socket.kind.args, {
        'theme': ArgShape.scalar,
        'darkTheme': ArgShape.scalar,
        'themeMode': ArgShape.scalar,
        'locale': ArgShape.scalar,
        'localizationsDelegates': ArgShape.list,
        'supportedLocales': ArgShape.listOfOneContributor,
      });
      for (final name in socket.kind.args.keys) {
        expect(socket.problemsWith(arg(name, 'value')), isEmpty, reason: name);
      }
      // The provider sets the other arguments of the root itself.
      expect(
        socket.problemsWith(arg('home', 'value')).single,
        'socket app_entry.app_args has no argument "home"; expected one of '
        'theme, darkTheme, themeMode, locale, localizationsDelegates, '
        'supportedLocales.',
      );
    });

    test(
        'render in the order of the socket, whatever the order of the '
        'contributions, with the expressions that read the context as they '
        'are', () {
      expect(
        socket.render([
          arg('supportedLocales', "Locale('en')"),
          arg('locale', 'AppLanguage.of(context)'),
          arg('localizationsDelegates', 'AppLocalizations.delegate'),
          arg('themeMode', 'AppThemeMode.of(context)'),
          arg('darkTheme', 'ThemeData.dark()'),
          arg('theme', 'ThemeData.light()'),
        ]),
        {
          'smf_app_entry__app_args': 'theme: ThemeData.light(),\n'
              'darkTheme: ThemeData.dark(),\n'
              'themeMode: AppThemeMode.of(context),\n'
              'locale: AppLanguage.of(context),\n'
              'localizationsDelegates: [AppLocalizations.delegate],\n'
              "supportedLocales: [Locale('en')],",
        },
      );
    });

    test('take one theme mode and one locale: two different ones conflict', () {
      const first = ModuleOrigin(ModuleId('first'));
      const second = ModuleOrigin(ModuleId('second'));

      for (final name in ['themeMode', 'locale']) {
        // Two modules may agree on a value.
        expect(
          socket.render([arg(name, 'a'), arg(name, 'a')]),
          {socket.tag: '$name: a,'},
          reason: name,
        );
        expect(
          () => socket.render([
            arg(name, 'a').withOrigin(first),
            arg(name, 'b').withOrigin(second),
          ]),
          throwsA(
            isA<MergeConflict>()
                .having((conflict) => conflict.key, 'key', name)
                .having((conflict) => conflict.existing, 'existing', 'a')
                .having((conflict) => conflict.incoming, 'incoming', 'b')
                .having(
                  (conflict) => conflict.reason,
                  'reason',
                  'the argument takes one value',
                )
                .having((c) => c.existingOrigin, 'existing origin', first)
                .having((c) => c.incomingOrigin, 'incoming origin', second),
          ),
          reason: name,
        );
      }
    });

    group('take the supported locales of one contributor:', () {
      const first = ModuleOrigin(ModuleId('first'));
      const ofVariant = ModuleOrigin(
        ModuleId('first'),
        variant: ModuleId('bloc'),
      );
      const second = ModuleOrigin(ModuleId('second'));
      const template = RoleTemplateOrigin(appEntryRole);

      SocketContribution locales(String code, [ContributionOrigin? origin]) {
        final contribution = arg('supportedLocales', code);
        return origin == null ? contribution : contribution.withOrigin(origin);
      }

      Matcher conflictOf(
        String existing,
        String incoming, {
        required ContributionOrigin from,
        required ContributionOrigin and,
      }) =>
          throwsA(
            isA<MergeConflict>()
                .having((conflict) => conflict.key, 'key', 'supportedLocales')
                .having((conflict) => conflict.existing, 'existing', existing)
                .having((conflict) => conflict.incoming, 'incoming', incoming)
                .having(
                  (conflict) => conflict.reason,
                  'reason',
                  'the argument takes the items of one contributor',
                )
                .having((c) => c.existingOrigin, 'existing origin', from)
                .having((c) => c.incomingOrigin, 'incoming origin', and),
          );

      test('the items of a module, those of its variant too, are a list', () {
        expect(
          socket.render([
            locales("Locale('en')", first),
            locales("Locale('uk')", ofVariant),
            // An item that it gives twice is in the list once.
            locales("Locale('en')", ofVariant),
          ]),
          {socket.tag: "supportedLocales: [Locale('en'), Locale('uk')],"},
        );
        // Contributions without an origin, as a test of a socket makes
        // them, are of one contributor.
        expect(
          socket.render([locales("Locale('en')"), locales("Locale('uk')")]),
          {socket.tag: "supportedLocales: [Locale('en'), Locale('uk')],"},
        );
        // The list of the template of a role, alone.
        expect(
          socket.render([locales('...appLocales', template)]),
          {socket.tag: 'supportedLocales: [...appLocales],'},
        );
      });

      test('the items of a second module conflict, also the same ones', () {
        for (final item in ["Locale('uk')", "Locale('en')"]) {
          expect(
            () => socket.render([
              locales("Locale('en')", first),
              locales(item, second),
            ]),
            conflictOf("Locale('en')", item, from: first, and: second),
            reason: item,
          );
        }
      });

      test(
          'a module next to the template of a role is the second '
          'contributor of the conflict, whichever contributed first', () {
        // The module first, with two items: the conflict names both.
        expect(
          () => socket.render([
            locales("Locale('en')", first),
            locales("Locale('fr')", first),
            locales('...appLocales', template),
          ]),
          conflictOf(
            '...appLocales',
            "Locale('en'), Locale('fr')",
            from: template,
            and: first,
          ),
        );
        expect(
          () => socket.render([
            locales('...appLocales', template),
            locales("Locale('en')", first),
          ]),
          conflictOf(
            '...appLocales',
            "Locale('en')",
            from: template,
            and: first,
          ),
        );
      });

      test('the delegates of the localizations are those of everyone', () {
        expect(
          socket.render([
            arg('localizationsDelegates', 'A.delegate').withOrigin(first),
            arg('localizationsDelegates', 'B.delegate').withOrigin(second),
            arg('localizationsDelegates', 'C.delegate').withOrigin(template),
          ]),
          {
            socket.tag: 'localizationsDelegates: '
                '[A.delegate, B.delegate, C.delegate],',
          },
        );
      });
    });
  });

  group('AppEntryRole native sockets', () {
    test('the iOS deployment target is the highest version', () {
      const socket = AppEntryRole.iosDeploymentTarget;
      expect(
        socket.render([
          socket.value('13.0'),
          socket.value('15.0'),
          socket.value('14'),
        ]),
        {socket.tag: '15.0'},
      );
    });

    test('the iOS deployment target always has a value', () {
      const socket = AppEntryRole.iosDeploymentTarget;
      expect(() => socket.render(const []), throwsStateError);
      expect(
        socket.problemsWith(socket.value('fifteen')).single,
        contains('cannot be compared'),
      );
    });

    test('Android permissions are united', () {
      const socket = AppEntryRole.androidManifestPermissions;
      expect(
        socket.render([
          socket.key('android.permission.INTERNET'),
          socket.key('android.permission.CAMERA'),
          socket.key('android.permission.INTERNET'),
        ]),
        {
          socket.tag:
              '    <uses-permission android:name="android.permission.INTERNET"/>\n'
                  '    <uses-permission android:name="android.permission.CAMERA"/>',
        },
      );
    });

    test('Android meta-data must agree and is escaped', () {
      const socket = AppEntryRole.androidManifestApplicationMeta;

      expect(
        _render(socket, const [
          ('a.key', AndroidMetaData.value('x & "y"')),
          ('b.icon', AndroidMetaData.resource('@drawable/ic_notification')),
        ]),
        {
          socket.tag: '        <meta-data android:name="a.key" '
              'android:value="x &amp; &quot;y&quot;"/>\n'
              '        <meta-data android:name="b.icon" '
              'android:resource="@drawable/ic_notification"/>',
        },
      );
      expect(
        _render(socket, const [
          ('a.key', AndroidMetaData.value('x')),
          ('a.key', AndroidMetaData.value('x')),
        ]),
        hasLength(1),
      );
      expect(
        () => _render(socket, const [
          ('a.key', AndroidMetaData.value('x')),
          ('a.key', AndroidMetaData.resource('x')),
        ]),
        throwsA(isA<MergeConflict>()),
      );
    });

    test('intent filters are XML without imports', () {
      const socket = AppEntryRole.mainActivityIntentFilters;
      const filter = '<intent-filter>\n'
          '    <action android:name="android.intent.action.VIEW"/>\n'
          '</intent-filter>';

      expect(socket.kind.carriesImports, isFalse);
      expect(
        socket
            .render(const [SocketContribution.code(socket, Fragment(filter))]),
        {socket.tag: filter},
      );
      expect(
        socket.problemsWith(
          const SocketContribution.code(
            socket,
            Fragment(filter, imports: [ImportRef('dart:io')]),
          ),
        ),
        isNotEmpty,
      );
    });

    test(
        'components of the Android application are XML without imports, '
        'those of one contribution after those of another', () {
      const socket = AppEntryRole.androidManifestApplicationComponents;
      const receiver = '        <receiver\n'
          '            android:name="com.example.alarms.AlarmReceiver"\n'
          '            android:exported="false" />';
      const service = '        <service\n'
          '            android:name="com.example.sync.SyncService"\n'
          '            android:exported="false" />';

      expect(socket.name, 'android_manifest_application_components');
      expect(socket.kind.carriesImports, isFalse);
      expect(
        socket.render(const [
          SocketContribution.code(socket, Fragment(receiver)),
          SocketContribution.code(socket, Fragment(service)),
        ]),
        {socket.tag: '$receiver\n$service'},
      );
      expect(socket.render(const []), {socket.tag: ''});
      expect(
        socket.problemsWith(
          const SocketContribution.code(
            socket,
            Fragment(receiver, imports: [ImportRef('dart:io')]),
          ),
        ),
        isNotEmpty,
      );
    });

    test('Info.plist unites string arrays and keeps scalars unique', () {
      const socket = AppEntryRole.infoPlist;

      expect(
        _render(socket, const [
          ('UIBackgroundModes', PlistStringArray(['fetch'])),
          ('NSCameraUsageDescription', PlistString('Scan <codes>')),
          ('UIBackgroundModes', PlistStringArray(['fetch', 'audio'])),
          ('UIStatusBarHidden', PlistBoolean(false)),
          ('Retries', PlistInteger(3)),
          ('Retries', PlistInteger(3)),
        ]),
        {
          socket.tag: [
            '\t<key>UIBackgroundModes</key>',
            '\t<array>',
            '\t\t<string>fetch</string>',
            '\t\t<string>audio</string>',
            '\t</array>',
            '\t<key>NSCameraUsageDescription</key>',
            '\t<string>Scan &lt;codes&gt;</string>',
            '\t<key>UIStatusBarHidden</key>',
            '\t<false/>',
            '\t<key>Retries</key>',
            '\t<integer>3</integer>',
          ].join('\n'),
        },
      );
      expect(
        () => _render(socket, const [
          ('UIStatusBarHidden', PlistBoolean(true)),
          ('UIStatusBarHidden', PlistBoolean(false)),
        ]),
        throwsA(isA<MergeConflict>()),
      );
      expect(
        () => _render(socket, const [
          ('UIBackgroundModes', PlistStringArray(['fetch'])),
          ('UIBackgroundModes', PlistString('fetch')),
        ]),
        throwsA(isA<MergeConflict>()),
      );
    });

    test(
        'the entitlements of the iOS app unite string arrays and keep '
        'scalars unique, as the keys of Info.plist', () {
      const socket = AppEntryRole.iosEntitlements;
      const sockets = ModuleOrigin(ModuleId('fake_sockets'));
      const overlap = ModuleOrigin(ModuleId('fake_overlap'));
      SocketContribution entry(
        ContributionOrigin origin,
        String key,
        PlistValue value,
      ) =>
          socket.entry(key, value).withOrigin(origin);

      expect(socket.name, 'ios_entitlements');
      expect(socket.tag, 'smf_app_entry__ios_entitlements');
      expect(socket.kind.policy, isA<PlistMergePolicy>());
      expect(
        socket.render([
          entry(sockets, 'aps-environment', const PlistString('development')),
          entry(
            sockets,
            'com.apple.developer.associated-domains',
            const PlistStringArray(['applinks:example.com']),
          ),
          entry(overlap, 'aps-environment', const PlistString('development')),
          entry(
            overlap,
            'com.apple.developer.associated-domains',
            const PlistStringArray(['applinks:example.org']),
          ),
        ]),
        {
          socket.tag: [
            '\t<key>aps-environment</key>',
            '\t<string>development</string>',
            '\t<key>com.apple.developer.associated-domains</key>',
            '\t<array>',
            '\t\t<string>applinks:example.com</string>',
            '\t\t<string>applinks:example.org</string>',
            '\t</array>',
          ].join('\n'),
        },
      );
      expect(
        () => socket.render([
          entry(sockets, 'aps-environment', const PlistString('development')),
          entry(overlap, 'aps-environment', const PlistString('production')),
        ]),
        throwsA(
          isA<MergeConflict>().having(
            (conflict) => '$conflict',
            'description',
            contains('(from fake_sockets and fake_overlap)'),
          ),
        ),
      );
    });

    test(
        'the code at the launch of the iOS app is Swift without imports, the '
        'statements of one contribution after those of another', () {
      const socket = AppEntryRole.iosAppDelegateLaunch;
      const delegate = '    UNUserNotificationCenter.current().delegate = self';
      const shake = '    application.applicationSupportsShakeToEdit = true';

      expect(socket.name, 'ios_app_delegate_launch');
      expect(socket.kind.carriesImports, isFalse);
      expect(
        socket.render(const [
          SocketContribution.code(socket, Fragment(delegate)),
          SocketContribution.code(socket, Fragment(shake)),
        ]),
        {socket.tag: '$delegate\n$shake'},
      );
      expect(socket.render(const []), {socket.tag: ''});
      expect(
        socket.problemsWith(
          const SocketContribution.code(
            socket,
            Fragment(delegate, imports: [ImportRef('dart:io')]),
          ),
        ),
        [
          equals(
            'socket app_entry.ios_app_delegate_launch is not Dart code and '
            'takes no imports.',
          ),
        ],
      );
    });

    test('Gradle plugins and dependencies take the highest version', () {
      expect(
        _render(AppEntryRole.gradleSettingsPlugins, const [
          ('io.github.ben-manes.versions', '0.63.0'),
          ('io.github.ben-manes.versions', '0.64.0'),
        ]),
        {
          AppEntryRole.gradleSettingsPlugins.tag:
              '    id("io.github.ben-manes.versions") version("0.64.0") '
                  'apply false',
        },
      );
      expect(
        AppEntryRole.gradleAppPlugins.render([
          AppEntryRole.gradleAppPlugins.key('io.github.ben-manes.versions'),
        ]),
        {
          AppEntryRole.gradleAppPlugins.tag:
              '    id("io.github.ben-manes.versions")',
        },
      );
      expect(
        _render(AppEntryRole.gradleAppDependencies, const [
          (r'com.example:lib$x', '1.0'),
          (r'com.example:lib$x', '1.2'),
        ]),
        {
          AppEntryRole.gradleAppDependencies.tag:
              r'    implementation("com.example:lib\$x:1.2")',
        },
      );
    });

    test(
        'core library desugaring takes the highest version of its library, '
        'and puts the switch and the library into the Gradle file', () {
      const socket = AppEntryRole.androidCoreLibraryDesugaring;
      const notifications = ModuleOrigin(ModuleId('notifications'));
      const calendar = ModuleOrigin(ModuleId('calendar'));
      const library = 'com.android.tools:desugar_jdk_libs:2.1.4';

      expect(socket.kind.policy, isA<MaxPolicy>());
      expect(socket.kind.required, isFalse);
      expect(
        socket.render([
          socket.value('2.1.3').withOrigin(calendar),
          socket.value('2.1.4').withOrigin(notifications),
          socket.value('2.0.4').withOrigin(calendar),
        ]),
        {
          'smf_app_entry__android_core_library_desugaring_enabled':
              '        isCoreLibraryDesugaringEnabled = true',
          'smf_app_entry__android_core_library_desugaring_library':
              '    coreLibraryDesugaring("$library")',
        },
      );
      // Without a module that needs it, the Gradle file has neither line.
      expect(socket.render(const []), {
        'smf_app_entry__android_core_library_desugaring_enabled': '',
        'smf_app_entry__android_core_library_desugaring_library': '',
      });
      // The problems name the socket, whose tags are those of its places.
      expect(
        socket.problemsWith(socket.value('two')).single,
        contains(
          '"two" of "app_entry.android_core_library_desugaring" cannot be '
          'compared',
        ),
      );
      expect(
        () => socket.render([
          socket.value('2.1.4').withOrigin(notifications),
          socket.value('2.1.4-beta').withOrigin(calendar),
        ]),
        throwsA(
          isA<MergeConflict>().having(
            (conflict) => '$conflict',
            'description',
            allOf(
              startsWith(
                'MergeConflict: "app_entry.android_core_library_desugaring" '
                'has conflicting values',
              ),
              contains('(from notifications and calendar)'),
            ),
          ),
        ),
      );
    });

    test('README sections follow each other under their headings', () {
      const socket = AppEntryRole.readmeSections;

      expect(socket.kind.carriesImports, isFalse);
      // In the order of the contributions, not of the headings.
      expect(
        _render(socket, const [
          ('Signing', 'The keys go into `android/key.properties`.'),
          ('Firebase', 'Run `flutterfire configure`.\n'),
          ('Signing', 'The keys go into `android/key.properties`.'),
        ]),
        {
          socket.tag: '\n## Signing\n\nThe keys go into '
              '`android/key.properties`.\n'
              '\n## Firebase\n\nRun `flutterfire configure`.',
        },
      );
      expect(
        () => _render(socket, const [
          ('Firebase', 'One text.'),
          ('Firebase', 'Another text.'),
        ]),
        throwsA(isA<MergeConflict>()),
      );
    });

    test('a README section has a heading of one line and text', () {
      const socket = AppEntryRole.readmeSections;

      expect(socket.problemsWith(socket.entry('Firebase', 'Text.')), isEmpty);
      for (final heading in ['', ' Firebase', 'Fire\nbase', 'Fire\rbase']) {
        expect(
          socket.problemsWith(socket.entry(heading, 'Text.')).single,
          'The heading "$heading" of a section of the README is not one line '
          'of text without spaces around it.',
          reason: heading,
        );
      }
      expect(
        socket.problemsWith(socket.entry('Firebase', ' \n')),
        ['The section "Firebase" of the README has no text.'],
      );
      // mason drops the backslash of a line break of Markdown.
      for (final (heading, text) in [
        ('Firebase', 'One line\\\nand another.'),
        (r'Fire\é', 'Text.'),
      ]) {
        expect(
          socket.problemsWith(socket.entry(heading, text)).single,
          'The section "$heading" of the README has a backslash before a line '
          'break or a non-ASCII character, which mason removes; for a line '
          'break in Markdown, end the line with two spaces instead.',
          reason: text,
        );
      }
    });

    test(
        'the README section of the steps by hand comes first, and the others '
        'keep the order of the contributions', () {
      const socket = AppEntryRole.readmeSections;

      expect(AppEntryRole.setupHeading, 'Finish the setup');
      expect(
        _render(socket, const [
          ('Signing', 'The keys go into `android/key.properties`.'),
          ('Firebase', 'Run `flutterfire configure`.'),
          (AppEntryRole.setupHeading, '1. Upload a key'),
          ('Languages', 'The texts are in ARB files.'),
        ]),
        {
          socket.tag: '\n## Finish the setup\n\n1. Upload a key\n'
              '\n## Signing\n\nThe keys go into `android/key.properties`.\n'
              '\n## Firebase\n\nRun `flutterfire configure`.\n'
              '\n## Languages\n\nThe texts are in ARB files.',
        },
      );
      // Without it, the order of the contributions holds for all.
      expect(
        _render(socket, const [
          ('Signing', 'Keys.'),
          ('Firebase', 'Run it.'),
        ]),
        {socket.tag: '\n## Signing\n\nKeys.\n\n## Firebase\n\nRun it.'},
      );
    });

    test(
        'the README section of the steps by hand comes from the template of '
        'the app entry role alone', () {
      const socket = AppEntryRole.readmeSections;
      const own = RoleTemplateOrigin(appEntryRole);

      /// The problems of the section [heading] from [origin].
      List<String> problemsFrom(
        ContributionOrigin origin,
        String heading, {
        String text = '1. Upload a key',
      }) =>
          socket.problemsWith(socket.entry(heading, text).withOrigin(origin));

      for (final (origin, who) in [
        (const ModuleOrigin(ModuleId('fire')), 'The module fire'),
        // A variant of a module, and a provider from its render hook, are
        // the module.
        (
          const ModuleOrigin(ModuleId('sign_in'), variant: ModuleId('bloc')),
          'The module sign_in',
        ),
        (
          const RoleTemplateOrigin(routerRole),
          'The template of the router role'
        ),
        (const PipelineOrigin(), 'The pipeline'),
      ]) {
        expect(
          problemsFrom(origin, AppEntryRole.setupHeading).single,
          '$who contributes the section "Finish the setup" of the README, '
          'which only the template of the app entry role writes, from the '
          'steps of the app that its developer does by hand. A step by hand '
          'is a ManualStep of its contributor, which that section lists.',
          reason: who,
        );
        // Every other heading is theirs to contribute.
        expect(problemsFrom(origin, 'Firebase'), isEmpty, reason: who);
      }
      expect(problemsFrom(own, AppEntryRole.setupHeading), isEmpty);
      // A contribution that the pipeline has not collected has no
      // contributor to check.
      expect(
        socket.problemsWith(socket.entry(AppEntryRole.setupHeading, 'Text.')),
        isEmpty,
      );
      // The other problems of a section do not depend on its contributor.
      expect(
        problemsFrom(own, AppEntryRole.setupHeading, text: ' '),
        ['The section "Finish the setup" of the README has no text.'],
      );
    });

    test(
        'the patterns of .gitignore come in their order, each under its '
        'comment after an empty line, and nothing without patterns', () {
      const socket = AppEntryRole.gitignore;

      expect(AppEntryRole.gitignoreFile, '.gitignore');
      expect(socket.kind.carriesImports, isFalse);
      // The pipeline takes the patterns by the ids of their contributors,
      // and the order of the patterns is the order of the file.
      expect(socket.kind.followsOrderEdges, isFalse);
      expect(
        _render(socket, const [
          ('/coverage/', 'The reports of the coverage of the tests'),
          ('.env', 'The values that each developer fills in'),
          ('/coverage/', 'The reports of the coverage of the tests'),
        ]),
        {
          socket.tag: '\n# The values that each developer fills in\n.env\n'
              '\n# The reports of the coverage of the tests\n/coverage/',
        },
      );
      // A tag that gets nothing renders nothing, and the pipeline removes
      // its line.
      expect(socket.render(const []), {socket.tag: ''});
    });

    test(
        'a pattern of .gitignore that modules give with different comments '
        'has each comment once, in their order, so that any modules fit in '
        'one app', () {
      const socket = AppEntryRole.gitignore;
      const values = 'The values of the app';
      const keys = 'The keys of the app';
      const local = 'What stays on one machine';

      // Whatever the order of the contributions.
      for (final comments in [
        [values, keys, values, local],
        [local, values, keys],
      ]) {
        expect(
          _render(socket, [
            for (final comment in comments) ('.env', comment),
            ('/build/', 'The output of the build'),
          ]),
          {
            socket.tag: '\n# The keys of the app\n# The values of the app\n'
                '# What stays on one machine\n.env\n'
                '\n# The output of the build\n/build/',
          },
          reason: '$comments',
        );
      }
    });

    test(
        'a pattern of .gitignore is one line that neither comments nor '
        'brings back, under a comment of one line', () {
      const socket = AppEntryRole.gitignore;
      List<String> problems(String pattern, [String comment = 'Values']) =>
          socket.problemsWith(socket.entry(pattern, comment));

      expect(problems('.env'), isEmpty);
      expect(
        problems('/build output/', 'The output of a tool, ünïcode'),
        isEmpty,
      );
      for (final pattern in ['', ' .env', '.env ', '.e\nnv', '.e\rnv']) {
        expect(
          problems(pattern).single,
          'The pattern "$pattern" of .gitignore is not one line of text '
          'without spaces around it.',
          reason: pattern,
        );
      }
      for (final pattern in [r'\#notes', r'build\ dir', r'C:\temp']) {
        expect(
          problems(pattern).single,
          'The pattern "$pattern" of .gitignore has a backslash, which git '
          'reads as an escape.',
          reason: pattern,
        );
      }
      expect(
        problems('#notes').single,
        'The pattern "#notes" of .gitignore starts with "#", which makes its '
        'line a comment.',
      );
      expect(
        problems('!keep.env').single,
        'The pattern "!keep.env" of .gitignore starts with "!", which brings '
        'back what a line before it ignores. The patterns come in the order '
        'of their text, so none may bring back what another ignores.',
      );
      for (final comment in ['', ' Values', 'Values ', 'Val\nues']) {
        expect(
          problems('.env', comment).single,
          'The comment "$comment" of the pattern ".env" of .gitignore is not '
          'one line of text without spaces around it.',
          reason: comment,
        );
      }
      // mason drops a backslash before a line break, which follows the
      // comment, or before a non-ASCII character.
      for (final comment in [r'Values of C:\', r'Values \ü']) {
        expect(
          problems('.env', comment).single,
          'The comment "$comment" of the pattern ".env" of .gitignore has a '
          'backslash at its end or before a non-ASCII character, which mason '
          'removes.',
          reason: comment,
        );
      }
      expect(problems('.env', r'Values of C:\temp'), isEmpty);
    });
  });

  group('the guide for coding agents', () {
    const socket = AppEntryRole.agentSections;

    /// The problems of the note [text] under [heading].
    List<String> problemsOf(String text, {String heading = 'Router'}) =>
        socket.problemsWith(socket.entry(heading, AgentNote(text)));

    test('is AGENTS.md, with a CLAUDE.md that reads it', () {
      expect(AppEntryRole.agentsFile, 'AGENTS.md');
      expect(AppEntryRole.claudeFile, 'CLAUDE.md');
      expect(appEntryRole.interface.files, [
        AppEntryRole.agentsFile,
        AppEntryRole.claudeFile,
        AppEntryRole.statusBarIconsFile,
        AppEntryRole.statusBarIconsTestFile,
      ]);
      expect(socket.tag, 'smf_app_entry__agent_sections');
      expect(socket.kind.carriesImports, isFalse);
      // Its renderer orders the sections and their notes itself, so a note
      // under a condition adds no order edge between the contributors.
      expect(socket.kind.followsOrderEdges, isFalse);
    });

    test(
        'comes from the template of the role, whose brick has the tag of '
        'the sections alone on a line', () {
      final brick = appEntryRole.template
          .contribute(testContext)
          .whereType<BrickContribution>()
          .single;
      final templates = {
        for (final file in brick.bundle.files)
          file.path: utf8.decode(base64.decode(file.data)),
      };

      expect(brick.bundle.name, 'app_entry_role');
      expect(templates.keys, appEntryRole.interface.files);
      expect(templates[AppEntryRole.claudeFile], '@AGENTS.md\n');
      final lines = templates[AppEntryRole.agentsFile]!.split('\n');
      expect(lines.first, '# AGENTS.md');
      // The sections render as complete lines after the introduction.
      expect(lines.where((line) => line.contains('{{')), [
        '{{{${socket.tag}}}}',
      ]);
      expect(lines.sublist(lines.length - 2), ['{{{${socket.tag}}}}', '']);
    });

    test('has the section of the role in every app, as what the role says', () {
      final note = appEntryRole.template
          .contribute(testContext)
          .whereType<SocketContribution>()
          .singleWhere((contribution) => contribution.socket == socket);

      expect(note.socket, socket);
      expect(note.entryKey, appEntryRole.description);
      expect(note.when, isEmpty);
      expect((note.entryValue! as AgentNote).isOfRole, isTrue);
      expect(socket.problemsWith(note), isEmpty);
    });

    test(
        'a note of a role comes from the template of a role, not from a '
        'module', () {
      SocketContribution from(ContributionOrigin origin, AgentNote note) =>
          socket.entry('Router', note).withOrigin(origin);
      const module = ModuleOrigin(ModuleId('go_router'));
      const template = RoleTemplateOrigin(appEntryRole);

      expect(
        socket.problemsWith(from(module, AgentNote.ofRole('Text.'))).single,
        'The module go_router contributes a note of a role to the section '
        '"Router" of the guide for coding agents. Only the template of a '
        'role says what the role guarantees; a module contributes '
        'AgentNote(text).',
      );
      expect(socket.problemsWith(from(module, AgentNote('Text.'))), isEmpty);
      expect(
        socket.problemsWith(from(template, AgentNote.ofRole('Text.'))),
        isEmpty,
      );
      // A contribution that the pipeline has not collected has no
      // contributor to check.
      expect(
        socket.problemsWith(socket.entry('Router', AgentNote.ofRole('Text.'))),
        isEmpty,
      );
      // The other problems of a note do not depend on its contributor.
      expect(
        socket.problemsWith(from(module, AgentNote(''))).single,
        endsWith('has no text.'),
      );
      expect(
        socket.problemsWith(from(template, AgentNote.ofRole(''))).single,
        endsWith('has no text.'),
      );
    });

    test('renders with the section of the role after its introduction',
        () async {
      final rendered = await renderTemplate(appEntryRole);
      final guide = rendered.files[AppEntryRole.agentsFile]!;
      final note = appEntryRole.template
          .contribute(testContext)
          .whereType<SocketContribution>()
          .singleWhere((contribution) => contribution.socket == socket)
          .entryValue! as AgentNote;

      expect(rendered.files.keys, appEntryRole.interface.files);
      expect(rendered.files[AppEntryRole.claudeFile], '@AGENTS.md\n');
      // The widget for the icons of the status bar goes into the builder of
      // the root, and the flavors into the README, both files of the provider.
      expect(
        [for (final fragment in rendered.elsewhere) fragment.socket],
        [AppEntryRole.appBuilder, AppEntryRole.readmeSections],
      );
      final [title, empty, introduction, ...sections] = guide.split('\n');
      expect(title, '# AGENTS.md');
      expect(empty, isEmpty);
      expect(introduction, startsWith('This guide tells coding agents'));
      expect(introduction, contains('[README.md](README.md)'));
      expect(
        sections.join('\n'),
        '\n## App entry\n\n${note.text}\n',
      );
    });

    test(
        'has the section of the app entry first, then the others in the '
        'order of their headings', () {
      expect(
        _render(socket, [
          ('Router', AgentNote('Routes.')),
          ('App entry', AgentNote('Start-up.')),
          ('Analytics', AgentNote('\nEvents.\n')),
        ]),
        {
          socket.tag: '\n## App entry\n\nStart-up.\n'
              '\n## Analytics\n\nEvents.\n'
              '\n## Router\n\nRoutes.',
        },
      );
    });

    test(
        'unites the notes of a section: those of roles first, then the '
        'others in the order of the contributions, each once', () {
      expect(
        _render(socket, [
          ('Router', AgentNote('With a package: its routes.')),
          ('Router', AgentNote.ofRole('Navigate through the facade.')),
          ('Router', AgentNote('A listener of the screen.')),
          ('Router', AgentNote('With a package: its routes.')),
          ('Router', AgentNote.ofRole('Navigate through the facade.')),
        ]),
        {
          socket.tag: '\n## Router\n\n'
              'Navigate through the facade.\n\n'
              'With a package: its routes.\n\n'
              'A listener of the screen.',
        },
      );
      // Notes that differ only in the spaces and the empty lines around
      // them are one.
      expect(
        _render(socket, [
          ('Router', AgentNote('Same text.')),
          ('Router', AgentNote('Same text.\n')),
          ('Router', AgentNote('  Same text.')),
        ]),
        {socket.tag: '\n## Router\n\nSame text.'},
      );
      // The same text as a note of a role and of a module is two notes.
      final united = socket.kind
          .merge([
            socket.entry('Router', AgentNote('The same.')),
            socket.entry('Router', AgentNote.ofRole('The same.')),
          ])
          .single
          .value;
      expect(united.text, 'The same.\n\nThe same.');
      expect(united.isOfRole, isFalse);
      expect(
        socket.kind
            .merge([
              socket.entry('Router', AgentNote.ofRole('One.')),
              socket.entry('Router', AgentNote.ofRole('Another.')),
            ])
            .single
            .value
            .isOfRole,
        isTrue,
      );
    });

    test('a note compares by its text and by whether a role says it', () {
      final note = AgentNote('Text.');

      expect(note, AgentNote('Text.'));
      expect(note.hashCode, AgentNote('Text.').hashCode);
      expect(note, isNot(AgentNote('Another text.')));
      expect(note, isNot(AgentNote.ofRole('Text.')));
      expect(AgentNote.ofRole('Text.'), AgentNote.ofRole('Text.'));
      expect('Text.', isNot(note));
      expect(note.isOfRole, isFalse);
      expect(AgentNote.ofRole('Text.').isOfRole, isTrue);
      expect(AgentNote('\n Text.\n\n').text, 'Text.');
      // The spaces and the empty lines around a text do not count.
      expect(AgentNote('  Text.'), note);
      expect(AgentNote('Text.\n'), note);
      expect(AgentNote('Text.\n').hashCode, note.hashCode);
      expect(AgentNote.ofRole('\nText.'), AgentNote.ofRole('Text.'));
      expect('$note', 'Text.');
    });

    test('a section has a heading of one line', () {
      expect(problemsOf('Text.'), isEmpty);
      for (final heading in ['', ' Router', 'Rou\nter', 'Rou\rter']) {
        expect(
          problemsOf('Text.', heading: heading).single,
          'The heading "$heading" of a section of the guide for coding '
          'agents is not one line of text without spaces around it.',
          reason: heading,
        );
      }
    });

    test('a note has text that mason keeps as it is', () {
      for (final text in ['', ' \n']) {
        expect(
          problemsOf(text).single,
          'A note of the section "Router" of the guide for coding agents has '
          'no text.',
          reason: text,
        );
      }
      // mason drops the backslash of a line break of Markdown, also the one
      // that ends a note or a heading, before the line break that follows.
      for (final text in [
        'One line\\\nand another.',
        r'It ends with a backslash\',
        // A command continued on the next line, in a fenced code block.
        '```bash\nflutter build apk \\\n  --debug\n```',
      ]) {
        expect(
          problemsOf(text).single,
          'A note of the section "Router" of the guide for coding agents '
          'has a backslash before a line break or a non-ASCII character, '
          'which mason removes. For a line break in Markdown, end the line '
          'with two spaces, and write a command on one line rather than '
          'continue it with a backslash.',
          reason: text,
        );
      }
      for (final heading in [r'Rou\é', r'Router\']) {
        expect(
          problemsOf('Text.', heading: heading).single,
          'The heading "$heading" of a section of the guide for coding '
          'agents has a backslash at its end or before a non-ASCII '
          'character, which mason removes.',
          reason: heading,
        );
      }
      expect(problemsOf(r'A path of Windows, C:\Users, in a line.'), isEmpty);
    });

    test('a note starts neither a title nor another section', () {
      for (final text in [
        '# Title',
        'Text.\n## Section\nMore text.',
        '   ## Indented by three spaces',
        'Text.\n#',
        '#\tTitle after a tab',
        // Not a fenced code block: a code span of three backticks.
        '```dart``` is a language.\n## Section',
      ]) {
        expect(
          problemsOf(text).single,
          'A note of the section "Router" of the guide for coding agents '
          'has a line that starts with "# " or "## " outside a fenced code '
          'block, which starts a title or another section; a note stays in '
          'its section.',
          reason: text,
        );
      }
      for (final text in [
        '### Details\n\nText.',
        '#hashtag',
        'Text with # in a line.',
        'Text.\n\n    ## In a code block by its indentation',
        '```bash\n# A comment of a script\n```',
        '~~~\n## In a block of tildes\n~~~',
        // A block ends with as many of its characters, or more.
        '````\n```\n# In the block still\n`````\nText.',
        // A block in an item of a list, indented with the item.
        '- Run:\n  ```bash\n  # A comment of a script\n  flutter test\n  ```',
      ]) {
        expect(problemsOf(text), isEmpty, reason: text);
      }
    });

    test(
        'a note has no line of = or - that makes the line above it a title '
        'or the heading of a section', () {
      for (final text in [
        'My own title\n============',
        'Another section\n---',
        'A title\n=   ',
        'Text.\n\nA heading in the text\n  -\nMore text.',
      ]) {
        expect(
          problemsOf(text).single,
          'A note of the section "Router" of the guide for coding agents '
          'has a line of "=" or "-" under a line of text outside a fenced '
          'code block, which makes that line a title or the heading of '
          'another section; a note stays in its section.',
          reason: text,
        );
      }
      for (final text in [
        // A rule between two paragraphs, after an empty line.
        'Text.\n\n---\n\nMore text.',
        '- An item.\n- Another.',
        'A table:\n\n| a | b |\n| --- | --- |\n| 1 | 2 |',
        '```\nA title in a block\n=====\n```',
        'Two signs == in a line, and a - too.',
      ]) {
        expect(problemsOf(text), isEmpty, reason: text);
      }
    });

    test('a note closes its fenced code blocks', () {
      for (final text in [
        '```bash\nflutter test',
        'Text.\n\n~~~\ncode\n```',
        '````\ncode\n```',
        // A line with more than the characters of the block does not close
        // it.
        '```\ncode\n```dart',
        // A block in an item of a list, indented with the item.
        '- Run:\n  ```bash\n  flutter test',
      ]) {
        expect(
          problemsOf(text).single,
          'A note of the section "Router" of the guide for coding agents '
          'does not close a fenced code block, which would take in the '
          'sections after it.',
          reason: text,
        );
      }
      for (final text in [
        '```bash\nflutter test\n```',
        '  ```\n  code\n  ```  ',
        '~~~\ncode\n~~~~\nText.',
      ]) {
        expect(problemsOf(text), isEmpty, reason: text);
      }
    });
  });

  group('the flavors of the app', () {
    final identity = testContext.appIdentity;

    /// The rows of the table of the section of the README, each as its cells.
    List<List<String>> rowsOf(String section) => [
          for (final line in section.split('\n'))
            if (line.startsWith('| `'))
              [
                for (final cell in line.split('|').skip(1).take(3)) cell.trim(),
              ],
        ];

    test('are dev, staging and prod, of which prod has the id of the app', () {
      expect(
        [
          for (final flavor in AppEntryRole.flavors)
            (flavor.name, flavor.idSuffix),
        ],
        [('dev', '.dev'), ('staging', '.staging'), ('prod', '')],
      );
    });

    test(
        'build dev without --flavor, and prod for a store, both among the '
        'flavors', () {
      expect(AppEntryRole.defaultFlavor.name, 'dev');
      expect(AppEntryRole.releaseFlavor.name, 'prod');
      expect(AppEntryRole.flavors, contains(AppEntryRole.defaultFlavor));
      expect(AppEntryRole.flavors, contains(AppEntryRole.releaseFlavor));
    });

    test('have no hyphen, on which Flutter splits a build configuration', () {
      for (final flavor in AppEntryRole.flavors) {
        expect(flavor.name, isNot(contains('-')));
      }
    });

    test('give the ids of the app with their suffixes', () {
      expect(
        [
          for (final flavor in AppEntryRole.flavors)
            (flavor.applicationIdIn(identity), flavor.bundleIdIn(identity)),
        ],
        [
          ('com.example.my_app.dev', 'com.example.my-app.dev'),
          ('com.example.my_app.staging', 'com.example.my-app.staging'),
          ('com.example.my_app', 'com.example.my-app'),
        ],
      );
    });

    test('name a build configuration for each mode, and a scheme', () {
      expect(
        AppEntryRole.flavors.first.xcodeConfigurations,
        ['Debug-dev', 'Profile-dev', 'Release-dev'],
      );
      expect(
        AppEntryRole.releaseFlavor.xcodeSchemeFile,
        'ios/Runner.xcodeproj/xcshareddata/xcschemes/prod.xcscheme',
      );
    });

    test(
        'are told of in the README of every app, with the ids of the app, '
        'what a plain command builds and how a store build names its flavor',
        () {
      final section = appEntryRole.template
          .contribute(testContext)
          .whereType<SocketContribution>()
          .singleWhere(
            (contribution) =>
                contribution.socket == AppEntryRole.readmeSections,
          );
      final text = section.entryValue! as String;

      expect(section.entryKey, AppEntryRole.flavorsHeading);
      expect(section.when, isEmpty);
      expect(
        rowsOf(text),
        [
          ['`dev`', '`com.example.my_app.dev`', '`com.example.my-app.dev`'],
          [
            '`staging`',
            '`com.example.my_app.staging`',
            '`com.example.my-app.staging`',
          ],
          ['`prod`', '`com.example.my_app`', '`com.example.my-app`'],
        ],
      );
      expect(text, contains('without `--flavor` builds `dev`'));
      expect(text, contains('in release mode too'));
      final commands = RegExp(r'```bash\n([^`]+)```').firstMatch(text)![1]!;
      expect(commands.trim().split('\n'), [
        'flutter run --flavor staging',
        'flutter build appbundle --flavor prod',
        'flutter build ipa --flavor prod',
      ]);
      expect(
        AppEntryRole.readmeSections.problemsWith(
          section.withOrigin(const RoleTemplateOrigin(appEntryRole)),
        ),
        isEmpty,
      );
    });

    test('come first among the sections of the README, after the steps by hand',
        () {
      const socket = AppEntryRole.readmeSections;
      final rendered = _render(socket, const [
        ('Firebase', 'Run `flutterfire configure`.'),
        (AppEntryRole.flavorProjectsHeading, 'Where they are.'),
        (AppEntryRole.flavorsHeading, 'Three flavors.'),
        (AppEntryRole.setupHeading, 'By hand.'),
      ]);

      expect(
        RegExp(r'^## (.+)$', multiLine: true)
            .allMatches(rendered[socket.tag]!)
            .map((match) => match[1]),
        [
          AppEntryRole.setupHeading,
          AppEntryRole.flavorsHeading,
          AppEntryRole.flavorProjectsHeading,
          'Firebase',
        ],
      );
    });

    test('are told of in the note of the role, with where code reads them', () {
      final note = agentNoteOf(appEntryRole).text;

      expect(note, contains('flavors `dev`, `staging` and `prod`'));
      expect(note, contains('`--flavor prod`'));
      expect(note, contains('`appFlavor` of `package:flutter/services.dart`'));
      expect(note, contains('`main_<flavor>.dart`'));
    });
  });

  group('the steps by hand', () {
    const readme = AppEntryRole.readmeSections;
    const guide = AppEntryRole.agentSections;
    final steps = [
      const ManualStep(
        ManualStepId.role(appEntryRole, 'app_id'),
        'Register the App ID of the iOS app',
      ),
      const ManualStep(
        ManualStepId(ModuleId('fire'), 'apns_key'),
        'Give Firebase your Apple push key (APNs key)',
      ),
    ];
    final link = Uri.parse(
      'https://doc.saymyframe.com/setup?steps=app_entry.app_id,fire.apns_key',
    );

    /// What the render hook of the template returns in an app with [setup].
    RoleOutput renderWith(ManualSetup setup) =>
        appEntryRole.template.render(inputOf(appEntryRole, manualSetup: setup));

    /// The section of the README that the template renders for [setup].
    SocketContribution sectionOf(ManualSetup setup) => renderWith(setup)
        .fragments
        .singleWhere((fragment) => fragment.socket == readme);

    test(
        'are listed in a section of the README, in their order, with the '
        'link to their guide', () {
      final section = sectionOf(ManualSetup(steps: steps, link: link));

      expect(section.entryKey, AppEntryRole.setupHeading);
      expect(section.when, isEmpty);
      expect(
        section.entryValue,
        'Once any commands of the sections below have run, the setup still '
        'needs these steps, which no command can do. [The guide]($link) '
        'shows each one click by click:\n'
        '\n'
        '1. Register the App ID of the iOS app\n'
        '2. Give Firebase your Apple push key (APNs key)\n'
        '\n'
        '$_repeatStep',
      );
      // The template may write the section, which comes before those of
      // the modules.
      final ofTemplate =
          section.withOrigin(const RoleTemplateOrigin(appEntryRole));
      expect(readme.problemsWith(ofTemplate), isEmpty);
      final firebase = readme
          .entry('Firebase', 'Run `flutterfire configure`.')
          .withOrigin(const ModuleOrigin(ModuleId('fire')));
      expect(
        readme.render([firebase, ofTemplate])[readme.tag],
        startsWith(
          '\n## Finish the setup\n\nOnce any commands of the sections below '
          'have run',
        ),
      );
      expect(
        readme.render([firebase, ofTemplate])[readme.tag],
        endsWith(
          '2. Give Firebase your Apple push key (APNs key)\n'
          '\n'
          '$_repeatStep\n'
          '\n## Firebase\n\nRun `flutterfire configure`.',
        ),
      );
    });

    test('are listed without a guide when the run names none', () {
      expect(
        sectionOf(ManualSetup(steps: steps.sublist(1))).entryValue,
        'Once any commands of the sections below have run, the setup still '
        'needs these steps, which no command can do:\n'
        '\n'
        '1. Give Firebase your Apple push key (APNs key)\n'
        '\n'
        '$_repeatStep',
      );
    });

    test('leave the README and the guide as they are in an app without them',
        () {
      for (final setup in [
        ManualSetup.none,
        ManualSetup(link: link),
      ]) {
        final output = renderWith(setup);

        expect(output.fragments, isEmpty, reason: '${setup.link}');
        expect(output.vars, isEmpty);
        expect(output.files, isEmpty);
      }
    });

    test(
        'are for the developer of the app, as the guide for coding agents '
        'tells after the note of the role, only in an app with them', () async {
      final rendered = await renderTemplate(
        appEntryRole,
        manualSetup: ManualSetup(steps: steps, link: link),
      );
      final entry = renderWith(ManualSetup(steps: steps))
          .fragments
          .singleWhere((fragment) => fragment.socket == guide);
      final note = entry.entryValue! as AgentNote;

      expect(entry.entryKey, appEntryRole.description);
      expect(entry.when, isEmpty);
      expect(note.isOfRole, isTrue);
      expect(
        guide.problemsWith(
          entry.withOrigin(const RoleTemplateOrigin(appEntryRole)),
        ),
        isEmpty,
      );
      expect(note.text, contains('"${AppEntryRole.setupHeading}"'));
      expect(note.text, contains('README'));
      // It follows the note of the role, in its section.
      final text = rendered.files[AppEntryRole.agentsFile]!;
      expect(
        text,
        endsWith(
          '\n## App entry\n\n${agentNoteOf(appEntryRole).text}\n\n'
          '${note.text}\n',
        ),
      );
      // It names no path that the app may lack.
      final issues = appEntryRole.checkStructure(
        StructuralRuleRequest(
          hook: const RoleHookRequest(
            data: [],
            presentRoles: {appEntryRole},
            context: testContext,
          ),
          files: const {},
          texts: {AppEntryRole.agentsFile: text},
          owners: {
            for (final path in appEntryRole.interface.files)
              path: const RoleTemplateOrigin(appEntryRole),
            for (final symbol in appEntryRole.interface.symbols)
              symbol.path: const RoleTemplateOrigin(appEntryRole),
          },
        ),
      );
      expect([for (final issue in issues) issue.message], isEmpty);

      // Without steps, the section has the note of the role alone.
      final without = await renderTemplate(appEntryRole);
      expect(
        without.files[AppEntryRole.agentsFile],
        endsWith('\n## App entry\n\n${agentNoteOf(appEntryRole).text}\n'),
      );
    });
  });

  group('the App ID of the iOS app', () {
    test(
        'is a step by hand of the role, with a title that keeps the rules of '
        'a title', () {
      const step = AppEntryRole.iosAppIdStep;

      expect(step.id, const ManualStepId.role(appEntryRole, 'ios_app_id'));
      expect(step.id.role, same(appEntryRole));
      expect(step.id.wire, 'app_entry.ios_app_id');
      expect(
        step.title,
        'In Xcode, sign the iOS app with your paid Apple Developer team',
      );
      expect(step.title.length, lessThanOrEqualTo(ManualStep.maxTitleLength));
      expect(step.title, isNot(endsWith('.')));
      expect(step.when, isEmpty);
    });

    test(
        'is needed by the entitlements of push messages, of Sign in with '
        'Apple and of associated domains, which the rule of the role names',
        () {
      expect(AppEntryRole.paidTeamEntitlements, {
        'aps-environment',
        'com.apple.developer.applesignin',
        'com.apple.developer.associated-domains',
      });
      final rule = appEntryRole.structuralRules
          .singleWhere((rule) => rule.id == 'app_entry.ios_app_id_step');
      for (final key in AppEntryRole.paidTeamEntitlements) {
        expect(rule.description, contains(key));
      }
      expect(rule.description, contains(AppEntryRole.iosAppIdStep.id.wire));
    });

    test(
        'comes with such an entitlement from the helper, under the roles of '
        'the entitlement', () {
      final contributions = AppEntryRole.paidTeamEntitlement(
        'aps-environment',
        const PlistString('development'),
        when: {routerRole},
      );

      expect(contributions, hasLength(2));
      final entry = contributions.first as SocketContribution;
      expect(entry.socket, AppEntryRole.iosEntitlements);
      expect(entry.entryKey, 'aps-environment');
      expect(entry.entryValue, const PlistString('development'));
      expect(entry.when, {routerRole});
      expect(entry.socket.problemsWith(entry), isEmpty);
      final step = contributions.last as ManualStep;
      expect(step.id, AppEntryRole.iosAppIdStep.id);
      expect(step.title, AppEntryRole.iosAppIdStep.title);
      expect(step.when, {routerRole});

      // Without roles, both apply in every app.
      for (final contribution in AppEntryRole.paidTeamEntitlement(
        'com.apple.developer.applesignin',
        const PlistStringArray(['Default']),
      )) {
        expect(contribution.when, isEmpty);
      }
    });

    test('is not for an entitlement that a free team signs', () {
      expect(
        () => AppEntryRole.paidTeamEntitlement(
          'keychain-access-groups',
          const PlistStringArray(['a.b']),
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'key')
              .having(
                (error) => error.invalidValue,
                'invalidValue',
                'keychain-access-groups',
              )
              .having(
                (error) => '${error.message}',
                'message',
                'A free team signs this entitlement, so it needs no step by '
                    'hand: contribute it with '
                    'AppEntryRole.iosEntitlements.entry',
              ),
        ),
      );
    });
  });

  group('the icons of the status bar', () {
    /// What the template of the role puts into the builder of the root.
    SocketContribution wrapper() => appEntryRole.template
        .contribute(testContext)
        .whereType<SocketContribution>()
        .singleWhere(
          (contribution) => contribution.socket == AppEntryRole.appBuilder,
        );

    /// The files of the app that the template of the role renders, by path.
    late Map<String, String> files;

    setUpAll(() async {
      files = (await renderTemplate(appEntryRole)).files;
    });

    /// The class `StatusBarIcons` in its file.
    ClassDeclaration widget() =>
        parseString(content: files[AppEntryRole.statusBarIconsFile]!)
            .unit
            .declarations
            .whereType<ClassDeclaration>()
            .singleWhere(
              (declaration) =>
                  declaration.namePart.typeName.lexeme == 'StatusBarIcons',
            );

    /// The method `build` of `StatusBarIcons`.
    MethodDeclaration buildOfWidget() => widget()
        .body
        .members
        .whereType<MethodDeclaration>()
        .singleWhere((method) => method.name.lexeme == 'build');

    /// The calls of [name] in the method `build` of `StatusBarIcons`.
    List<MethodInvocation> calls(String name) {
      final found = <MethodInvocation>[];
      buildOfWidget().accept(_Calls(name, found));
      return found;
    }

    /// The argument [name] of [call], as code.
    String argument(MethodInvocation call, String name) =>
        call.argumentList.arguments
            .whereType<NamedArgument>()
            .singleWhere((argument) => argument.name.lexeme == name)
            .argumentExpression
            .toSource();

    test(
        'come from the template of the role, in every app, as a widget of '
        'its file around the content of every route', () {
      final contribution = wrapper();
      final fragment = contribution.fragment!;

      expect(contribution.when, isEmpty);
      expect(fragment.isWrapper, isTrue);
      expect(fragment.problems(), isEmpty);
      expect(
        '${fragment.code}child${fragment.closing}',
        'StatusBarIcons(child: child)',
      );
      expect(
        [for (final import in fragment.imports) import.resolveUri('my_app')],
        ['package:my_app/core/app/status_bar_icons.dart'],
      );
      expect(
        AppEntryRole.statusBarIconsFile,
        'lib/${fragment.imports.single.uri}',
      );
      final constructor =
          widget().body.members.whereType<ConstructorDeclaration>().single;
      expect(constructor.constKeyword, isNotNull);
      expect(
        constructor.parameters.toSource(),
        '({required this.child, super.key})',
      );
    });

    test(
        'suit the theme below the root: dark ones on a light theme and '
        'light ones on a dark theme', () {
      final region = calls('AnnotatedRegion').single;
      final style = calls('SystemUiOverlayStyle').single;

      expect(region.typeArguments!.toSource(), '<SystemUiOverlayStyle>');
      expect(argument(region, 'value'), style.toSource());
      // The content of the routes is inside the region.
      expect(argument(region, 'child'), 'child');
      // The brightness of the bar, which iOS takes, and of its icons, which
      // Android takes.
      expect(argument(style, 'statusBarBrightness'), 'brightness');
      expect(
        argument(style, 'statusBarIconBrightness'),
        'brightness == Brightness.dark ? Brightness.light : Brightness.dark',
      );
    });

    test(
        'read the theme from the context of the widget, and leave the '
        'navigation bar of the system as it is', () {
      final build = buildOfWidget();
      final style = calls('SystemUiOverlayStyle').single;

      // The widget names no parameter of the builder of the provider.
      expect(build.parameters!.toSource(), '(BuildContext context)');
      expect(
        build.toSource(),
        contains('final brightness = Theme.of(context).brightness;'),
      );
      expect(
        [
          for (final argument
              in style.argumentList.arguments.whereType<NamedArgument>())
            argument.name.lexeme,
        ],
        ['statusBarBrightness', 'statusBarIconBrightness'],
      );
    });

    test(
        'have a widget test in every app, which pumps the widget in a light '
        'and in a dark theme, so that flutter test has a test to run in an '
        'app whose modules bring none', () {
      final test = files[AppEntryRole.statusBarIconsTestFile]!;
      final unit = parseString(content: test).unit;
      final tests = <MethodInvocation>[];
      unit.accept(_Calls('testWidgets', tests));

      expect(
        [
          for (final directive in unit.directives.whereType<ImportDirective>())
            directive.uri.stringValue,
        ],
        contains('package:my_app/core/app/status_bar_icons.dart'),
      );
      expect(
        [
          for (final call in tests)
            call.argumentList.arguments.first.toSource(),
        ],
        [
          "'asks for dark icons on a light theme'",
          "'asks for light icons on a dark theme'",
          "'leaves the navigation bar of the system as it is'",
        ],
      );
      expect(test, contains('const StatusBarIcons(child: '));
      expect(test, contains('ThemeData(brightness: Brightness.dark)'));
    });
  });

  group('the paths of the guide for coding agents', () {
    const guide = AppEntryRole.agentsFile;

    /// What the rules of the role find in an app with [files] and the guide
    /// [text].
    List<SmfIssue> check(
      String text, {
      List<String> files = const [
        'README.md',
        'pubspec.yaml',
        'lib/main.dart',
        'lib/core/app/fallback_start_screen.dart',
        'android/app/build.gradle.kts',
        'ios/Runner/Info.plist',
      ],
    }) =>
        appEntryRole.checkStructure(
          StructuralRuleRequest(
            hook: const RoleHookRequest(
              data: [],
              presentRoles: {appEntryRole},
              context: testContext,
            ),
            files: const {},
            texts: {guide: text},
            owners: {
              guide: const RoleTemplateOrigin(appEntryRole),
              for (final path in files)
                path: const ModuleOrigin(ModuleId('flutter_core')),
            },
          ),
        );

    List<String> messages(List<SmfIssue> issues) =>
        [for (final issue in issues) issue.message];

    test('are files and directories of the app', () {
      expect(
        check('''
# AGENTS.md

The introduction names `README.md` and `lib/main.dart`.

## App entry

- `lib/main.dart` has `main()`, and `lib/core/app/` the screens of the app.
- `lib/core` and `android/` are directories, and so is `ios/Runner`.
- `ios/Runner/Info.plist` and `android/app/build.gradle.kts` are native.
'''),
        isEmpty,
      );
    });

    test(
        'that the app does not have are reported under the heading of their '
        'section, on the owner of the guide', () {
      final issues = check('''
# AGENTS.md

## Liar

The screens are in `lib/liar/missing.dart`, next to `lib/core/missing/`.

- A tool writes `android/app/google-services.json` later.
''');

      expect(messages(issues), [
        equals(
          'The section "Liar" of AGENTS.md names `lib/liar/missing.dart`, but '
          'the app has no such file or directory.',
        ),
        equals(
          'The section "Liar" of AGENTS.md names `lib/core/missing/`, but the '
          'app has no such file or directory.',
        ),
        equals(
          'The section "Liar" of AGENTS.md names '
          '`android/app/google-services.json`, but the app has no such file '
          'or directory.',
        ),
      ]);
      for (final issue in issues) {
        expect(issue.isError, isTrue);
        expect(issue.path, guide);
        expect(issue.origin, const RoleTemplateOrigin(appEntryRole));
        expect(
          issue.hint,
          allOf(
            contains('with the role of the file in its when'),
            contains('*'),
          ),
        );
      }
    });

    test(
        'below a directory of a Flutter project that the app is without are '
        'reported too', () {
      final issues = check('''
## Liar

The icon is `assets/icons/home.png` and the page `web/index.html`. The tests
are in `test/` and `integration_test/app_test.dart`, and the app runs on
`macos/`.
''');

      expect(messages(issues), [
        for (final path in [
          'assets/icons/home.png',
          'web/index.html',
          'test/',
          'integration_test/app_test.dart',
          'macos/',
        ])
          equals(
            'The section "Liar" of AGENTS.md names `$path`, but the app has '
            'no such file or directory.',
          ),
      ]);
    });

    test(
        'to Dart files are paths of the app whatever they start with, and '
        'the name of a Dart file alone is no path', () {
      final issues = check('''
## Router

The routes are in `core/router/navigation.dart`, and `main()` in `main.dart`
or `./lib/main.dart`. The tests end with `_test.dart`.
''');

      expect(messages(issues), [
        equals(
          'The section "Router" of AGENTS.md names '
          '`core/router/navigation.dart`, but the app has no such file or '
          'directory.',
        ),
        equals(
          'The section "Router" of AGENTS.md names the Dart file `main.dart` '
          'without its path from the root of the app.',
        ),
        equals(
          'The section "Router" of AGENTS.md names `./lib/main.dart`, but '
          'the app has no such file or directory.',
        ),
        equals(
          'The section "Router" of AGENTS.md names the Dart file '
          '`_test.dart` without its path from the root of the app.',
        ),
      ]);
      expect(
        issues[1].hint,
        'Write the path from the root of the app, such as lib/main.dart, or, '
        'for the files of a kind, a pattern with *, such as *_test.dart.',
      );
      expect(issues.last.hint, issues[1].hint);
      expect(issues.first.origin, const RoleTemplateOrigin(appEntryRole));
    });

    test('are told from what is no path of the app', () {
      expect(
        check('''
## Router

- A pattern: `lib/features/<feature>/`, `lib/core/*/`, `test/<path>_test.dart`,
  `*_test.dart`.
- A route: `/home`, `/home/details/:id`, `home.details`.
- A library: `package:flutter/material.dart`.
- A command: `dart format .`, `flutter build ipa`.
- A file at the root of the app, or a name: `pubspec.yaml`, `Icons.home`.
- Code: `context.nav.home.details(id: 5).go()`, `bootstrap()`.
- What the tools write: `build/ios/SourcePackages`, `.dart_tool/`.
- A path in the text, not in code: lib/missing.dart.
'''),
        isEmpty,
      );
    });

    test('are read in inline code, not in fenced code blocks', () {
      final issues = check('''
## Router

```bash
cat `lib/in_a_block.dart`
```

A span of two backticks, ``lib/two.dart``, and one after a run ``` that
nothing closes: `lib/after.dart`. This paragraph ends with a ` alone.

The next paragraph has `lib/next.dart`, which the one before does not reach.
''');

      expect(messages(issues), [
        for (final path in ['lib/two.dart', 'lib/after.dart', 'lib/next.dart'])
          equals(
            'The section "Router" of AGENTS.md names `$path`, but the app has '
            'no such file or directory.',
          ),
      ]);
    });

    test('are read in each item of a list on its own', () {
      final issues = check('''
## Router

- This item has a ` alone.
- The next names `lib/missing.dart`,
  and goes on in `lib/another.dart`.
1. A numbered item with a ` alone.
2. The next names `lib/numbered.dart`.
   * And an item below it has a ` alone.
   * Its next names `lib/below.dart`.
''');

      expect(messages(issues), [
        for (final path in [
          'lib/missing.dart',
          'lib/another.dart',
          'lib/numbered.dart',
          'lib/below.dart',
        ])
          equals(
            'The section "Router" of AGENTS.md names `$path`, but the app has '
            'no such file or directory.',
          ),
      ]);
    });

    test('are reported once for each section, and for the introduction', () {
      final issues = check('''
# AGENTS.md

See `lib/missing.dart`.

## Router

- `lib/missing.dart` has the routes.
- Put a route into `lib/missing.dart`.

## Layout

- `lib/missing.dart` has the shell.
''');

      expect(messages(issues), [
        for (final where in [
          'The introduction',
          'The section "Router"',
          'The section "Layout"',
        ])
          equals(
            '$where of AGENTS.md names `lib/missing.dart`, but the app has no '
            'such file or directory.',
          ),
      ]);
    });

    test('of the note of the role are those that the role guarantees',
        () async {
      final rendered = await renderTemplate(appEntryRole);
      final interface = appEntryRole.interface;

      // An app with nothing but what the role guarantees: the files of its
      // template and those of the symbols of its providers.
      expect(
        check(
          rendered.files[guide]!,
          files: [
            ...interface.files,
            for (final symbol in interface.symbols) symbol.path,
          ],
        ),
        isEmpty,
      );
      // Without them, the rule finds the paths of the note.
      expect(
        messages(check(rendered.files[guide]!, files: const ['lib/app.dart'])),
        [
          for (final path in [
            AppEntryRole.mainFile,
            AppEntryRole.bootstrapFile,
            AppEntryRole.statusBarIconsFile,
          ])
            equals(
              'The section "App entry" of AGENTS.md names `$path`, but the '
              'app has no such file or directory.',
            ),
        ],
      );
    });
  });

  group('the line of the README that names Say My Frame', () {
    const readme = AppEntryRole.readmeFile;
    const owner = ModuleOrigin(ModuleId('flutter_core'));

    /// What the rules of the role find in an app whose README is [text].
    List<SmfIssue> check(String text) => appEntryRole.checkStructure(
          StructuralRuleRequest(
            hook: const RoleHookRequest(
              data: [],
              presentRoles: {appEntryRole},
              context: testContext,
            ),
            files: const {},
            texts: {readme: text},
            owners: const {readme: owner},
          ),
        );

    test('links the documentation of Say My Frame', () {
      expect(
        AppEntryRole.generatedWith,
        'Generated with [Say My Frame](https://doc.saymyframe.com).',
      );
    });

    test(
        'is in the README, under the title or among the lines before the '
        'first section', () {
      expect(
        check('# my_app\n\n${AppEntryRole.generatedWith}\n'),
        isEmpty,
      );
      expect(
        check(
          '# my_app\n'
          '\n'
          'A new Flutter project.\n'
          '\n'
          '${AppEntryRole.generatedWith}  \n'
          '\n'
          '## Firebase\n'
          '\n'
          'Run flutterfire configure.\n',
        ),
        isEmpty,
      );
    });

    test(
        'is reported when the README lacks it, has it only in a section or '
        'only inside a line', () {
      for (final text in [
        '# my_app\n\nA new Flutter project.\n',
        '# my_app\n\n## About\n\n${AppEntryRole.generatedWith}\n',
        '# my_app\n\nThis app: ${AppEntryRole.generatedWith}\n',
      ]) {
        final issues = check(text);

        expect(issues, hasLength(1), reason: text);
        expect(
          issues.single.message,
          'README.md does not say that Say My Frame generated the app: it '
          'has no line "${AppEntryRole.generatedWith}" before its first '
          'section.',
        );
        expect(
          issues.single.hint,
          'Write the line of AppEntryRole.generatedWith under the title of '
          'the README of the provider.',
        );
        expect(issues.single.origin, owner);
        expect(issues.single.path, readme);
      }
    });
  });

  group('AppEntryRole native checks', () {
    /// What the structural rules of [role] find in an app with [texts],
    /// whose steps by hand are [steps].
    List<SmfIssue> checkWith(
      Role<NoDsl> role,
      Map<String, String> texts,
      List<ManualStep> steps,
    ) =>
        role.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: const [],
              presentRoles: const {appEntryRole},
              context: testContext,
              manualSetup: ManualSetup(steps: steps),
            ),
            files: const {},
            texts: texts,
            owners: {
              for (final path in texts.keys)
                path: const ModuleOrigin(ModuleId('flutter_core')),
            },
          ),
        );

    /// The structural problems of an app with [texts], whose steps by hand
    /// are [steps]: by default the step that the entitlement of
    /// [_entitlements] needs, as in the app of a module that adds it.
    ///
    /// The rule of the flavors has a group of its own: [texts] holds parts of
    /// a native project, as short as the rule that a test looks at needs
    /// them, and no flavor is among them.
    List<SmfIssue> checkTexts(
      Map<String, String> texts, {
      List<ManualStep> steps = const [AppEntryRole.iosAppIdStep],
    }) =>
        checkWith(const _AppEntryWithoutFlavorRule(), texts, steps);

    List<String> messages(List<SmfIssue> issues) =>
        [for (final issue in issues) issue.message];

    test('accept native files that name every key once', () {
      expect(
        messages(
          checkTexts({
            AppEntryRole.infoPlistFile: _plist,
            AppEntryRole.androidManifestFile: _manifest,
            AppEntryRole.gradleSettingsFile: _settings,
            AppEntryRole.gradleAppFile: _appGradle,
          }),
        ),
        isEmpty,
      );
    });

    test('report a key of Info.plist that the dictionary has twice', () {
      final issues = checkTexts({
        AppEntryRole.infoPlistFile: _plist.replaceFirst(
          '</dict>\n</plist>',
          '\t<key>CFBundleName</key>\n\t<string>Again</string>\n'
              '</dict>\n</plist>',
        ),
      });

      expect(messages(issues), [
        'ios/Runner/Info.plist has the key CFBundleName more than once.',
      ]);
      expect(
        issues.single.origin,
        const ModuleOrigin(ModuleId('flutter_core')),
      );
      expect(issues.single.path, AppEntryRole.infoPlistFile);
    });

    test('report permissions and meta-data of the application twice', () {
      final manifest = _manifest
          .replaceFirst(
            '    <application',
            '    <uses-permission android:name="android.permission.CAMERA"/>\n'
                '    <application',
          )
          .replaceFirst(
            '    </application>',
            '        <meta-data android:name="flutterEmbedding" '
                'android:value="2"/>\n'
                '    </application>',
          );

      expect(
        messages(checkTexts({AppEntryRole.androidManifestFile: manifest})),
        [
          equals(
            'android/app/src/main/AndroidManifest.xml has the permission '
            'android.permission.CAMERA more than once.',
          ),
          equals(
            'android/app/src/main/AndroidManifest.xml has the meta-data '
            'flutterEmbedding more than once.',
          ),
        ],
      );
    });

    test(
        'report a component of the application that the manifest declares '
        'twice', () {
      String component(String element, String name) =>
          '        <$element android:name="$name" '
          'android:exported="false" />\n';
      final manifest = _manifest.replaceFirst(
        '    </application>',
        '${component('receiver', 'com.example.AlarmReceiver')}'
            '${component('service', 'com.example.SyncService')}'
            '${component('provider', 'com.example.FilesProvider')}'
            '${component('receiver', 'com.example.AlarmReceiver')}'
            '${component('service', 'com.example.SyncService')}'
            '${component('provider', 'com.example.FilesProvider')}'
            '${component('activity', '.MainActivity')}'
            // A component of another kind with the same name is another.
            '${component('service', 'com.example.AlarmReceiver')}'
            '    </application>',
      );
      const path = 'android/app/src/main/AndroidManifest.xml';

      expect(
        messages(checkTexts({AppEntryRole.androidManifestFile: manifest})),
        [
          equals('$path has the activity .MainActivity more than once.'),
          equals('$path has the service com.example.SyncService more than '
              'once.'),
          equals('$path has the receiver com.example.AlarmReceiver more than '
              'once.'),
          equals('$path has the provider com.example.FilesProvider more than '
              'once.'),
        ],
      );
      expect(
        checkTexts({AppEntryRole.androidManifestFile: manifest}).first.hint,
        'One module declares a component, and none declares one that the '
        'template of the app entry role has, such as its main activity.',
      );
    });

    test(
        'resolve the name of a component as Android does, against the '
        'namespace of the app', () {
      String component(String element, String name, {String quote = '"'}) =>
          '        <$element android:name=$quote$name$quote '
          'android:exported="false" />\n';
      final manifest = _manifest.replaceFirst(
        '    </application>',
        '${component('receiver', '.Receiver')}'
            '${component('receiver', 'com.example.app.Receiver')}'
            // A module's main activity next to that of the provider.
            '${component('activity', 'com.example.app.MainActivity')}'
            // A name without a dot is relative too.
            '${component('service', 'Sync')}'
            '${component('service', 'com.example.app.Sync')}'
            '${component('activity-alias', '.Launcher')}'
            "${component('activity-alias', '.Launcher', quote: "'")}"
            // Another package keeps its name.
            '${component('provider', 'com.example.other.Files')}'
            '${component('provider', 'com.example.app.Files')}'
            '    </application>',
      );
      const path = 'android/app/src/main/AndroidManifest.xml';
      const appGradle = 'android {\n    namespace = "com.example.app"\n}\n';

      expect(
        messages(
          checkTexts({
            AppEntryRole.androidManifestFile: manifest,
            AppEntryRole.gradleAppFile: appGradle,
          }),
        ),
        [
          equals('$path has the activity com.example.app.MainActivity more '
              'than once.'),
          equals('$path has the activity-alias com.example.app.Launcher more '
              'than once.'),
          equals('$path has the service com.example.app.Sync more than once.'),
          equals('$path has the receiver com.example.app.Receiver more than '
              'once.'),
        ],
      );
      // Without the namespace of the app, a name is taken as it is written.
      expect(
        messages(checkTexts({AppEntryRole.androidManifestFile: manifest})),
        [
          equals('$path has the activity-alias .Launcher more than once.'),
        ],
      );
    });

    test('tell the meta-data of an activity from those of the application', () {
      final manifest = _manifest.replaceFirst(
        '        </activity>',
        '            <meta-data android:name="flutterEmbedding" '
            'android:value="2"/>\n'
            '        </activity>',
      );

      expect(
        messages(checkTexts({AppEntryRole.androidManifestFile: manifest})),
        isEmpty,
      );
    });

    test('report a plugin that a plugins block has twice', () {
      final issues = checkTexts({
        AppEntryRole.gradleSettingsFile: _settings.replaceFirst(
          '2.3.20" apply false\n',
          '2.3.20" apply false\n'
              '    id("org.jetbrains.kotlin.android") version("2.3.21") '
              'apply false\n',
        ),
        AppEntryRole.gradleAppFile:
            '$_appGradle\nplugins {\n    id("com.android.application")\n}\n',
      });

      expect(messages(issues), [
        equals(
          'android/settings.gradle.kts has the plugin '
          'org.jetbrains.kotlin.android more than once.',
        ),
      ]);
    });

    test('read no key out of comments', () {
      expect(
        messages(
          checkTexts({
            AppEntryRole.infoPlistFile: _plist.replaceFirst(
              '</dict>',
              '<!-- <key>CFBundleName</key> -->\n</dict>',
            ),
            AppEntryRole.androidManifestFile: _manifest.replaceFirst(
              '    </application>',
              '        <!-- <meta-data android:name="flutterEmbedding"/> -->\n'
                  '    </application>',
            ),
            AppEntryRole.gradleSettingsFile: _settings.replaceFirst(
              '\n}',
              '\n    // id("com.android.application")\n}',
            ),
          }),
        ),
        isEmpty,
      );
    });

    test('report an entitlement that the entitlements have twice', () {
      const path = AppEntryRole.iosEntitlementsFile;
      final issues = checkTexts({
        path: _entitlements.replaceFirst(
          '</dict>',
          '\t<key>aps-environment</key>\n\t<string>production</string>\n'
              '</dict>',
        ),
      });

      expect(messages(issues), [
        equals(
          'ios/Runner/Runner.entitlements has the key aps-environment more '
          'than once.',
        ),
      ]);
      expect(issues.single.path, path);
    });

    group('the step by hand of the App ID of the iOS app', () {
      const path = AppEntryRole.iosEntitlementsFile;
      const step = AppEntryRole.iosAppIdStep;

      /// Another step of the app, which has another id.
      const other = ManualStep(
        ManualStepId.role(appEntryRole, 'app_id'),
        'Register the App ID of the iOS app',
      );

      /// The entitlements of an iOS app with [entries], as the provider of
      /// the role renders them.
      String entitlementsOf(Map<String, PlistValue> entries) {
        const socket = AppEntryRole.iosEntitlements;
        final keys = socket.render([
          for (final MapEntry(:key, :value) in entries.entries)
            socket.entry(key, value),
        ]);
        return _entitlements.replaceFirst(
          RegExp('<dict>.*</dict>', dotAll: true),
          '<dict>\n${keys.values.join()}\n</dict>',
        );
      }

      test('accepts an app with an entitlement that needs it and the step', () {
        for (final key in AppEntryRole.paidTeamEntitlements) {
          expect(
            messages(
              checkTexts(
                {
                  path: entitlementsOf({key: const PlistString('x')}),
                },
                steps: const [other, step],
              ),
            ),
            isEmpty,
            reason: key,
          );
        }
      });

      test(
          'reports an app with such entitlements and without the step, as a '
          'problem of the entitlements that names them', () {
        final issues = checkTexts(
          {
            path: entitlementsOf({
              'aps-environment': const PlistString('development'),
              'keychain-access-groups': const PlistStringArray(['a.b']),
              'com.apple.developer.associated-domains':
                  const PlistStringArray(['applinks:example.com']),
            }),
          },
          steps: const [other],
        );

        expect(messages(issues), [
          equals(
            'ios/Runner/Runner.entitlements has the entitlements '
            'aps-environment, com.apple.developer.associated-domains, which '
            'only a team of the paid Apple Developer Program signs, but the '
            'app does not list the step by hand app_entry.ios_app_id: "In '
            'Xcode, sign the iOS app with your paid Apple Developer team".',
          ),
        ]);
        expect(
          issues.single.hint,
          'The module or the template of a role that adds such an entitlement '
          'lists AppEntryRole.iosAppIdStep with it, under the same roles: '
          'AppEntryRole.paidTeamEntitlement gives both.',
        );
        expect(issues.single.path, path);
        expect(
          issues.single.origin,
          const ModuleOrigin(ModuleId('flutter_core')),
        );

        expect(
          messages(
            checkTexts(
              {
                path: entitlementsOf({
                  'com.apple.developer.applesignin':
                      const PlistStringArray(['Default']),
                }),
              },
              steps: const [],
            ),
          ),
          [
            startsWith(
              'ios/Runner/Runner.entitlements has the entitlement '
              'com.apple.developer.applesignin, which only a team of the paid '
              'Apple Developer Program signs, but ',
            ),
          ],
        );
      });

      test(
          'asks for no step in an app whose entitlements need none, have such '
          'a key only in a comment or in a value, or are not among its files',
          () {
        for (final texts in [
          {path: entitlementsOf({})},
          {
            path: entitlementsOf({
              'keychain-access-groups': const PlistStringArray(['a.b']),
            }),
          },
          {
            path: entitlementsOf({
              'com.example.list': const PlistStringArray(['aps-environment']),
            }).replaceFirst(
              '</dict>',
              '\t<!-- <key>aps-environment</key> -->\n</dict>',
            ),
          },
          // An app that the harness did not render.
          <String, String>{},
        ]) {
          expect(
            messages(checkTexts(texts, steps: const [])),
            isEmpty,
            reason: '$texts',
          );
        }
      });
    });

    group('the signing of the iOS app with its entitlements', () {
      const project = AppEntryRole.xcodeProjectFile;

      List<SmfIssue> checkProject(String text) => checkTexts({
            project: text,
            AppEntryRole.iosEntitlementsFile: _entitlements,
          });

      test('accepts every build configuration of the app signing with them',
          () {
        expect(messages(checkProject(_xcodeProject)), isEmpty);
        // As Xcode writes the settings when a value needs quotes.
        expect(
          messages(
            checkProject(
              _xcodeProject
                  .replaceAll(
                    'INFOPLIST_FILE = Runner/Info.plist;',
                    'INFOPLIST_FILE = "Runner/Info.plist";',
                  )
                  .replaceFirst(
                    'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;',
                    'CODE_SIGN_ENTITLEMENTS = "Runner/Runner.entitlements";',
                  ),
            ),
          ),
          isEmpty,
        );
      });

      test(
          'reports a build configuration of the app that does not sign with '
          'them', () {
        const signs = 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;';
        const forDevices = '"CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]" = '
            'Runner/Runner.entitlements;';
        final configurations = _xcodeProject.split(signs);
        expect(configurations, hasLength(4));
        // Profile without the setting, Debug with other entitlements, and
        // Release with them for the devices only.
        final text = [
          configurations[0],
          configurations[1],
          'CODE_SIGN_ENTITLEMENTS = Runner/Other.entitlements;',
          configurations[2],
          forDevices,
          configurations[3],
        ].join();
        final issues = checkProject(text);

        expect(messages(issues), [
          for (final name in [
            'Profile (249021D4217E4FDB00AE95B9)',
            'Debug (97C147061CF9000F007C117D)',
            'Release (97C147071CF9000F007C117D)',
          ])
            equals(
              'The build configuration $name of the app target in '
              'ios/Runner.xcodeproj/project.pbxproj does not sign the app '
              'with ios/Runner/Runner.entitlements.',
            ),
        ]);
        for (final issue in issues) {
          expect(issue.path, project);
          expect(issue.origin, const ModuleOrigin(ModuleId('flutter_core')));
          expect(
            issue.hint,
            'Each build configuration with INFOPLIST_FILE = Runner/Info.plist '
            'has CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements; and no '
            'other CODE_SIGN_ENTITLEMENTS. Without it the app builds and '
            'signs, but has none of the entitlements that the modules add.',
          );
        }

        // A configuration whose name does not follow its settings.
        expect(
          messages(
            checkProject(
              _xcodeProject.replaceFirst(signs, '').replaceFirst(
                    '\t\t\tname = Profile;\n\t\t};\n\t\t331C',
                    '\t\t};\n\t\t331C',
                  ),
            ),
          ),
          [
            equals(
              'The build configuration 249021D4217E4FDB00AE95B9 of the app '
              'target in ios/Runner.xcodeproj/project.pbxproj does not sign '
              'the app with ios/Runner/Runner.entitlements.',
            ),
          ],
        );

        // Twice in one configuration, once with a condition.
        expect(
          messages(
            checkProject(
              _xcodeProject.replaceFirst(signs, '$signs\n\t\t\t\t$forDevices'),
            ),
          ),
          [
            equals(
              'The build configuration Profile (249021D4217E4FDB00AE95B9) of '
              'the app target in ios/Runner.xcodeproj/project.pbxproj does '
              'not sign the app with ios/Runner/Runner.entitlements.',
            ),
          ],
        );
      });

      test(
          'reports the entitlements of the app in another target, and '
          'entitlements in the build settings of the project', () {
        String withSetting(String before, String value) =>
            _xcodeProject.replaceFirst(
              before,
              'CODE_SIGN_ENTITLEMENTS = $value;\n\t\t\t\t$before',
            );
        const ofProject = 'ALWAYS_SEARCH_USER_PATHS = NO;';
        const ofTests = 'CODE_SIGN_STYLE = Automatic;';

        // The target of the tests signs with the file of the app.
        final ofApp = checkProject(
          withSetting(ofTests, 'Runner/Runner.entitlements'),
        );
        expect(messages(ofApp), [
          equals(
            'The build configuration Debug (331C8088294A63A400263BE5) in '
            'ios/Runner.xcodeproj/project.pbxproj, which is not one of the '
            'app target, signs with the entitlements of the app, '
            'ios/Runner/Runner.entitlements.',
          ),
        ]);
        expect(
          ofApp.single.hint,
          'Only the app target signs with ios/Runner/Runner.entitlements. '
          'Another target, such as an app extension, signs with '
          'entitlements of its own.',
        );

        // The project has a setting that every target inherits, whatever
        // its file.
        for (final value in [
          'Runner/Runner.entitlements',
          'Share/Share.entitlements',
        ]) {
          final inherited = checkProject(withSetting(ofProject, value));
          expect(
            messages(inherited),
            [
              equals(
                'The build configuration Profile (249021D3217E4FDB00AE95B9) '
                'of the project in ios/Runner.xcodeproj/project.pbxproj names '
                'entitlements in CODE_SIGN_ENTITLEMENTS, which every target '
                'without a setting of its own inherits, such as the tests.',
              ),
            ],
            reason: value,
          );
          expect(
            inherited.single.hint,
            'Set CODE_SIGN_ENTITLEMENTS in the build configurations of each '
            'target that signs with entitlements: Runner/Runner.entitlements '
            'in those of the app target, which read Runner/Info.plist.',
          );
        }
      });

      test('reads what it can of a project that is cut off', () {
        // A configuration without settings, and a comment, a string and a
        // configuration that do not end.
        const release = 'INFOPLIST_FILE = Runner/Info.plist;\n'
            '\t\t\t};\n\t\t\tname = Release;';
        final cut = _xcodeProject.substring(
          0,
          _xcodeProject.indexOf(release) + release.indexOf('\n'),
        );
        const empty = '\t\t00000000000000000000000A = '
            '{isa = XCBuildConfiguration; name = Empty;};\n';
        for (final end in ['', '\n/* cut', '\n// cut', '\n"cut']) {
          expect(
            messages(
              checkProject(
                cut.replaceFirst(
                      '/* Begin XCBuildConfiguration section */\n',
                      '/* Begin XCBuildConfiguration section */\n$empty',
                    ) +
                    end,
              ),
            ),
            isEmpty,
            reason: end,
          );
        }
      });

      test('reports a project without build settings of the app target', () {
        final issues = checkProject(
          _xcodeProject
              .replaceAll(
                'INFOPLIST_FILE = Runner/Info.plist;',
                'GENERATE_INFOPLIST_FILE = YES;',
              )
              .replaceAll(
                'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;',
                '',
              ),
        );

        expect(messages(issues), [
          equals(
            'ios/Runner.xcodeproj/project.pbxproj has no build configuration '
            'of the app target, with INFOPLIST_FILE = Runner/Info.plist, '
            'that signs the app with ios/Runner/Runner.entitlements.',
          ),
        ]);
      });

      test(
          'reads build settings with braces in their strings, and none in '
          'comments', () {
        const signs = 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;';
        final release = _xcodeProject.lastIndexOf(signs);
        String releaseWith(String instead) => _xcodeProject.replaceRange(
              release,
              release + signs.length,
              instead,
            );

        // Release does not sign with them, and has a brace in a string or in
        // a comment, or the setting only in a comment.
        for (final instead in [
          r'OTHER_SWIFT_FLAGS = "-D FOO=${BAR}";',
          '/* { */',
          '/*\n\t\t\t\t$signs\n\t\t\t\t*/',
          '// $signs',
        ]) {
          expect(
            messages(checkProject(releaseWith(instead))),
            [contains('Release')],
            reason: instead,
          );
        }
        // Release signs with them, next to a brace in a string and in a
        // comment.
        expect(
          messages(
            checkProject(
              releaseWith(
                '$signs\n\t\t\t\tOTHER_SWIFT_FLAGS = "-D FOO=\${BAR} \\"}\\"";'
                '\n\t\t\t\t/* } { */',
              ),
            ),
          ),
          isEmpty,
        );
      });

      test(
          'accepts a target with entitlements of its own, such as an app '
          'extension', () {
        expect(
          messages(
            checkProject(
              _xcodeProject.replaceFirst(
                'CODE_SIGN_STYLE = Automatic;',
                'CODE_SIGN_ENTITLEMENTS = Share/Share.entitlements;\n'
                    '\t\t\t\tCODE_SIGN_STYLE = Automatic;',
              ),
            ),
          ),
          isEmpty,
        );
      });

      test('checks nothing in an app without an iOS project', () {
        expect(
          messages(checkTexts({AppEntryRole.infoPlistFile: _plist})),
          isEmpty,
        );
      });
    });

    List<SmfIssue> checkModule(Map<String, String> templates) =>
        appEntryRole.checkModule(
          ModuleRuleRequest(
            hook: const RoleHookRequest(
              data: [],
              presentRoles: {appEntryRole},
              context: testContext,
            ),
            module: const ModuleDescriptor(
              id: ModuleId('scaffold'),
              description: 'Scaffold',
              kind: ModuleKinds.scaffold,
              providers: [RoleProvider.plain(appEntryRole)],
            ),
            contributions: [BrickContribution(_bundle(templates))],
          ),
        );

    const bootstrap = '''
Future<void> bootstrap() async {
{{{smf_app_entry__bootstrap_early}}}
{{{smf_app_entry__bootstrap_platform}}}
{{{smf_app_entry__bootstrap_di}}}
{{{smf_app_entry__bootstrap_late}}}
}
''';

    const main = '''
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  runApp(
    {{{smf_app_entry__root_wrappers_open}}}const App(){{{smf_app_entry__root_wrappers_close}}},
  );
}
''';

    test('module rules accept the tags of a provider in place', () {
      expect(
        checkModule({
          AppEntryRole.mainFile: main,
          AppEntryRole.bootstrapFile: bootstrap,
          AppEntryRole.androidManifestFile: _manifestTemplate,
          AppEntryRole.infoPlistFile:
              '<dict>\n{{{smf_app_entry__info_plist}}}\n</dict>\n',
          AppEntryRole.iosEntitlementsFile:
              '<dict>\n{{{smf_app_entry__ios_entitlements}}}\n</dict>\n',
          AppEntryRole.appDelegateFile: _appDelegateTemplate,
          AppEntryRole.gradleSettingsFile:
              'plugins {\n{{{smf_app_entry__gradle_settings_plugins}}}\n}\n',
          AppEntryRole.gradleAppFile: 'plugins {\n'
              '{{{smf_app_entry__gradle_app_plugins}}}\n}\n\n'
              'android {\n    compileOptions {\n'
              '{{{smf_app_entry__android_core_library_desugaring_enabled}}}\n'
              '    }\n}\n\n'
              'dependencies {\n'
              '{{{smf_app_entry__gradle_app_dependencies}}}\n'
              '{{{smf_app_entry__android_core_library_desugaring_library}}}\n'
              '}\n',
          AppEntryRole.readmeFile: '# {{app_name}}\n\nAn app.\n'
              '{{{smf_app_entry__readme_sections}}}\n',
          AppEntryRole.gitignoreFile:
              '/build/\n{{{smf_app_entry__gitignore}}}\n',
        }),
        isEmpty,
      );
    });

    test('the phases of start-up are in order in bootstrap.dart', () {
      final swapped = bootstrap
          .replaceFirst('bootstrap_early', 'bootstrap_x')
          .replaceFirst('bootstrap_late', 'bootstrap_early')
          .replaceFirst('bootstrap_x', 'bootstrap_late');
      final issues = checkModule({AppEntryRole.bootstrapFile: swapped});

      expect(issues.map((issue) => issue.message), [
        equals(
          'The tags of the phases of start-up in lib/bootstrap.dart are not '
          'in the order early, platform, di, late.',
        ),
      ]);
      expect(issues.single.origin, const ModuleOrigin(ModuleId('scaffold')));

      final moved = checkModule({
        AppEntryRole.bootstrapFile:
            bootstrap.replaceFirst('{{{smf_app_entry__bootstrap_late}}}', ''),
        'lib/late.dart': '{{{smf_app_entry__bootstrap_late}}}\n',
      });
      expect(moved.map((issue) => issue.message), [
        equals(
          'The tag {{{smf_app_entry__bootstrap_late}}} is not in '
          'lib/bootstrap.dart, where bootstrap() runs the phases of '
          'start-up.',
        ),
      ]);
    });

    test('the phases of start-up are in the body of bootstrap()', () {
      final issues = checkModule({
        AppEntryRole.bootstrapFile: '''
Future<void> bootstrap() async {
{{{smf_app_entry__bootstrap_early}}}
{{{smf_app_entry__bootstrap_platform}}}
{{{smf_app_entry__bootstrap_di}}}
}

void later() {
{{{smf_app_entry__bootstrap_late}}}
}
''',
      });

      expect(issues.map((issue) => issue.message), [
        equals(
          'The tag {{{smf_app_entry__bootstrap_late}}} is in '
          'lib/bootstrap.dart, but not in the body of bootstrap(), which '
          'runs the phases of start-up.',
        ),
      ]);
      expect(issues.single.origin, const ModuleOrigin(ModuleId('scaffold')));

      for (final template in [
        'Future<void> bootstrap() async => run();\n',
        // A body that the template does not close.
        'Future<void> bootstrap() async {\n',
      ]) {
        final withoutBody = checkModule({
          AppEntryRole.bootstrapFile:
              '$template{{{smf_app_entry__bootstrap_early}}}\n',
        });
        expect(
          withoutBody.map((issue) => issue.message),
          [
            equals(
              'The tag {{{smf_app_entry__bootstrap_early}}} is in '
              'lib/bootstrap.dart, but not in the body of bootstrap(), which '
              'runs the phases of start-up.',
            ),
          ],
          reason: template,
        );
      }
    });

    test(
        'the body of bootstrap() ends at its own brace, whatever the strings, '
        'comments, tags and closures in it', () {
      expect(
        checkModule({
          AppEntryRole.bootstrapFile: '''
{{{smf_app_entry__top_level}}}

/// Runs the start-up code of {{app_name}}, not a } of a comment.
Future<void> bootstrap() async {
  // A brace in a comment: }
  /* And in another: } */
  print('A brace in a string: }');
  print(""" and in another: } """);
{{{smf_app_entry__bootstrap_early}}}
  await runZoned(() async {
{{{smf_app_entry__bootstrap_platform}}}
  });
{{{smf_app_entry__bootstrap_di}}}
{{{smf_app_entry__bootstrap_late}}}
}

void later() {}
''',
        }),
        isEmpty,
      );
    });

    test(
        'the root wrappers are in the body of main() in main.dart, so the '
        'widget that creates the root is below them', () {
      const open = '{{{smf_app_entry__root_wrappers_open}}}';
      const close = '{{{smf_app_entry__root_wrappers_close}}}';
      const scaffold = ModuleOrigin(ModuleId('scaffold'));

      // Around the MaterialApp in the build of the root widget, which
      // main() runs as it is: the context of that build, which the
      // arguments of the root read, would be above the wrappers.
      final inBuild = checkModule({
        AppEntryRole.mainFile:
            main.replaceFirst(open, '').replaceFirst(close, ''),
        'lib/app.dart': '''
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) =>
      ${open}MaterialApp(
{{{smf_app_entry__app_args}}}
      )$close;
}
''',
      });

      expect(inBuild.map((issue) => issue.message), [
        equals(
          'The tag $open is not in lib/main.dart, where main() runs the root '
          'widget inside the root wrappers.',
        ),
        equals(
          'The tag $close is not in lib/main.dart, where main() runs the '
          'root widget inside the root wrappers.',
        ),
      ]);
      for (final issue in inBuild) {
        expect(issue.origin, scaffold);
        expect(issue.path, AppEntryRole.mainFile);
      }

      // In main.dart, but outside the body of main(): in a function after
      // it, or in a variable before it.
      for (final template in [
        '''
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  runApp(_root());
}

Widget _root() => ${open}const App()$close;
''',
        '''
final Widget _root = ${open}const App()$close;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  runApp(_root);
}
''',
      ]) {
        final outside = checkModule({AppEntryRole.mainFile: template});

        expect(
          outside.map((issue) => issue.message),
          [
            equals(
              'The tag $open is in lib/main.dart, but not in the body of '
              'main(), which runs the root widget inside the root wrappers.',
            ),
            equals(
              'The tag $close is in lib/main.dart, but not in the body of '
              'main(), which runs the root widget inside the root wrappers.',
            ),
          ],
          reason: template,
        );
        for (final issue in outside) {
          expect(issue.origin, scaffold, reason: template);
          expect(issue.path, AppEntryRole.mainFile, reason: template);
        }
      }

      // One of the two tags only: the wrappers open in main() and close
      // elsewhere.
      final split = checkModule({
        AppEntryRole.mainFile: main.replaceFirst(close, ''),
        'lib/app.dart': 'final close = App()$close;\n',
      });

      expect(split.map((issue) => issue.message), [
        equals(
          'The tag $close is not in lib/main.dart, where main() runs the '
          'root widget inside the root wrappers.',
        ),
      ]);

      // A provider without the tags takes no root wrappers: the pipeline
      // reports a wrapper that a module contributes then.
      expect(
        checkModule({
          AppEntryRole.mainFile:
              main.replaceFirst(open, '').replaceFirst(close, ''),
        }),
        isEmpty,
      );
    });

    test('line tags stand alone at the start of a line of their file', () {
      final issues = checkModule({
        AppEntryRole.androidManifestFile: _manifestTemplate.replaceFirst(
          '\n{{{smf_app_entry__android_manifest_permissions}}}',
          '    {{{smf_app_entry__android_manifest_permissions}}}',
        ),
        'ios/Podfile': '{{{smf_app_entry__info_plist}}}\n',
        AppEntryRole.infoPlistFile:
            '<dict>\n{{{smf_app_entry__ios_entitlements}}}\n</dict>\n',
        AppEntryRole.iosEntitlementsFile:
            '<dict>{{{smf_app_entry__ios_entitlements}}}</dict>\n',
        'ios/Runner/SceneDelegate.swift':
            'class SceneDelegate: FlutterSceneDelegate {\n'
                '{{{smf_app_entry__ios_app_delegate_launch}}}\n}\n',
        'android/app/src/debug/AndroidManifest.xml': '<application>\n'
            '{{{smf_app_entry__android_manifest_application_components}}}\n'
            '</application>\n',
        AppEntryRole.readmeFile:
            '# {{app_name}}\n\nAn app. {{{smf_app_entry__readme_sections}}}\n',
        // Each place of the desugaring renders lines of the Gradle file of
        // the app: the switch in compileOptions and the library in the
        // dependencies.
        AppEntryRole.gradleSettingsFile:
            '{{{smf_app_entry__android_core_library_desugaring_enabled}}}\n',
        AppEntryRole.gradleAppFile: 'dependencies {\n'
            '    {{{smf_app_entry__android_core_library_desugaring_library}}}\n'
            '}\n',
        // The patterns of the modules are lines of the .gitignore at the
        // root of the app, not of another one.
        'android/.gitignore': '{{{smf_app_entry__gitignore}}}\n',
        AppEntryRole.gitignoreFile: '/build/ {{{smf_app_entry__gitignore}}}\n',
      });

      expect(issues.map((issue) => issue.message), [
        equals(
          'The tag {{{smf_app_entry__android_manifest_permissions}}} must '
          'stand alone at the start of a line of '
          'android/app/src/main/AndroidManifest.xml, because its '
          'contributions render as complete lines.',
        ),
        equals(
          'The tag '
          '{{{smf_app_entry__android_manifest_application_components}}} is in '
          'android/app/src/debug/AndroidManifest.xml, but its lines belong in '
          'android/app/src/main/AndroidManifest.xml.',
        ),
        equals(
          'The tag {{{smf_app_entry__info_plist}}} is in ios/Podfile, but its '
          'lines belong in ios/Runner/Info.plist.',
        ),
        equals(
          'The tag {{{smf_app_entry__ios_entitlements}}} is in '
          'ios/Runner/Info.plist, but its lines belong in '
          'ios/Runner/Runner.entitlements.',
        ),
        equals(
          'The tag {{{smf_app_entry__ios_entitlements}}} must stand alone at '
          'the start of a line of ios/Runner/Runner.entitlements, because its '
          'contributions render as complete lines.',
        ),
        equals(
          'The tag {{{smf_app_entry__ios_app_delegate_launch}}} is in '
          'ios/Runner/SceneDelegate.swift, but its lines belong in '
          'ios/Runner/AppDelegate.swift.',
        ),
        equals(
          'The tag '
          '{{{smf_app_entry__android_core_library_desugaring_enabled}}} is in '
          'android/settings.gradle.kts, but its lines belong in '
          'android/app/build.gradle.kts.',
        ),
        equals(
          'The tag '
          '{{{smf_app_entry__android_core_library_desugaring_library}}} must '
          'stand alone at the start of a line of android/app/build.gradle.kts, '
          'because its contributions render as complete lines.',
        ),
        equals(
          'The tag {{{smf_app_entry__gitignore}}} is in android/.gitignore, '
          'but its lines belong in .gitignore.',
        ),
        equals(
          'The tag {{{smf_app_entry__gitignore}}} must stand alone at the '
          'start of a line of .gitignore, because its contributions render as '
          'complete lines.',
        ),
        equals(
          'The tag {{{smf_app_entry__readme_sections}}} must stand alone at '
          'the start of a line of README.md, because its contributions render '
          'as complete lines.',
        ),
      ]);
    });

    test(
        'the tag of the patterns of .gitignore is on the last line of the '
        'provider with text, so the patterns follow its own lines', () {
      const tag = '{{{smf_app_entry__gitignore}}}';
      const path = AppEntryRole.gitignoreFile;
      List<String> problems(String template) => [
            for (final issue in checkModule({path: template})) issue.message,
          ];
      const notLast = 'The tag $tag is not on the last line of $path that has '
          'text: the patterns of the modules follow every line of the '
          'provider, so no line of the provider can take back what they '
          'ignore.';

      expect(problems('/build/\n$tag\n'), isEmpty);
      // Empty lines after it are no lines of the provider.
      expect(problems('/build/\n$tag\n\n  \n'), isEmpty);
      for (final template in [
        '$tag\n/build/\n',
        '/build/\n$tag\n\n# Keep the keys\n!/keys/\n',
      ]) {
        final issues = checkModule({path: template});
        expect(
          [for (final issue in issues) issue.message],
          [notLast],
          reason: template,
        );
        expect(issues.single.origin, const ModuleOrigin(ModuleId('scaffold')));
        expect(issues.single.path, path);
      }
      // A tag that is not alone on its line has the problem of that only.
      const notAlone = 'The tag $tag must stand alone at the start of a line '
          'of $path, because its contributions render as complete lines.';
      expect(problems('$tag /build/\n'), [notAlone]);
    });

    test(
        'the code at the launch of the iOS app runs in '
        'application(_:didFinishLaunchingWithOptions:), before Flutter takes '
        'the launch', () {
      const tag = '{{{smf_app_entry__ios_app_delegate_launch}}}';
      const path = AppEntryRole.appDelegateFile;
      const method = 'application(_:didFinishLaunchingWithOptions:)';
      List<SmfIssue> issues(String template) => checkModule({path: template});
      List<String> problems(String template) =>
          [for (final issue in issues(template)) issue.message];
      const notInBody = 'The tag $tag is in $path, but not in the body of '
          '$method, where the code of the modules runs before the launch of '
          'the app finishes.';
      const call = 'super.application(_:didFinishLaunchingWithOptions:)';
      const notFirst = 'The tag $tag is in the body of $method in $path, but '
          'not before its call of $call, which hands the launch of the app to '
          'Flutter: the code of the modules runs before it.';
      const noCall = 'The tag $tag is in the body of $method in $path, which '
          'has no call of $call: the method hands the launch of the app to '
          'Flutter with that call, after the code of the modules.';
      String moved(String to) =>
          _appDelegateTemplate.replaceFirst('$tag\n', '').replaceFirst(
                to,
                '$tag\n$to',
              );

      expect(problems(_appDelegateTemplate), isEmpty);
      // Braces in the comments and strings of the method do not end it.
      expect(
        problems(
          _appDelegateTemplate.replaceFirst(
            tag,
            '    // A } of a comment.\n'
            '    print("A } of a string")\n'
            '$tag',
          ),
        ),
        isEmpty,
      );
      // A call of super in a comment or a string before the tag is no call,
      // and a space before the parenthesis of the call is.
      expect(
        problems(
          _appDelegateTemplate
              .replaceFirst(
                'super.application(application',
                'super.application (application',
              )
              .replaceFirst(
                tag,
                '    // super.application(application, '
                'didFinishLaunchingWithOptions: launchOptions)\n'
                '    print("super.application(")\n'
                '$tag',
              ),
        ),
        isEmpty,
      );
      // In the method that registers the plugins, which runs once the scene
      // of the app connects: too late for a tap that launched the app.
      expect(problems(moved('    GeneratedPluginRegistrant')), [notInBody]);
      // In another method that the launch calls, or in no method at all.
      expect(
        problems(
          _appDelegateTemplate.replaceFirst(
            'didFinishLaunchingWithOptions launchOptions',
            'willFinishLaunchingWithOptions launchOptions',
          ),
        ),
        [notInBody],
      );
      expect(
        problems('import UIKit\n\nclass AppDelegate: FlutterAppDelegate {\n'
            '$tag\n}\n'),
        [notInBody],
      );
      // After Flutter took the launch, or in a method that never hands it
      // over.
      expect(problems(moved('  }\n\n  func didInitialize')), [notFirst]);
      expect(
        problems(
          _appDelegateTemplate.replaceFirst(
            'return super.application(application, '
                'didFinishLaunchingWithOptions: launchOptions)',
            'return true',
          ),
        ),
        [noCall],
      );
      final issue = issues(moved('    GeneratedPluginRegistrant')).single;
      expect(issue.origin, const ModuleOrigin(ModuleId('scaffold')));
      expect(issue.path, path);

      // An app delegate without the tag: the rule of the lines of the
      // native files reports a tag in another file.
      expect(problems('import UIKit\n'), isEmpty);
    });

    test(
        'the tags of the Android manifest are among the children of the '
        'element that their contributions belong to', () {
      const path = AppEntryRole.androidManifestFile;
      const permissions = '{{{smf_app_entry__android_manifest_permissions}}}';
      const meta = '{{{smf_app_entry__android_manifest_application_meta}}}';
      const components =
          '{{{smf_app_entry__android_manifest_application_components}}}';
      const filters = '{{{smf_app_entry__main_activity_intent_filters}}}';
      List<String> problems(String template) => [
            for (final issue in checkModule({path: template})) issue.message,
          ];
      String notIn(String tag, String parent) =>
          'The tag $tag is in $path, but not among the children of '
          '<$parent>, where its contributions belong.';

      // A comment with an element does not open it.
      expect(
        problems(
          _manifestTemplate.replaceFirst(
            '    <application>',
            '    <!-- <application> <activity> -->\n    <application>',
          ),
        ),
        isEmpty,
      );
      // Each of the four in the wrong element: the components after the
      // application, which the Android build refuses.
      expect(
        problems('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="{{app_name.titleCase()}}">
$permissions
        <activity android:name=".MainActivity">
$meta
        </activity>
$filters
    </application>
$components
</manifest>
'''),
        [
          equals(notIn(permissions, 'manifest')),
          equals(notIn(meta, 'application')),
          equals(notIn(components, 'application')),
          equals(notIn(filters, 'activity')),
        ],
      );
      // Outside every element.
      expect(
        problems('</manifest>\n$permissions\n'),
        [equals(notIn(permissions, 'manifest'))],
      );
      final issue = checkModule({path: '$components\n'}).single;
      expect(issue.origin, const ModuleOrigin(ModuleId('scaffold')));
      expect(issue.path, path);
    });

    group('the rule of the flavors', () {
      const pubspec = 'pubspec.yaml';
      const gradle = AppEntryRole.gradleAppFile;
      const project = AppEntryRole.xcodeProjectFile;
      final dev = AppEntryRole.flavors.first;
      final prod = AppEntryRole.flavors.last;

      /// The messages of every structural rule over [texts].
      List<String> check(Map<String, String> texts) => messages(
            checkWith(appEntryRole, texts, const [AppEntryRole.iosAppIdStep]),
          );

      /// The messages over the flavored app, once [change] replaced the text
      /// of the file at [path].
      List<String> checkChanged(String path, String Function(String) change) {
        final texts = _flavoredApp();
        return check({...texts, path: change(texts[path]!)});
      }

      test('accepts an app with the flavors of the role', () {
        expect(
          _flavoredProject,
          contains('name = "Debug-dev";'),
          reason: 'A name with a hyphen is quoted in the project.',
        );
        expect(check(_flavoredApp()), isEmpty);
      });

      test('looks at no project that the app does not have', () {
        expect(check(const {}), isEmpty);
        expect(check({pubspec: 'name: my_app\n'}), isEmpty);
      });

      test('holds a provider with the project of one platform alone', () {
        final texts = _flavoredApp();

        expect(
          check({pubspec: texts[pubspec]!, gradle: texts[gradle]!}),
          isEmpty,
        );
        expect(
          check({gradle: texts[gradle]!.replaceAll('.dev', '.other')}),
          [
            equals(_noDefaultFlavor),
            contains('The flavor dev in $gradle builds the application id'),
          ],
        );
        expect(
          check({
            project: texts[project]!,
            AppEntryRole.iosEntitlementsFile: _entitlements,
          }),
          [
            equals(_noDefaultFlavor),
            for (final flavor in AppEntryRole.flavors)
              equals(
                '${flavor.xcodeSchemeFile} is missing: a build of the flavor '
                '${flavor.name} selects the scheme of the flavor by its name.',
              ),
          ],
        );
      });

      test('reports a pubspec without the default flavor', () {
        final issues = checkWith(
          appEntryRole,
          {
            ..._flavoredApp(),
            pubspec: 'name: my_app\n\nflutter:\n  uses-material-design: true\n',
          },
          const [AppEntryRole.iosAppIdStep],
        );

        expect(messages(issues), [_noDefaultFlavor]);
        expect(
          issues.single.origin,
          const ModuleOrigin(ModuleId('flutter_core')),
        );
        expect(issues.single.path, pubspec);
        expect(issues.single.hint, contains('PubspecContribution.flutter'));
      });

      test('reads the default flavor from the flutter section alone', () {
        String inPubspec(String text) => 'name: my_app\n$text';
        for (final text in const [
          // In another section, as a comment and in a key of the section.
          'dependencies:\n  default-flavor: dev\n',
          'flutter:\n  # default-flavor: dev\n  generate: true\n',
          'flutter:\n  assets:\n    default-flavor: dev\n',
          'flutter:\n  generate: true\ndefault-flavor: dev\n',
          'default-flavor: dev\nflutter:\n  generate: true\n',
          // A key of the section after a section that ended.
          'flutter:\n  generate: true\nother:\n  default-flavor: dev\n',
        ]) {
          expect(
            checkChanged(pubspec, (_) => inPubspec(text)),
            [_noDefaultFlavor],
            reason: text,
          );
        }
        for (final text in const [
          'flutter:\n  default-flavor: dev\n',
          'flutter:\n  default-flavor: "dev"\n',
          "flutter:\n  default-flavor: 'dev'\n",
          'flutter:\n  default-flavor: dev # the plain build\n',
          'flutter: # the section\n\n    # a comment\n    default-flavor: dev',
          'flutter:\n  generate: true\n  default-flavor: dev\nother: 1\n',
        ]) {
          expect(
            checkChanged(pubspec, (_) => inPubspec(text)),
            isEmpty,
            reason: text,
          );
        }
      });

      test('reports a default flavor that names no flavor of the role', () {
        expect(
          checkChanged(pubspec, (_) => 'flutter:\n  default-flavor: beta\n'),
          [
            equals(
              'default-flavor in pubspec.yaml is "beta", which is no flavor of '
              'the role: dev, staging, prod.',
            ),
          ],
        );
      });

      test('leaves which flavor is the default to the test of a running app',
          () {
        // Only a run of the flutter tool shows what a plain command builds.
        expect(
          checkChanged(
            pubspec,
            (text) => text.replaceFirst('dev', prod.name),
          ),
          isEmpty,
        );
      });

      test('reports a flavor that Gradle lacks, and one that the role lacks',
          () {
        final block =
            RegExp(r'create\("staging"\) \{.*?\n        \}\n', dotAll: true);

        expect(
          checkChanged(gradle, (text) => text.replaceFirst(block, '')),
          ['$gradle has no flavor staging in productFlavors.'],
        );
        expect(
          checkChanged(
            gradle,
            (text) => text.replaceFirst('create("staging")', 'create("beta")'),
          ),
          [
            '$gradle has no flavor staging in productFlavors.',
            equals(
              '$gradle has the flavor beta in productFlavors, which is no '
              'flavor of the role: dev, staging, prod.',
            ),
          ],
        );
        // A block outside productFlavors is no flavor.
        expect(
          checkChanged(
            gradle,
            (text) => text.replaceFirst(block, '').replaceFirst(
                'android {',
                'other {\n  create("staging") {}\n}'
                    '\nandroid {'),
          ),
          ['$gradle has no flavor staging in productFlavors.'],
        );
      });

      test('reports a Gradle file without product flavors', () {
        expect(
          check({..._flavoredApp(), gradle: _plainGradle}),
          [
            '$gradle has no flavorDimensions, which product flavors need.',
            for (final flavor in AppEntryRole.flavors)
              '$gradle has no flavor ${flavor.name} in productFlavors.',
          ],
        );
      });

      test('reads no flavor from a comment of Gradle', () {
        expect(
          checkChanged(
            gradle,
            (text) => text
                .replaceFirst(
                  'flavorDimensions += "default"',
                  '// flavorDimensions += "default"',
                )
                .replaceFirst(
                  'applicationIdSuffix = ".dev"',
                  '/* applicationIdSuffix = ".dev" */',
                ),
          ),
          [
            '$gradle has no flavorDimensions, which product flavors need.',
            equals(
              'The flavor dev in $gradle builds the application id '
              'com.example.my_app, but the id of the flavor is '
              'com.example.my_app.dev.',
            ),
          ],
        );
      });

      test('reports a flavor without a dimension', () {
        expect(
          checkChanged(
            gradle,
            (text) => text.replaceFirst(
              '            dimension = "default"\n',
              '',
            ),
          ),
          ['The flavor dev in $gradle has no dimension.'],
        );
      });

      test('reports each id of Android that is not that of the flavor', () {
        String reported(String flavor, String id, String expected) =>
            'The flavor $flavor in $gradle builds the application id $id, but '
            'the id of the flavor is $expected.';

        // A wrong suffix.
        expect(
          checkChanged(
            gradle,
            (text) => text.replaceFirst(
              'applicationIdSuffix = ".staging"',
              'applicationIdSuffix = ".beta"',
            ),
          ),
          [
            reported(
              'staging',
              'com.example.my_app.beta',
              'com.example.my_app.staging',
            ),
          ],
        );
        // No suffix on a flavor that has one.
        expect(
          checkChanged(
            gradle,
            (text) => text.replaceFirst(
              '            applicationIdSuffix = ".dev"\n',
              '',
            ),
          ),
          [reported('dev', 'com.example.my_app', 'com.example.my_app.dev')],
        );
        // A suffix on the flavor that has the id of the app.
        expect(
          checkChanged(
            gradle,
            (text) => text.replaceFirst(
              'create("prod") {',
              'create("prod") {\n            applicationIdSuffix = ".prod"',
            ),
          ),
          [reported('prod', 'com.example.my_app.prod', 'com.example.my_app')],
        );
        // Another id of the app, which each flavor adds its suffix to.
        expect(
          checkChanged(
            gradle,
            (text) => text.replaceFirst(
              'applicationId = "com.example.my_app"',
              'applicationId = "com.other.app"',
            ),
          ),
          [
            reported('dev', 'com.other.app.dev', 'com.example.my_app.dev'),
            reported(
              'staging',
              'com.other.app.staging',
              'com.example.my_app.staging',
            ),
            reported('prod', 'com.other.app', 'com.example.my_app'),
          ],
        );
        // An id of its own, without a suffix, is the id of the flavor too.
        expect(
          checkChanged(
            gradle,
            (text) => text.replaceFirst(
              'applicationIdSuffix = ".dev"',
              'applicationId = "com.example.my_app.dev"',
            ),
          ),
          isEmpty,
        );
      });

      test('leaves the form of the label of a flavor to its provider', () {
        // A provider may have strings.xml for each flavor.
        expect(
          checkChanged(
            gradle,
            (text) => text.replaceAll(
              RegExp(r' *manifestPlaceholders\[.*\n'),
              '',
            ),
          ),
          isEmpty,
        );
        expect(
          checkChanged(
            project,
            (text) => text.replaceAll(RegExp(r'\t*APP_DISPLAY_NAME.*\n'), ''),
          ),
          isEmpty,
        );
      });

      test('reports a configuration that one list of the project lacks', () {
        final id = _configurationId('C', 'Profile-staging');

        expect(
          checkChanged(
            project,
            (text) => text.replaceFirst(
              RegExp('\t*$id /\\* Profile-staging \\*/,\n'),
              '',
            ),
          ),
          [
            equals(
              'The build configuration list ${_listId('C')} in $project lacks '
              'Profile-staging.',
            ),
          ],
        );
      });

      test('reads the name of a configuration from the object', () {
        // The comment of the list and of the object say Debug-dev.
        expect(
          checkChanged(
            project,
            (text) => text.replaceFirst(
              'name = "Debug-dev";',
              'name = "Debug-other";',
            ),
          ),
          [
            equals(
              'The build configuration list ${_listId('A')} in $project lacks '
              'Debug-dev.',
            ),
          ],
        );
        // The first configuration in the file is that of the project. So that
        // of the app target is the one after the last of the project.
        final ofApp = _configurationId('B', 'Debug-dev');
        expect(
          checkChanged(
            project,
            (text) => text.replaceFirstMapped(
              RegExp('$ofApp /\\*.*?name = "Debug-dev";', dotAll: true),
              (match) =>
                  match[0]!.replaceFirst('name = "Debug-dev"', 'name = Debug'),
            ),
          ),
          [
            equals(
              'The build configuration list ${_listId('B')} in $project lacks '
              'Debug-dev.',
            ),
            equals(
              '$project has no build configuration Debug-dev of the app '
              'target, with INFOPLIST_FILE = Runner/Info.plist.',
            ),
          ],
        );
      });

      test(
          'reports a configuration of the app target that has no id of its '
          'flavor', () {
        final other = prod.bundleIdIn(testContext.appIdentity);
        final ofDev = dev.bundleIdIn(testContext.appIdentity);

        expect(
          checkChanged(
            project,
            (text) => text.replaceFirst(
              'PRODUCT_BUNDLE_IDENTIFIER = $ofDev;',
              'PRODUCT_BUNDLE_IDENTIFIER = $other;',
            ),
          ),
          [
            equals(
              'The build configuration Debug-dev of the app target in $project '
              'has the bundle id "$other", but the id of the flavor is '
              '$ofDev.',
            ),
          ],
        );
        expect(
          checkChanged(
            project,
            (text) => text.replaceFirst(
              'PRODUCT_BUNDLE_IDENTIFIER = $ofDev;',
              '',
            ),
          ),
          [
            equals(
              'The build configuration Debug-dev of the app target in $project '
              'has the bundle id "", but the id of the flavor is $ofDev.',
            ),
          ],
        );
        // In quotes it is the same id.
        expect(
          checkChanged(
            project,
            (text) => text.replaceFirst(
              'PRODUCT_BUNDLE_IDENTIFIER = $ofDev;',
              'PRODUCT_BUNDLE_IDENTIFIER = "$ofDev";',
            ),
          ),
          isEmpty,
        );
      });

      test('reports a configuration of the app target without a base', () {
        expect(
          checkChanged(project, (text) {
            final at = text.indexOf(
              '${_configurationId('B', 'Release-staging')} /*',
            );
            return text.replaceRange(
              at,
              null,
              text.substring(at).replaceFirst(
                    RegExp(r'\t*baseConfigurationReference.*\n'),
                    '',
                  ),
            );
          }),
          [
            equals(
              'The build configuration Release-staging of the app target in '
              '$project has no baseConfigurationReference, so it reads no '
              'ios/Flutter/Generated.xcconfig.',
            ),
          ],
        );
      });

      test('reports flavors of a mode with different bases', () {
        expect(
          checkChanged(project, (text) {
            final at =
                text.indexOf('${_configurationId('B', 'Debug-prod')} /*');
            return text.replaceRange(
              at,
              null,
              text.substring(at).replaceFirst(
                    'baseConfigurationReference = $_debugBase',
                    'baseConfigurationReference = $_releaseBase',
                  ),
            );
          }),
          [
            equals(
              'The build configurations Debug-dev, Debug-staging, Debug-prod '
              'of the app target in $project do not share one '
              'baseConfigurationReference.',
            ),
          ],
        );
      });

      test('reports a scheme that is missing', () {
        final issues = checkWith(
          appEntryRole,
          _flavoredApp()..remove(dev.xcodeSchemeFile),
          const [AppEntryRole.iosAppIdStep],
        );

        expect(messages(issues), [
          equals(
            '${dev.xcodeSchemeFile} is missing: a build of the flavor dev '
            'selects the scheme of the flavor by its name.',
          ),
        ]);
        expect(issues.single.path, dev.xcodeSchemeFile);
        expect(
          issues.single.origin,
          const ModuleOrigin(ModuleId('flutter_core')),
        );
      });

      test('reports each action of a scheme that takes another configuration',
          () {
        final file = dev.xcodeSchemeFile;
        const actions = {
          'TestAction': 'Debug-dev',
          'LaunchAction': 'Debug-dev',
          'AnalyzeAction': 'Debug-dev',
          'ProfileAction': 'Profile-dev',
          'ArchiveAction': 'Release-dev',
        };
        for (final MapEntry(key: action, value: configuration)
            in actions.entries) {
          // The configuration of another flavor, or of another mode.
          expect(
            checkChanged(
              file,
              (text) => text.replaceFirst(
                RegExp('(?<=<$action\n *buildConfiguration = ")[^"]*'),
                'Release-staging',
              ),
            ),
            [
              equals(
                '$action of $file takes the build configuration '
                '"Release-staging", but this flavor builds $configuration '
                'there.',
              ),
            ],
          );
          // None at all.
          expect(
            checkChanged(
              file,
              (text) => text.replaceFirst(
                RegExp('(?<=<$action)\n *buildConfiguration = "[^"]*"'),
                '',
              ),
            ),
            [
              equals(
                '$action of $file takes the build configuration "", but this '
                'flavor builds $configuration there.',
              ),
            ],
            reason: action,
          );
        }
      });

      test('reports a scheme without the action or with one in a comment', () {
        final file = dev.xcodeSchemeFile;

        expect(
          checkChanged(
            file,
            (text) => text.replaceFirst(
              RegExp('<ArchiveAction.*?</ArchiveAction>', dotAll: true),
              '',
            ),
          ),
          [
            equals(
              'ArchiveAction of $file takes the build configuration "", but '
              'this flavor builds Release-dev there.',
            ),
          ],
        );
        expect(
          checkChanged(
            file,
            (text) => text.replaceFirst(
              RegExp('<ArchiveAction.*?</ArchiveAction>', dotAll: true),
              (RegExp('<ArchiveAction.*?</ArchiveAction>', dotAll: true)
                      .stringMatch(text)!)
                  .replaceFirst('<ArchiveAction', '<!-- <ArchiveAction')
                  .replaceFirst('</ArchiveAction>', '</ArchiveAction> -->'),
            ),
          ),
          [
            equals(
              'ArchiveAction of $file takes the build configuration "", but '
              'this flavor builds Release-dev there.',
            ),
          ],
        );
      });

      test('reports a scheme without the pre-action of its build', () {
        final file = dev.xcodeSchemeFile;
        final reported =
            'BuildAction of $file has no pre-action that runs xcode_backend.sh '
            'prepare.';

        // No pre-action at all.
        expect(
          checkChanged(
            file,
            (text) => text.replaceFirst(
              RegExp('<PreActions>.*?</PreActions>', dotAll: true),
              '',
            ),
          ),
          [reported],
        );
        // The script of another step of the tool.
        expect(
          checkChanged(
            file,
            (text) => text.replaceFirst(' prepare', ' build'),
          ),
          [reported],
        );
        // After the build, where it comes too late.
        expect(
          checkChanged(
            file,
            (text) => text
                .replaceFirst('<PreActions>', '<PostActions>')
                .replaceFirst('</PreActions>', '</PostActions>'),
          ),
          [reported],
        );
        // Before another action than the build.
        final preActions = RegExp('<PreActions>.*?</PreActions>', dotAll: true);
        expect(
          checkChanged(file, (text) {
            final moved = preActions.stringMatch(text)!;
            return text
                .replaceFirst(preActions, '')
                .replaceFirst('</TestAction>', '$moved</TestAction>');
          }),
          [reported],
        );
        // In a comment.
        expect(
          checkChanged(file, (text) {
            final kept = preActions.stringMatch(text)!;
            return text.replaceFirst(preActions, '<!-- $kept -->');
          }),
          [reported],
        );
      });

      test('reads the attributes of a scheme in either quotes', () {
        expect(
          checkChanged(
            dev.xcodeSchemeFile,
            (text) => text.replaceAllMapped(
              RegExp('buildConfiguration = "([^"]*)"'),
              (match) => "buildConfiguration = '${match[1]}'",
            ),
          ),
          isEmpty,
        );
      });

      test('the signing of the app holds for each of its configurations', () {
        const signs = 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;';
        expect(_configurationNames, hasLength(12));
        for (final name in _configurationNames) {
          final id = _configurationId('B', name);

          expect(
            checkChanged(project, (text) {
              final at = text.indexOf('$id /*');
              return text.replaceRange(
                at,
                null,
                text.substring(at).replaceFirst(signs, ''),
              );
            }),
            [
              equals(
                'The build configuration $name ($id) of the app target in '
                '$project does not sign the app with '
                '${AppEntryRole.iosEntitlementsFile}.',
              ),
            ],
          );
        }
      });
    });

    group('the minimum iOS version in the templates of the Xcode project', () {
      const path = AppEntryRole.xcodeProjectFile;
      const tag = '{{{smf_app_entry__ios_deployment_target}}}';
      final template = _flavoredProject.replaceAll(
        'IPHONEOS_DEPLOYMENT_TARGET = 15.0;',
        'IPHONEOS_DEPLOYMENT_TARGET = $tag;',
      );

      List<String> problems(String text) => [
            for (final issue in checkModule({path: text})) issue.message,
          ];

      test('is the tag in every configuration of the project', () {
        expect(
          tag.allMatches(template),
          hasLength(12),
          reason: 'The twelve configurations of the project have the tag.',
        );
        expect(problems(template), isEmpty);
      });

      test('asks nothing of a provider without such a template', () {
        expect(checkModule({'README.md': '# My app\n'}), isEmpty);
      });

      test('reports a configuration of the project with a version of its own',
          () {
        final id = _configurationId('A', 'Debug-dev');
        final at = template.indexOf('$id /*');
        final issues = checkModule({
          path: template.replaceRange(
            at,
            null,
            template.substring(at).replaceFirst(tag, '15.0'),
          ),
        });

        expect(
          [for (final issue in issues) issue.message],
          [
            equals(
              'The build configuration Debug-dev ($id) in $path has '
              'IPHONEOS_DEPLOYMENT_TARGET = 15.0 instead of the tag $tag, so '
              'the version that a module raises does not reach it.',
            ),
          ],
        );
        expect(issues.single.origin, const ModuleOrigin(ModuleId('scaffold')));
        expect(issues.single.path, path);
      });

      test('reports a configuration of the project without the setting', () {
        final id = _configurationId('A', 'Release-prod');
        final at = template.indexOf('$id /*');

        expect(
          problems(
            template.replaceRange(
              at,
              null,
              template
                  .substring(at)
                  .replaceFirst('IPHONEOS_DEPLOYMENT_TARGET = $tag;', ''),
            ),
          ),
          [
            equals(
              'The build configuration Release-prod ($id) in $path has no '
              'IPHONEOS_DEPLOYMENT_TARGET, though the targets inherit it '
              'from there, so the version that a module raises does not '
              'reach it.',
            ),
          ],
        );
      });

      test('reports a target that sets a version of its own', () {
        final id = _configurationId('B', 'Debug-prod');
        final at = template.indexOf('$id /*');
        const setting = 'INFOPLIST_FILE = Runner/Info.plist;';

        expect(
          problems(
            template.replaceRange(
              at,
              null,
              template.substring(at).replaceFirst(
                    setting,
                    '$setting\n\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = "16.0";',
                  ),
            ),
          ),
          [
            equals(
              'The build configuration Debug-prod ($id) in $path has '
              'IPHONEOS_DEPLOYMENT_TARGET = 16.0 instead of the tag $tag, so '
              'the version that a module raises does not reach it.',
            ),
          ],
        );
        // A target may leave the setting to the project.
        expect(problems(template), isEmpty);
      });
    });

    test('the Gradle sockets refuse the plugins every app declares', () {
      expect(
        AppEntryRole.gradleAppPlugins.problemsWith(
          AppEntryRole.gradleAppPlugins.key('org.jetbrains.kotlin.android'),
        ),
        [
          equals(
            'socket app_entry.gradle_app_plugins does not take '
            'org.jetbrains.kotlin.android: the Flutter Gradle plugin applies '
            'the Kotlin plugin itself.',
          ),
        ],
      );
      expect(
        AppEntryRole.gradleSettingsPlugins.problemsWith(
          AppEntryRole.gradleSettingsPlugins
              .entry('com.android.application', '9.1.0'),
        ),
        [
          equals(
            'socket app_entry.gradle_settings_plugins does not take '
            'com.android.application: the provider of the app entry role '
            'declares it.',
          ),
        ],
      );
      expect(
        AppEntryRole.gradleAppPlugins.problemsWith(
          AppEntryRole.gradleAppPlugins.key('io.github.ben-manes.versions'),
        ),
        isEmpty,
      );
    });
  });

  test('AndroidMetaData compares by kind and text', () {
    const value = AndroidMetaData.value('a');

    expect(value, const AndroidMetaData.value('a'));
    expect(value.hashCode, const AndroidMetaData.value('a').hashCode);
    expect(value, isNot(const AndroidMetaData.resource('a')));
    expect(value.isResource, isFalse);
    expect(value.text, 'a');
    expect('$value', 'android:value="a"');
    expect(
      '${const AndroidMetaData.resource('@color/accent')}',
      'android:resource="@color/accent"',
    );
  });

  group('PlistValue', () {
    test('compares by value', () {
      expect(const PlistString('a'), const PlistString('a'));
      expect(const PlistString('a').hashCode, const PlistString('a').hashCode);
      expect(const PlistString('a'), isNot(const PlistString('b')));
      expect(const PlistBoolean(true), const PlistBoolean(true));
      expect(const PlistBoolean(true).hashCode, true.hashCode);
      expect(const PlistInteger(1), const PlistInteger(1));
      expect(const PlistInteger(1).hashCode, 1.hashCode);
      expect(
        const PlistStringArray(['a', 'b']),
        const PlistStringArray(['a', 'b']),
      );
      expect(
        const PlistStringArray(['a']).hashCode,
        const PlistStringArray(['a']).hashCode,
      );
      expect(
        const PlistStringArray(['a', 'b']),
        isNot(const PlistStringArray(['b', 'a'])),
      );
      expect(
        const PlistStringArray(['a']),
        isNot(const PlistStringArray(['a', 'b'])),
      );
      expect(
        const PlistStringArray(['fetch', 'fetch']).toXml(''),
        '<array>\n\t<string>fetch</string>\n</array>',
      );
      expect(const PlistStringArray(['a']), isNot(const PlistString('a')));
    });

    test('describes itself', () {
      expect('${const PlistString('a')}', 'a');
      expect('${const PlistBoolean(true)}', 'true');
      expect('${const PlistInteger(2)}', '2');
      expect('${const PlistStringArray(['a'])}', '[a]');
    });
  });

  test('the scaffold kind provides the app entry', () {
    expect(ModuleKinds.scaffold.id, 'scaffold');
    expect(ModuleKinds.scaffold.label, 'App scaffold');
    expect(ModuleKinds.scaffold.mustProvide, {appEntryRole});
  });
}

/// An `Info.plist` like the one of `flutter create`, shortened.
const _plist = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>MyApp</string>
	<key>UIApplicationSceneManifest</key>
	<dict>
		<key>UISceneConfigurations</key>
		<dict>
			<key>UIWindowSceneSessionRoleApplication</key>
			<array>
				<dict>
					<key>UISceneClassName</key>
					<string>UIWindowScene</string>
				</dict>
				<dict>
					<key>UISceneClassName</key>
					<string>UIWindowScene</string>
				</dict>
			</array>
		</dict>
	</dict>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
	</array>
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
</dict>
</plist>
''';

/// The entitlements of an iOS app with one entitlement.
const _entitlements = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
</dict>
</plist>
''';

/// The Xcode project of `flutter create` 3.44, shortened, whose app target
/// signs with its entitlements: the project, whose list of build
/// configurations has one of its own, and the build configurations, those
/// of the app target, which read its `Info.plist`, and one of the target of
/// its tests.
const _xcodeProject = r'''
// !$*UTF8*$!
{
	objects = {

/* Begin PBXProject section */
		97C146E61CF9000F007C117D /* Project object */ = {
			isa = PBXProject;
			attributes = {
				LastUpgradeCheck = 1510;
				TargetAttributes = {
					97C146ED1CF9000F007C117D = {
						CreatedOnToolsVersion = 7.3.1;
					};
				};
			};
			buildConfigurationList = 97C146E91CF9000F007C117D /* Build configuration list for PBXProject "Runner" */;
			targets = (
				97C146ED1CF9000F007C117D /* Runner */,
				331C8080294A63A400263BE5 /* RunnerTests */,
			);
		};
/* End PBXProject section */

/* Begin XCBuildConfiguration section */
		249021D3217E4FDB00AE95B9 /* Profile */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer";
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
			};
			name = Profile;
		};
		249021D4217E4FDB00AE95B9 /* Profile */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;
			buildSettings = {
				CLANG_ENABLE_MODULES = YES;
				CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
				INFOPLIST_FILE = Runner/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
			};
			name = Profile;
		};
		331C8088294A63A400263BE5 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				GENERATE_INFOPLIST_FILE = YES;
			};
			name = Debug;
		};
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;
			buildSettings = {
				CLANG_ENABLE_MODULES = YES;
				CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
				INFOPLIST_FILE = Runner/Info.plist;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		97C147071CF9000F007C117D /* Release */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;
			buildSettings = {
				CLANG_ENABLE_MODULES = YES;
				CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
				INFOPLIST_FILE = Runner/Info.plist;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		97C146E91CF9000F007C117D /* Build configuration list for PBXProject "Runner" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				249021D3217E4FDB00AE95B9 /* Profile */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				97C147061CF9000F007C117D /* Debug */,
				97C147071CF9000F007C117D /* Release */,
				249021D4217E4FDB00AE95B9 /* Profile */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = 97C146E61CF9000F007C117D /* Project object */;
}
''';

/// The app entry role with every structural rule but that of the flavors, for
/// tests that look at the other rules.
final class _AppEntryWithoutFlavorRule extends Role<NoDsl> {
  const _AppEntryWithoutFlavorRule();

  @override
  String get id => appEntryRole.id;

  @override
  String get description => appEntryRole.description;

  @override
  RoleCardinality get cardinality => appEntryRole.cardinality;

  @override
  bool get openToAllModules => appEntryRole.openToAllModules;

  @override
  List<StructuralRule<NoDsl>> get structuralRules => [
        for (final rule in appEntryRole.structuralRules)
          if (rule.id != 'app_entry.flavors') rule,
      ];
}

/// What the rule of the flavors says of a pubspec without the default flavor.
const _noDefaultFlavor = 'pubspec.yaml has no default-flavor in its flutter '
    'section, so a command of the flutter tool without --flavor cannot tell '
    'which flavor to build.';

/// The files that the rule of the flavors reads in an app with the flavors of
/// the role, shortened.
Map<String, String> _flavoredApp() => {
      'pubspec.yaml': 'name: my_app\n\nflutter:\n  default-flavor: "dev"\n'
          '  uses-material-design: true\n',
      AppEntryRole.gradleAppFile: _flavoredGradle,
      AppEntryRole.xcodeProjectFile: _flavoredProject,
      AppEntryRole.iosEntitlementsFile: _entitlements,
      for (final flavor in AppEntryRole.flavors)
        flavor.xcodeSchemeFile: _schemeOf(flavor.name),
    };

/// The build script of the app module without flavors.
const _plainGradle = '''
android {
    defaultConfig {
        applicationId = "com.example.my_app"
    }
}
''';

/// The build script of the app module with the flavors of the role.
const _flavoredGradle = '''
android {
    defaultConfig {
        // The id that each flavor adds to.
        applicationId = "com.example.my_app"
    }

    flavorDimensions += "default"
    productFlavors {
        create("dev") {
            dimension = "default"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appName"] = "My App Dev"
        }
        create("staging") {
            dimension = "default"
            applicationIdSuffix = ".staging"
            manifestPlaceholders["appName"] = "My App Staging"
        }
        create("prod") {
            dimension = "default"
            manifestPlaceholders["appName"] = "My App"
        }
    }
}
''';

/// The base of the configurations of the debug mode in [_flavoredProject].
const _debugBase = '9740EEB21CF90195004384FC';

/// The base of the configurations of the other modes.
const _releaseBase = '7AFA3C8E1D35360C0083082E';

/// The names of the build configurations of a list of [_flavoredProject].
final List<String> _configurationNames = [
  'Debug',
  'Release',
  'Profile',
  for (final flavor in AppEntryRole.flavors) ...flavor.xcodeConfigurations,
];

/// The id of the configuration [name] of the list [owner]: `A` for that of
/// the project, `B` for that of the app target and `C` for that of its tests.
String _configurationId(String owner, String name) => [
      owner,
      _configurationNames.indexOf(name).toString().padLeft(23, '0'),
    ].join();

/// The id of the configuration list of [owner].
String _listId(String owner) => '$owner${'F' * 23}';

/// An Xcode project with the flavors of the role, shortened from that of
/// `flutter create`: each configuration of the project and of its two targets
/// has only what the rules read.
final String _flavoredProject = () {
  String quoted(String name) => name.contains('-') ? '"$name"' : name;

  String configuration(String owner, String name, String settings) {
    final base = name.startsWith('Debug') ? _debugBase : _releaseBase;
    return '''
		${_configurationId(owner, name)} /* $name */ = {
			isa = XCBuildConfiguration;
			${owner == 'B' ? 'baseConfigurationReference = $base /* xcconfig */;' : ''}
			buildSettings = {
$settings
			};
			name = ${quoted(name)};
		};
''';
  }

  String idOfFlavor(String name) {
    final flavors = AppEntryRole.flavors.where(
      (flavor) => flavor.xcodeConfigurations.contains(name),
    );
    final identity = testContext.appIdentity;
    return flavors.isEmpty
        ? identity.iosBundleId
        : flavors.single.bundleIdIn(identity);
  }

  String list(String owner) => '''
		${_listId(owner)} /* Build configuration list of $owner */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
${[
        for (final name in _configurationNames)
          '\t\t\t\t${_configurationId(owner, name)} /* $name */,',
      ].join('\n')}
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
''';

  return '''
// !\$*UTF8*\$!
{
	objects = {

/* Begin PBXProject section */
		97C146E61CF9000F007C117D /* Project object */ = {
			isa = PBXProject;
			buildConfigurationList = ${_listId('A')} /* Build configuration list of A */;
		};
/* End PBXProject section */

/* Begin XCBuildConfiguration section */
${[
    for (final name in _configurationNames)
      configuration('A', name, '\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;'),
    for (final name in _configurationNames)
      configuration(
        'B',
        name,
        '''
				APP_DISPLAY_NAME = "My App";
				CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
				INFOPLIST_FILE = Runner/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = ${idOfFlavor(name)};''',
      ),
    for (final name in _configurationNames)
      configuration(
        'C',
        name,
        '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.my-app.RunnerTests;',
      ),
  ].join()}/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
${['A', 'B', 'C'].map(list).join()}/* End XCConfigurationList section */
	};
	rootObject = 97C146E61CF9000F007C117D /* Project object */;
}
''';
}();

/// The Xcode scheme of the flavor [name], shortened from that of Flutter's
/// template, with the attributes on lines of their own as Xcode writes them.
String _schemeOf(String name) => '''
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1510"
   version = "1.3">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <PreActions>
         <ExecutionAction
            ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent
               title = "Run Prepare Flutter Framework Script"
               scriptText = "/bin/sh &quot;\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh&quot; prepare&#10;">
            </ActionContent>
         </ExecutionAction>
      </PreActions>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug-$name"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug-$name"
      launchStyle = "0">
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Profile-$name"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug-$name">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release-$name"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
''';

/// An Android manifest like the one of `flutter create`, shortened.
const _manifest = r'''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA"/>
    <application
        android:label="My App"
        android:name="${applicationName}">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
        </activity>
        <!-- Don't delete the meta-data below. -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
''';

/// The app delegate of a provider, that of `flutter create` 3.44 with the
/// tag of the code that runs before the launch of the app finishes.
const _appDelegateTemplate = '''
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
{{{smf_app_entry__ios_app_delegate_launch}}}
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
''';

/// The manifest of a provider, with the tags of its sockets.
const _manifestTemplate = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
{{{smf_app_entry__android_manifest_permissions}}}
    <application>
        <activity android:name=".MainActivity">
{{{smf_app_entry__main_activity_intent_filters}}}
        </activity>
{{{smf_app_entry__android_manifest_application_meta}}}
{{{smf_app_entry__android_manifest_application_components}}}
    </application>
</manifest>
''';

/// The Gradle settings of `flutter create` 3.44, shortened.
const _settings = '''
pluginManagement {
    repositories {
        google()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}
''';

/// The build script of the app module of `flutter create` 3.44, shortened.
const _appGradle = '''
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
''';

MasonBundle _bundle(Map<String, String> files) => MasonBundle(
      name: 'scaffold',
      description: 'scaffold',
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
    );

/// Collects the calls of the function or the constructor [name].
final class _Calls extends RecursiveAstVisitor<void> {
  _Calls(this.name, this.found);

  final String name;
  final List<MethodInvocation> found;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == name) found.add(node);
    super.visitMethodInvocation(node);
  }
}
