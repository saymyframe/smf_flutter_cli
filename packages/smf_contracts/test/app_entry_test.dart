import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The file of the provider with the root widget of the app.
const _appFile = 'lib/app.dart';

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
List<SmfIssue> _check(
  Map<String, DartFileIndex> files, {
  Map<String, ContributionOrigin> owners = const {},
}) {
  final request = StructuralRuleRequest(
    hook: const RoleHookRequest(
      data: [],
      presentRoles: {appEntryRole},
      context: testContext,
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
    ...appEntryRole.interface.checkSymbols(files),
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
      expect(appEntryRole.uses, isEmpty);
      expect(appEntryRole.template, isNull);
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
        ])
          file.split('/').first,
      };

      expect(projects, {'android', 'ios'});
    });

    test('owns all its sockets, with valid and distinct tags', () {
      final sockets = appEntryRole.sockets;
      final tags = [for (final socket in sockets) ...socket.tags];

      expect(sockets, hasLength(17));
      for (final socket in sockets) {
        expect(socket.role, same(appEntryRole), reason: '$socket');
        expect(socket.problems(), isEmpty, reason: '$socket');
      }
      expect(tags.toSet(), hasLength(tags.length));
      expect(tags, contains('smf_app_entry__bootstrap_platform'));
      expect(tags, contains('smf_app_entry__root_wrappers_open'));
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
        appEntryRole.structuralRules.map((rule) => rule.id),
        [
          'app_entry.bootstrap_without_material',
          'app_entry.main_sequence',
          'app_entry.material_root',
          'app_entry.root_in_build',
          'app_entry.native_keys',
        ],
      );
      expect(
        appEntryRole.moduleRules.map((rule) => rule.id),
        [
          'app_entry.bootstrap_phases',
          'app_entry.root_wrappers_in_main',
          'app_entry.tag_lines',
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
        'are one theme, dark theme, theme mode and locale, and the lists of '
        'the localizations', () {
      expect(socket.kind.args, {
        'theme': ArgShape.scalar,
        'darkTheme': ArgShape.scalar,
        'themeMode': ArgShape.scalar,
        'locale': ArgShape.scalar,
        'localizationsDelegates': ArgShape.list,
        'supportedLocales': ArgShape.list,
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
  });

  group('AppEntryRole native checks', () {
    List<SmfIssue> checkTexts(Map<String, String> texts) =>
        appEntryRole.checkStructure(
          StructuralRuleRequest(
            hook: const RoleHookRequest(
              data: [],
              presentRoles: {appEntryRole},
              context: testContext,
            ),
            files: const {},
            texts: texts,
            owners: {
              for (final path in texts.keys)
                path: const ModuleOrigin(ModuleId('flutter_core')),
            },
          ),
        );

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
          AppEntryRole.gradleSettingsFile:
              'plugins {\n{{{smf_app_entry__gradle_settings_plugins}}}\n}\n',
          AppEntryRole.gradleAppFile: 'plugins {\n'
              '{{{smf_app_entry__gradle_app_plugins}}}\n}\n\n'
              'dependencies {\n'
              '{{{smf_app_entry__gradle_app_dependencies}}}\n}\n',
          AppEntryRole.readmeFile: '# {{app_name}}\n\nAn app.\n'
              '{{{smf_app_entry__readme_sections}}}\n',
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
        AppEntryRole.readmeFile:
            '# {{app_name}}\n\nAn app. {{{smf_app_entry__readme_sections}}}\n',
      });

      expect(issues.map((issue) => issue.message), [
        equals(
          'The tag {{{smf_app_entry__android_manifest_permissions}}} must '
          'stand alone at the start of a line of '
          'android/app/src/main/AndroidManifest.xml, because its '
          'contributions render as complete lines.',
        ),
        equals(
          'The tag {{{smf_app_entry__info_plist}}} is in ios/Podfile, but its '
          'lines belong in ios/Runner/Info.plist.',
        ),
        equals(
          'The tag {{{smf_app_entry__readme_sections}}} must stand alone at '
          'the start of a line of README.md, because its contributions render '
          'as complete lines.',
        ),
      ]);
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

/// The manifest of a provider, with the tags of its sockets.
const _manifestTemplate = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
{{{smf_app_entry__android_manifest_permissions}}}
    <application>
        <activity android:name=".MainActivity">
{{{smf_app_entry__main_activity_intent_filters}}}
        </activity>
{{{smf_app_entry__android_manifest_application_meta}}}
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
