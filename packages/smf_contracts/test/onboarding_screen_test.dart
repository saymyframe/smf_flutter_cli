@TestOn('vm')
library;

import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';
import 'role_support.dart';
import 'support.dart';

const _material = ImportRef('package:flutter/material.dart');

const _bell = Fragment('Icons.notifications', imports: [_material]);

const _permissionFile = ImportRef.app('core/permissions/permission_step.dart');
const _permissionPath = 'lib/core/permissions/permission_step.dart';

const _tipsFile = ImportRef.app('features/tips/tips_step.dart');
const _tipsPath = 'lib/features/tips/tips_step.dart';

const _ask = FunctionRef('askPermission', import: _permissionFile);
const _unasked = FunctionRef('permissionUnasked', import: _permissionFile);
const _showTips = FunctionRef('showTips', import: _tipsFile);

const _welcomePath = 'lib/features/welcome/welcome_screen.dart';

const _permissions = ModuleOrigin(ModuleId('permissions'));
const _welcome = ModuleOrigin(ModuleId('welcome'));

/// A role whose template gives the onboarding a step, as a role that asks
/// for a permission does, with the texts of the step for the localization
/// role.
final _alertsRole = TestRole<NoDsl>(
  'alerts',
  uses: {onboardingScreenRole, localizationRole},
);

/// Another role whose template gives the onboarding a step, with its texts
/// for the localization role.
final _hintsRole = TestRole<NoDsl>(
  'hints',
  uses: {onboardingScreenRole, localizationRole},
);

/// A role whose template gives the onboarding a step, but which neither
/// requires nor uses the localization role.
final _mutedRole = TestRole<NoDsl>('muted', uses: {onboardingScreenRole});

/// The step [name] of the tests, whose texts are named after it, or after
/// [textNames] if it is set, and read
/// `<name> title` and so on in English, and with [translated] also
/// `uk <name> title` and so on in Ukrainian; with the button `later` unless
/// [later] is `false`, and of the stage [stage].
OnboardingStep _step(
  String name, {
  String? textNames,
  FunctionRef run = _ask,
  FunctionRef? showIf,
  bool later = true,
  bool translated = false,
  Fragment icon = _bell,
  OnboardingStage stage = OnboardingStage.permission,
}) {
  LocalizedText text(String suffix, String en) => LocalizedText(
        '${textNames ?? name}$suffix',
        en: '$name $en',
        translations: {if (translated) 'uk': 'uk $name $en'},
      );
  return OnboardingStep(
    name: name,
    stage: stage,
    icon: icon,
    title: text('Title', 'title'),
    text: text('Text', 'text'),
    action: text('Action', 'action'),
    later: later ? text('Later', 'later') : null,
    run: run,
    showIf: showIf,
  );
}

/// [step] as the module [module] contributes it.
RoleData<Object> _stepOf(
  OnboardingStep step, {
  String module = 'permissions',
}) =>
    dataOf(onboardingScreenRole, step, module: module);

/// [step] as the template of [role] contributes it.
RoleData<Object> _stepOfRole(OnboardingStep step, Role role) =>
    onboardingScreenRole.data(step).withOrigin(RoleTemplateOrigin(role));

/// The texts of [steps] for the localization role, as the module [module]
/// gives them.
RoleData<Object> _textsOf(
  List<OnboardingStep> steps, {
  String module = 'permissions',
}) =>
    dataOf(
      localizationRole,
      TextsData([for (final step in steps) ...step.shownTexts]),
      module: module,
    );

/// The texts of [steps] for the localization role, as the template of
/// [role] gives them.
RoleData<Object> _textsOfRole(List<OnboardingStep> steps, Role role) =>
    localizationRole
        .data(TextsData([for (final step in steps) ...step.shownTexts]))
        .withOrigin(RoleTemplateOrigin(role));

/// The routes of the module `welcome`: the onboarding at `/`, a page below
/// it, and a page that needs a value.
RoleData<Object> get _routes => dataOf(
      routerRole,
      const RoutesData([
        Route(
          '/',
          name: 'onboarding',
          screen: ScreenRef(
            'WelcomeScreen',
            import: ImportRef.app('features/welcome/welcome_screen.dart'),
          ),
          children: [
            Route(
              'more',
              name: 'more',
              screen: ScreenRef(
                'MoreScreen',
                import: ImportRef.app('features/welcome/more_screen.dart'),
              ),
            ),
          ],
        ),
        Route(
          '/pages/:page',
          name: 'page',
          screen: ScreenRef(
            'PageScreen',
            import: ImportRef.app('features/welcome/page_screen.dart'),
          ),
          params: [RouteParam.path('page', type: int)],
        ),
      ]),
      module: 'welcome',
    );

/// The route [name] that the module [module] names as the onboarding
/// screen.
RoleData<Object> _screenRoute(String name, {String module = 'welcome'}) =>
    dataOf(onboardingScreenRole, OnboardingScreenRoute(name), module: module);

/// The input of the hooks of the onboarding screen role in an app with
/// [data] and a router, where the roles in [present] are present too.
RoleHookInput<OnboardingData> _input(
  List<RoleData<Object>> data, {
  Set<Role> present = const {},
}) =>
    inputOf(
      onboardingScreenRole,
      data: data,
      present: {routerRole, ...present},
    );

/// A feature that provides the onboarding screen role.
const _provider = ModuleDescriptor(
  id: ModuleId('welcome'),
  description: 'Welcome',
  kind: ModuleKinds.feature,
  providers: [RoleProvider.plain(onboardingScreenRole)],
);

/// A module with a step, which uses the role and the localization role.
const _contributor = ModuleDescriptor(
  id: ModuleId('permissions'),
  description: 'Permissions',
  kind: ModuleKinds.infrastructure,
  uses: {onboardingScreenRole, localizationRole},
);

/// A module with a step that uses the role but not the localization role.
const _plainContributor = ModuleDescriptor(
  id: ModuleId('permissions'),
  description: 'Permissions',
  kind: ModuleKinds.infrastructure,
  uses: {onboardingScreenRole},
);

/// A brick named [name] with a file at each of [paths].
BrickContribution _brick(
  List<String> paths, {
  String name = 'brick',
  Set<Role> when = const {},
}) =>
    BrickContribution(
      MasonBundle(
        name: name,
        description: name,
        version: '0.1.0',
        files: [
          for (final path in paths)
            MasonBundledFile(
              path,
              base64.encode(utf8.encode('// A file of the tests.\n')),
              'text',
            ),
        ],
      ),
      when: when,
    );

/// The issues of the module rules of the role for [module], which
/// contributes [contributions], in an app with a router where the roles in
/// [present] are present too and other contributors give the role [others].
List<SmfIssue> _moduleIssues(
  ModuleDescriptor module,
  List<Contribution> contributions, {
  List<RoleData<Object>> others = const [],
  Set<Role> present = const {},
}) {
  final origin = ModuleOrigin(module.id);
  // The pipeline gives each data its origin when it collects it.
  final own = [
    for (final contribution in contributions)
      if (contribution is RoleData<Object>)
        contribution.withOrigin(origin)
      else
        contribution,
  ];
  return onboardingScreenRole.checkModule(
    ModuleRuleRequest(
      hook: RoleHookRequest(
        data: [...own.whereType<RoleData<Object>>(), ...others],
        presentRoles: {onboardingScreenRole, routerRole, ...present},
        context: testContext,
      ),
      module: module,
      contributions: own,
    ),
  );
}

/// The index of the file at [path] that declares the functions
/// [functions], each with the return type that it is written with, or
/// without one for `null`, and with no parameters.
DartFileIndex _functionsFile(String path, Map<String, String?> functions) =>
    DartFileIndex(
      path: path,
      declarations: [
        for (final MapEntry(key: name, value: type) in functions.entries)
          IndexedDeclaration(
            name: name,
            kind: DeclarationKind.function,
            type: type,
          ),
      ],
    );

/// The issues of the structural rules of the role in an app with [data],
/// the [files] with their [owners], and [modules].
List<SmfIssue> _structureIssues(
  List<RoleData<Object>> data, {
  required List<DartFileIndex> files,
  Map<String, ContributionOrigin> owners = const {},
  List<ModuleDescriptor> modules = const [],
}) =>
    onboardingScreenRole.checkStructure(
      StructuralRuleRequest(
        hook: RoleHookRequest(
          data: data,
          presentRoles: {onboardingScreenRole, routerRole},
          context: testContext,
        ),
        files: {for (final file in files) file.path: file},
        owners: owners,
        modules: modules,
      ),
    );

/// A stand-in for the part of Flutter's widgets library that the file of
/// the steps uses, with the signatures of Flutter 3.44, and a context that
/// is in a language, as one below the root of an app is.
const _widgets = '''
final class BuildContext {
  const BuildContext(this.language);

  /// The code of the language of the app at the context.
  final String language;
}

final class IconData {
  const IconData(this.codePoint);

  final int codePoint;
}
''';

/// A stand-in for the icons of Flutter's material library.
const _materialIcons = '''
import 'widgets.dart';

abstract final class Icons {
  static const IconData notifications = IconData(1);

  static const IconData lightbulb = IconData(2);
}
''';

/// The file of the texts of a provider of the localization role, with a
/// getter for each of [getters], which returns the name of the getter after
/// the language of the context.
String _textsFile(List<String> getters) => [
      "import 'package:flutter/widgets.dart';",
      '',
      'final class Texts {',
      '  const Texts(this._language);',
      '',
      '  final String _language;',
      for (final getter in getters) ...[
        '',
        "  String get $getter => '\$_language $getter';",
      ],
      '}',
      '',
      'extension AppTexts on BuildContext {',
      '  Texts get l10n => Texts(language);',
      '}',
      '',
    ].join('\n');

/// The files of the functions of the steps of the tests, which note each
/// call of an action in `calls` of the first.
const Map<String, String> _functionFiles = {
  _permissionPath: '''
/// The actions that ran, in order.
final List<String> calls = [];

Future<void> askPermission() async => calls.add('askPermission');

bool permissionUnasked() => false;
''',
  _tipsPath: '''
import 'package:my_app/core/permissions/permission_step.dart';

Future<bool> showTips() async {
  calls.add('showTips');
  return true;
}
''',
};

/// A script that sends the steps of the app: for each, its labels, each in
/// English and in Ukrainian, the code point of its icon and whether its
/// condition shows it, and then the actions that ran once it called the
/// action of each step in turn.
const _readSteps = r'''
import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:my_app/core/onboarding/onboarding_steps.dart';
import 'package:my_app/core/permissions/permission_step.dart';

Future<void> main(List<String> arguments, SendPort port) async {
  String labels(String Function(BuildContext context)? label) => label == null
      ? '-'
      : '${label(const BuildContext('en'))} / '
          '${label(const BuildContext('uk'))}';
  final steps = [
    for (final step in appOnboardingSteps)
      [
        labels(step.title),
        labels(step.text),
        labels(step.action),
        labels(step.later),
        '${step.icon.codePoint}',
        '${step.showIf?.call() ?? 'always'}',
      ],
  ];
  for (final step in appOnboardingSteps) {
    await step.run();
  }
  port.send([...steps, calls]);
}
''';

/// What [_readSteps] sends for the app whose file of the steps is [code],
/// once the file type-checks with the files of the functions against the
/// stand-ins of Flutter and [texts], the file of the texts of the app, if
/// it has one.
Future<Object?> _stepsOf(String code, {String? texts}) async {
  final files = DartFiles.write(
    {
      OnboardingScreenRole.stepsFile: code,
      ..._functionFiles,
      if (texts != null) LocalizationRole.textsFile: texts,
    },
    flutter: const {'widgets.dart': _widgets, 'material.dart': _materialIcons},
  );
  try {
    expect(await files.analysisProblems(), isEmpty, reason: code);
    return await files.run(_readSteps);
  } finally {
    files.delete();
  }
}

/// The top-level declarations of the Dart [code] by name, each as its
/// source.
Map<String, String> _topLevelOf(String code) => {
      for (final declaration in parseString(content: code).unit.declarations)
        switch (declaration) {
          FunctionDeclaration(:final name) => name.lexeme,
          TopLevelVariableDeclaration(:final variables) =>
            variables.variables.single.name.lexeme,
          ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
          _ => '$declaration',
        }: declaration.toSource(),
    };

/// The imports of the Dart [code], in order, each as its URI and, after a
/// space, its prefix if it has one.
List<String> _importsOf(String code) => [
      for (final directive in parseString(content: code).unit.directives)
        if (directive is ImportDirective)
          [
            directive.uri.stringValue,
            if (directive.prefix case final prefix?) prefix.name,
          ].join(' '),
    ];

/// The named arguments of each step of the list of the steps of the Dart
/// [code], each as its source by its name.
List<Map<String, String>> _itemsOf(String code) {
  final list = parseString(content: code)
      .unit
      .declarations
      .whereType<TopLevelVariableDeclaration>()
      .single
      .variables
      .variables
      .single
      .initializer! as ListLiteral;
  return [
    for (final item in list.elements)
      {
        for (final argument
            in (item as MethodInvocation).argumentList.arguments)
          if (argument
              case NamedArgument(:final name, :final argumentExpression))
            name.lexeme: argumentExpression.toSource(),
      },
  ];
}

/// The file of the steps that the template renders for [data], in an app
/// with a router and the roles in [present].
Future<String> _renderedSteps(
  List<RoleData<Object>> data, {
  Set<Role> present = const {},
}) async {
  final rendered = await renderTemplate(
    onboardingScreenRole,
    data: data,
    present: {routerRole, ...present},
  );
  return rendered.files[OnboardingScreenRole.stepsFile]!;
}

void main() {
  group('OnboardingStep', () {
    test('has the texts of its page and of its buttons', () {
      final step = _step('ask');

      expect(
        [for (final text in step.shownTexts) text.name],
        ['askTitle', 'askText', 'askAction', 'askLater'],
      );
      expect(
        [for (final text in _step('ask', later: false).shownTexts) text.name],
        ['askTitle', 'askText', 'askAction'],
      );
      expect('$step', 'onboarding step "ask"');
    });

    test('calls its action, and its condition if it has one', () {
      expect(_step('ask').functions, [_ask]);
      expect(_step('ask', showIf: _unasked).functions, [_ask, _unasked]);
    });

    test('has no problems with a name, an icon and functions of the app', () {
      expect(_step('ask', showIf: _unasked).problems(), isEmpty);
    });

    test('reports a name that is no lowerCamelCase identifier', () {
      for (final name in ['', 'Ask', 'ask_me', 'ask-me', '1ask']) {
        expect(
          _step(name).problems().single,
          'The onboarding step "$name" needs a name that is a lowerCamelCase '
          'identifier, such as permission.',
          reason: name,
        );
      }
    });

    test('reports an icon that is no expression, and its imports', () {
      for (final icon in const [
        Fragment(''),
        Fragment('  '),
        Fragment.wrap('Icon(', ')'),
      ]) {
        expect(
          _step('ask', icon: icon).problems().single,
          'The onboarding step "ask" has an icon that is not an expression, '
          'such as Icons.notifications.',
        );
      }
      expect(
        _step(
          'ask',
          icon: const Fragment(
            'Icons.notifications',
            imports: [ImportRef('flutter/material.dart')],
          ),
        ).problems(),
        [contains('flutter/material.dart')],
      );
    });

    test(
        'reports a function that is no public function of a file of the '
        'app', () {
      const private = FunctionRef('_ask', import: _permissionFile);
      const ofPackage = FunctionRef(
        'openAppSettings',
        import: ImportRef('package:app_settings/app_settings.dart'),
      );

      expect(_step('ask', run: private).problems(), [
        'The function "_ask" is not a public Dart function name.',
      ]);
      expect(
        _step('ask', showIf: ofPackage).problems().single,
        'The function openAppSettings of the onboarding step "ask" must be a '
        'function of a file of the app, imported with ImportRef.app.',
      );
    });
  });

  test('OnboardingScreenRoute names a route of the provider', () {
    const route = OnboardingScreenRoute('onboarding');

    expect(route.name, 'onboarding');
    expect('$route', 'onboarding screen route "onboarding"');
  });

  test('the stages of the steps are the permissions and then the offers', () {
    expect(
      OnboardingStage.values,
      [OnboardingStage.permission, OnboardingStage.offer],
    );
  });

  group('the onboarding screen role', () {
    test(
        'has at most one provider, requires the router and uses the '
        'localization role', () {
      expect(onboardingScreenRole.id, 'onboarding_screen');
      expect(onboardingScreenRole.description, 'Onboarding screen');
      expect('$onboardingScreenRole', 'onboarding screen role');
      expect(onboardingScreenRole.presenceFlag, 'has_onboarding_screen');
      expect(onboardingScreenRole.cardinality, RoleCardinality.atMostOne);
      expect(onboardingScreenRole.requires, {routerRole});
      expect(onboardingScreenRole.uses, {localizationRole});
    });

    test(
        'guarantees the file of the steps with their class, which the '
        'provider reads whole', () {
      expect(onboardingScreenRole.sockets, isEmpty);
      expect(onboardingScreenRole.socketFamilies, isEmpty);
      expect(onboardingScreenRole.options, isEmpty);
      expect(
        OnboardingScreenRole.stepsFile,
        'lib/core/onboarding/onboarding_steps.dart',
      );
      expect(onboardingScreenRole.interface.files, [
        OnboardingScreenRole.stepsFile,
      ]);
      expect(onboardingScreenRole.interface.symbols, [
        OnboardingScreenRole.step,
      ]);
      const fields = [
        'icon',
        'title',
        'text',
        'action',
        'run',
        'later',
        'showIf',
      ];
      expect(OnboardingScreenRole.step.name, 'OnboardingStep');
      expect(OnboardingScreenRole.step.path, OnboardingScreenRole.stepsFile);
      expect(OnboardingScreenRole.step.constConstructor, isTrue);
      expect(OnboardingScreenRole.step.namedParameters, fields);
      expect(OnboardingScreenRole.step.getters, fields);
      expect(OnboardingScreenRole.appOnboardingSteps, 'appOnboardingSteps');
    });

    test('takes steps and the route of the screen as its data', () {
      expect(onboardingScreenRole.accepts(_step('ask')), isTrue);
      expect(
        onboardingScreenRole.accepts(const OnboardingScreenRoute('a')),
        isTrue,
      );
      expect(onboardingScreenRole.accepts('ask'), isFalse);
    });

    test('has two module rules and two structural rules', () {
      expect(
        onboardingScreenRole.moduleRules.map((rule) => rule.id),
        ['onboarding_screen.steps', 'onboarding_screen.route'],
      );
      expect(
        onboardingScreenRole.structuralRules.map((rule) => rule.id),
        ['onboarding_screen.step_functions', 'onboarding_screen.steps_shown'],
      );
      for (final description in [
        ...onboardingScreenRole.moduleRules.map((rule) => rule.description),
        ...onboardingScreenRole.structuralRules.map(
          (rule) => rule.description,
        ),
      ]) {
        expect(description, endsWith('.'));
      }
    });
  });

  group('OnboardingScreenRole.stepsIn', () {
    test(
        'lists the steps in the order of the data: those of the modules, '
        'then those of the templates of roles, and those of one contributor '
        'in its order', () {
      final steps = onboardingScreenRole.stepsIn(
        _input([
          _stepOf(_step('ask')),
          _screenRoute('onboarding'),
          _stepOf(_step('tips'), module: 'tips'),
          _stepOf(_step('confirm')),
          _stepOfRole(_step('alert'), _alertsRole),
        ]),
      );

      expect(
        [for (final step in steps) step.fullName],
        [
          'permissions.ask',
          'tips.tips',
          'permissions.confirm',
          'alerts.alert',
        ],
      );
      expect(
        [for (final step in steps) step.owner],
        [
          _permissions,
          const ModuleOrigin(ModuleId('tips')),
          _permissions,
          RoleTemplateOrigin(_alertsRole),
        ],
      );
      expect(steps.first.step.name, 'ask');
      expect('${steps.last}', 'onboarding step alerts.alert');
    });

    test(
        'lists the steps of an offer after those of a permission, whatever '
        'the order of their contributors', () {
      final steps = onboardingScreenRole.stepsIn(
        _input([
          _stepOf(_step('paywall', stage: OnboardingStage.offer)),
          _stepOf(_step('ask'), module: 'tips'),
          _stepOfRole(_step('trial', stage: OnboardingStage.offer), _hintsRole),
          _stepOfRole(_step('alert'), _alertsRole),
        ]),
      );

      expect(
        [for (final step in steps) step.fullName],
        [
          'tips.ask',
          'alerts.alert',
          'permissions.paywall',
          'hints.trial',
        ],
      );
    });

    test('gives the step of a variant of a module to the module', () {
      final step = onboardingScreenRole
          .stepsIn(
            _input([
              onboardingScreenRole.data(_step('ask')).withOrigin(
                    const ModuleOrigin(
                      ModuleId('permissions'),
                      variant: ModuleId('bloc'),
                    ),
                  ),
            ]),
          )
          .single;

      expect(step.owner, _permissions);
      expect(step.fullName, 'permissions.ask');
    });

    test('leaves out a step whose condition does not hold', () {
      final steps = onboardingScreenRole.stepsIn(
        _input([
          onboardingScreenRole
              .data(_step('ask'), when: {_alertsRole}).withOrigin(_permissions),
          _stepOf(_step('tips')),
        ]),
      );

      expect([for (final step in steps) step.step.name], ['tips']);
    });

    test('is empty in an app whose modules add no step', () {
      expect(
        onboardingScreenRole.stepsIn(_input([_screenRoute('onboarding')])),
        isEmpty,
      );
    });

    test('reads the steps for a role that uses the onboarding screen', () {
      final steps = onboardingScreenRole.stepsIn(
        _alertsRole.hookInput(
          RoleHookRequest(
            data: [_stepOf(_step('ask'))],
            presentRoles: {_alertsRole, onboardingScreenRole},
            context: testContext,
          ),
        ),
      );

      expect([for (final step in steps) step.fullName], ['permissions.ask']);
    });
  });

  group('OnboardingScreenRole.screenIn', () {
    test('is the route that the provider names, among its routes', () {
      final screen = onboardingScreenRole.screenIn(
        _input([_routes, _stepOf(_step('ask')), _screenRoute('onboarding')]),
      )!;

      expect(screen.fullPath, '/welcome');
      expect(screen.fullName, 'welcome.onboarding');
      expect(screen.route.screen.className, 'WelcomeScreen');
      expect(screen.route.screen.file, _welcomePath);
      expect(
        onboardingScreenRole
            .screenIn(_input([_routes, _screenRoute('more')]))!
            .fullPath,
        '/welcome/more',
      );
    });

    test(
        'is missing when no module names it, the name is of no route, or a '
        'template of a role names it', () {
      expect(onboardingScreenRole.screenIn(_input([_routes])), isNull);
      expect(
        onboardingScreenRole.screenIn(_input([_routes, _screenRoute('end')])),
        isNull,
      );
      expect(
        onboardingScreenRole.screenIn(
          _input([_routes, _screenRoute('onboarding', module: 'tips')]),
        ),
        isNull,
      );
      expect(
        onboardingScreenRole.screenIn(
          _input([
            _routes,
            onboardingScreenRole
                .data(const OnboardingScreenRoute('onboarding'))
                .withOrigin(RoleTemplateOrigin(_alertsRole)),
          ]),
        ),
        isNull,
      );
    });

    test(
        'is one of the routes of the app, so another role reads it only if '
        'it requires or uses the router role too', () {
      final named = RoleHookRequest(
        data: [_routes, _screenRoute('onboarding')],
        presentRoles: {onboardingScreenRole, routerRole, _alertsRole},
        context: testContext,
      );

      expect(
        () => onboardingScreenRole.screenIn(_alertsRole.hookInput(named)),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('neither requires nor uses the router role'),
          ),
        ),
      );
    });
  });

  group('the template of the onboarding screen role', () {
    test('generates the class of a step, whose labels are functions', () async {
      final rendered = await renderTemplate(
        onboardingScreenRole,
        present: {routerRole},
      );

      expect(rendered.files.keys, [OnboardingScreenRole.stepsFile]);
      expect(rendered.elsewhere, isEmpty);
      final code = rendered.files[OnboardingScreenRole.stepsFile]!;
      expectParses(code);
      final declarations = _topLevelOf(code);
      expect(declarations.keys, [
        OnboardingScreenRole.step.name,
        OnboardingScreenRole.appOnboardingSteps,
      ]);
      expect(
        declarations[OnboardingScreenRole.appOnboardingSteps],
        'const List<OnboardingStep> appOnboardingSteps = [];',
      );
      expect(_importsOf(code), ['package:flutter/widgets.dart']);
      // The constructor and the fields of the class, as the symbol of the
      // role says, which the contract harness checks in every app with the
      // role, with their types, which the app is compiled with.
      final step = declarations[OnboardingScreenRole.step.name]!;
      expect(
        step,
        contains(
          'const OnboardingStep({required this.icon, required this.title, '
          'required this.text, required this.action, required this.run, '
          'this.later, this.showIf});',
        ),
      );
      for (final declaration in [
        'final IconData icon;',
        'final String Function(BuildContext context) title;',
        'final String Function(BuildContext context) text;',
        'final String Function(BuildContext context) action;',
        'final Future<void> Function() run;',
        'final String Function(BuildContext context)? later;',
        'final bool Function()? showIf;',
      ]) {
        expect(step, contains(declaration));
      }
      expect(await _stepsOf(code), [<String>[]]);
    });

    test(
        'generates the constant list of the steps of the app in their order, '
        'each with its icon, functions for its labels, and the functions of '
        'its contributor through a prefix of their file', () async {
      final code = await _renderedSteps([
        _stepOf(_step('ask', showIf: _unasked)),
        _stepOf(
          _step(
            'tips',
            run: _showTips,
            later: false,
            icon: const Fragment(
              'Icons.lightbulb',
              imports: [
                ImportRef('package:flutter/material.dart', show: ['Icons']),
              ],
            ),
          ),
          module: 'tips',
        ),
        _stepOf(_step('again')),
      ]);
      final declarations = _topLevelOf(code);

      expect(declarations.keys, [
        'OnboardingStep',
        'appOnboardingSteps',
        '_permissionsAskTitle',
        '_permissionsAskText',
        '_permissionsAskAction',
        '_permissionsAskLater',
        '_tipsTipsTitle',
        '_tipsTipsText',
        '_tipsTipsAction',
        '_permissionsAgainTitle',
        '_permissionsAgainText',
        '_permissionsAgainAction',
        '_permissionsAgainLater',
      ]);
      expect(
        declarations['appOnboardingSteps'],
        startsWith('const List<OnboardingStep> appOnboardingSteps = ['),
      );
      expect(_itemsOf(code), [
        {
          'icon': 'Icons.notifications',
          'title': '_permissionsAskTitle',
          'text': '_permissionsAskText',
          'action': '_permissionsAskAction',
          'run': 'step0.askPermission',
          'later': '_permissionsAskLater',
          'showIf': 'step0.permissionUnasked',
        },
        {
          'icon': 'Icons.lightbulb',
          'title': '_tipsTipsTitle',
          'text': '_tipsTipsText',
          'action': '_tipsTipsAction',
          'run': 'step1.showTips',
        },
        {
          'icon': 'Icons.notifications',
          'title': '_permissionsAgainTitle',
          'text': '_permissionsAgainText',
          'action': '_permissionsAgainAction',
          'run': 'step0.askPermission',
          'later': '_permissionsAgainLater',
        },
      ]);
      // Without the localization role, each label is its English text.
      expect(
        declarations['_permissionsAskTitle'],
        "String _permissionsAskTitle(BuildContext context) => 'ask title';",
      );
      // The imports of the icons, once each, and of the file of each
      // function with a prefix of its own, once for the functions of a file.
      expect(_importsOf(code), [
        'package:flutter/widgets.dart',
        'package:flutter/material.dart',
        'package:my_app/core/permissions/permission_step.dart step0',
        'package:my_app/features/tips/tips_step.dart step1',
      ]);
      expect(await _stepsOf(code), [
        [
          'ask title / ask title',
          'ask text / ask text',
          'ask action / ask action',
          'ask later / ask later',
          '1',
          'false',
        ],
        [
          'tips title / tips title',
          'tips text / tips text',
          'tips action / tips action',
          '-',
          '2',
          'always',
        ],
        [
          'again title / again title',
          'again text / again text',
          'again action / again action',
          'again later / again later',
          '1',
          'always',
        ],
        ['askPermission', 'showTips', 'askPermission'],
      ]);
    });

    test(
        'reads a label from the texts of the app when the contributor of the '
        'step gave the localization role the text, and as its English text '
        'otherwise', () async {
      final ask = _step('ask', translated: true);
      final alert = _step('alert', run: _showTips, translated: true);
      final code = await _renderedSteps(
        [
          // A module that lists the localization role and gave it the texts
          // of its step, a module that does not list it, and the template
          // of a role, whose texts the app reads from its texts.
          _stepOf(ask),
          _textsOf([ask]),
          _stepOf(_step('tips', run: _showTips, later: false), module: 'tips'),
          _stepOfRole(alert, _alertsRole),
          _textsOfRole([alert], _alertsRole),
        ],
        present: {localizationRole},
      );
      final declarations = _topLevelOf(code);

      expect(
        declarations['_permissionsAskTitle'],
        'String _permissionsAskTitle(BuildContext context) => '
        'context.l10n.permissionsAskTitle;',
      );
      expect(
        declarations['_tipsTipsTitle'],
        "String _tipsTipsTitle(BuildContext context) => 'tips title';",
      );
      expect(
        declarations['_alertsAlertLater'],
        'String _alertsAlertLater(BuildContext context) => '
        'context.l10n.alertsAlertLater;',
      );
      // The file of the texts of the app, once.
      expect(
        _importsOf(code).where((import) => import.contains('l10n')),
        ['package:my_app/core/l10n/l10n.dart'],
      );
      // The list is a constant, and the labels follow the language of the
      // context that they are read at.
      expect(
        await _stepsOf(
          code,
          texts: _textsFile([
            for (final (owner, step) in [
              ('permissions', ask),
              ('alerts', alert),
            ])
              for (final text in step.shownTexts)
                '$owner${text.name[0].toUpperCase()}${text.name.substring(1)}',
          ]),
        ),
        [
          [
            'en permissionsAskTitle / uk permissionsAskTitle',
            'en permissionsAskText / uk permissionsAskText',
            'en permissionsAskAction / uk permissionsAskAction',
            'en permissionsAskLater / uk permissionsAskLater',
            '1',
            'always',
          ],
          [
            'tips title / tips title',
            'tips text / tips text',
            'tips action / tips action',
            '-',
            '1',
            'always',
          ],
          [
            'en alertsAlertTitle / uk alertsAlertTitle',
            'en alertsAlertText / uk alertsAlertText',
            'en alertsAlertAction / uk alertsAlertAction',
            'en alertsAlertLater / uk alertsAlertLater',
            '1',
            'always',
          ],
          ['askPermission', 'showTips', 'showTips'],
        ],
      );
    });

    test(
        'names the functions of the labels of two steps apart when the id of '
        'one owner continues in the name of its step to that of another',
        () async {
      final code = await _renderedSteps([
        _stepOf(_step('tipsAsk', later: false)),
        _stepOf(
          _step('ask', run: _showTips, later: false),
          module: 'permissions_tips',
        ),
        _stepOf(_step('ask', later: false), module: 'permissions_tips2'),
      ]);
      final declarations = _topLevelOf(code);

      expect(
        declarations.keys.where((name) => name.endsWith('Title')),
        [
          '_permissionsTipsAskTitle',
          '_permissionsTipsAsk2Title',
          '_permissionsTips2AskTitle',
        ],
      );
      expect(
        declarations['_permissionsTipsAsk2Title'],
        'String _permissionsTipsAsk2Title(BuildContext context) => '
        "'ask title';",
      );
      expect(await _stepsOf(code), hasLength(4));
    });

    test('escapes the English text of a label', () async {
      final code = await _renderedSteps([
        _stepOf(
          const OnboardingStep(
            name: 'ask',
            stage: OnboardingStage.permission,
            icon: _bell,
            title: LocalizedText('title', en: r"Don't miss $5 deals"),
            text: LocalizedText('text', en: 'Text'),
            action: LocalizedText('action', en: 'Allow'),
            run: _ask,
          ),
        ),
      ]);

      expect(
        ((await _stepsOf(code))! as List).first,
        containsAllInOrder([r"Don't miss $5 deals / Don't miss $5 deals"]),
      );
    });

    test('refuses a text with problems, in every app', () {
      for (final present in <Set<Role>>[
        {routerRole},
        {routerRole, localizationRole},
      ]) {
        expect(
          () => onboardingScreenRole.template.render(
            inputOf(
              onboardingScreenRole,
              data: [
                _stepOf(
                  const OnboardingStep(
                    name: 'ask',
                    stage: OnboardingStage.permission,
                    icon: _bell,
                    title: LocalizedText('Title', en: 'Allow'),
                    text: LocalizedText('text', en: 'Text'),
                    action: LocalizedText('action', en: 'Allow'),
                    run: _ask,
                  ),
                ),
              ],
              present: present,
            ),
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('the template validates', () {
    final template = onboardingScreenRole.template;

    /// The messages of the issues that the template reports for [data], in
    /// an app with a router and the roles in [present].
    List<String> messagesOf(
      List<RoleData<Object>> data, {
      Set<Role> present = const {},
    }) =>
        [
          for (final issue in template.validate(_input(data, present: present)))
            issue.message,
        ];

    test(
        'nothing of the steps of modules, which the module rules check, and '
        'a route that a module names', () {
      expect(
        messagesOf([
          _stepOf(
            _step(
              'Ask',
              run: const FunctionRef('_ask', import: _permissionFile),
            ),
          ),
          _stepOf(_step('Ask')),
          _screenRoute('onboarding'),
        ]),
        isEmpty,
      );
    });

    test(
        'accepts the steps of a template that gives the localization role '
        'their texts', () {
      final steps = [_step('alert'), _step('later', translated: true)];

      for (final present in <Set<Role>>[
        {},
        {localizationRole},
      ]) {
        expect(
          messagesOf(
            [
              for (final step in steps) _stepOfRole(step, _alertsRole),
              _textsOfRole(steps, _alertsRole),
            ],
            present: present,
          ),
          isEmpty,
        );
      }
    });

    test(
        'reports the problems of a step of a template with the template: '
        'those of the step and of its texts, and a name given twice', () {
      final issues = template.validate(
        _input([
          _stepOfRole(_step('alert'), _alertsRole),
          _stepOfRole(
            _step(
              'alert',
              run: const FunctionRef('_alert', import: _permissionFile),
            ),
            _alertsRole,
          ),
          // Other templates may have a step of that name.
          _stepOfRole(_step('alert'), _hintsRole),
          _stepOfRole(_step('alert'), _mutedRole),
          _stepOfRole(
            const OnboardingStep(
              name: 'bad name',
              stage: OnboardingStage.permission,
              icon: _bell,
              title: LocalizedText('title', en: ' '),
              text: LocalizedText('text', en: 'Text'),
              action: LocalizedText('action', en: 'Allow'),
              run: _ask,
            ),
            _alertsRole,
          ),
        ]),
      );

      const twice = 'The template of the alerts role gives two onboarding '
          'steps named "alert".';
      const badName = 'The onboarding step "bad name" needs a name that is a '
          'lowerCamelCase identifier, such as permission.';
      expect(
        [
          for (final issue in issues)
            if (issue.origin == RoleTemplateOrigin(_alertsRole)) issue.message,
        ],
        [
          'The function "_alert" is not a public Dart function name.',
          twice,
          badName,
          'The text "title" has no English text.',
        ],
      );
      // The name is given twice by one template only: each template has
      // names of its own.
      expect(
        [
          for (final issue in issues)
            if (issue.origin == RoleTemplateOrigin(_hintsRole)) issue.message,
        ],
        isEmpty,
      );
      expect(
        [
          for (final issue in issues)
            if (issue.message.contains('two onboarding steps')) issue.origin,
        ],
        [RoleTemplateOrigin(_alertsRole)],
      );
    });

    test(
        'reports a step of a template whose role neither requires nor uses '
        'the localization role, in every app', () {
      for (final present in <Set<Role>>[
        {},
        {localizationRole},
      ]) {
        final issue = template
            .validate(
              _input(
                [_stepOfRole(_step('alert'), _mutedRole)],
                present: present,
              ),
            )
            .single;

        expect(
          issue.message,
          'The template of the muted role gives the onboarding step "alert", '
          'whose texts an app with the localization role reads from its '
          'texts, but the muted role neither requires nor uses the '
          'localization role, so it cannot give them. Add the localization '
          'role to the uses of the muted role, and give it the texts of the '
          'step.',
        );
        expect(issue.origin, RoleTemplateOrigin(_mutedRole));
      }
    });

    test(
        'reports a text of a step of a template that the template does not '
        'give the localization role, or gives it otherwise, in an app with '
        'the role', () {
      final alert = _step('alert', later: false);
      final other = LocalizedText(
        alert.text.name,
        en: alert.text.en,
        translations: const {'uk': 'Інший текст'},
      );
      final data = [
        _stepOfRole(alert, _alertsRole),
        localizationRole
            .data(TextsData([alert.title, other]))
            .withOrigin(RoleTemplateOrigin(_alertsRole)),
      ];

      const differs = 'The template of the alerts role gives the onboarding '
          'step "alert" the text "alertText", and the localization role a '
          'text of that name that differs from it. Give both roles the same '
          'text, such as one constant.';
      const missing = 'The template of the alerts role gives the onboarding '
          'step "alert" the text "alertAction", but not the localization '
          'role, so the app would read a text that it lacks. Give the role '
          'the texts of the step too: localizationRole.data(TextsData([...]), '
          'when: {onboardingScreenRole}).';
      expect(messagesOf(data), isEmpty);
      expect(
        messagesOf(data, present: {localizationRole}),
        [differs, missing],
      );
    });

    test('rejects a route of the screen that no module names', () {
      final issue = template
          .validate(
            _input([
              onboardingScreenRole
                  .data(const OnboardingScreenRoute('onboarding'))
                  .withOrigin(RoleTemplateOrigin(_alertsRole)),
            ]),
          )
          .single;

      expect(
        issue.message,
        'Only the module that provides the onboarding screen role names the '
        'route of the onboarding screen, not role:alerts.',
      );
      expect(issue.origin, RoleTemplateOrigin(_alertsRole));
    });
  });

  group('the module rule onboarding_screen.steps', () {
    test('accepts steps whose functions the bricks of the module generate', () {
      expect(
        _moduleIssues(_contributor, [
          onboardingScreenRole.data(_step('ask', showIf: _unasked)),
          onboardingScreenRole.data(_step('tips', run: _showTips)),
          _brick([_permissionPath]),
          _brick([_tipsPath], name: 'tips', when: {onboardingScreenRole}),
        ]),
        isEmpty,
      );
    });

    test(
        'rejects a function whose file the bricks that apply in the app do '
        'not generate', () {
      final issues = _moduleIssues(_contributor, [
        onboardingScreenRole.data(_step('ask', showIf: _showTips)),
        _brick([_permissionPath]),
        // The brick applies only in an app with the alerts role.
        _brick([_tipsPath], name: 'tips', when: {_alertsRole}),
      ]);

      expect(
          issues.single.message,
          'The function showTips of the onboarding step "ask" is in '
          '$_tipsPath, which the bricks of the module do not generate.');
      expect(issues.single.hint, contains('in a brick of the module'));
      expect(issues.single.origin, _permissions);
      expect(issues.single.path, _tipsPath);
      expect(
        _moduleIssues(
          _contributor,
          [
            onboardingScreenRole.data(_step('ask', showIf: _showTips)),
            _brick([_permissionPath]),
            _brick([_tipsPath], name: 'tips', when: {_alertsRole}),
          ],
          present: {_alertsRole},
        ),
        isEmpty,
      );
    });

    test('rejects a step with problems, and two steps of one name', () {
      final messages = [
        for (final issue in _moduleIssues(_contributor, [
          onboardingScreenRole.data(_step('ask')),
          onboardingScreenRole.data(_step('ask', icon: const Fragment(''))),
          onboardingScreenRole.data(
            _step(
              'Tips',
              textNames: 'tips',
              run: const FunctionRef(
                'openAppSettings',
                import: ImportRef('package:app_settings/app_settings.dart'),
              ),
            ),
          ),
          _brick([_permissionPath]),
        ]))
          issue.message,
      ];

      const noIcon = 'The onboarding step "ask" has an icon that is not an '
          'expression, such as Icons.notifications.';
      const badName = 'The onboarding step "Tips" needs a name that is a '
          'lowerCamelCase identifier, such as permission.';
      const ofPackage = 'The function openAppSettings of the onboarding step '
          '"Tips" must be a function of a file of the app, imported with '
          'ImportRef.app.';
      expect(messages, [
        noIcon,
        'The module gives two onboarding steps named "ask".',
        badName,
        ofPackage,
      ]);
    });

    test(
        'takes translations of the texts of a step only from a module that '
        'lists the localization role', () {
      final contributions = [
        onboardingScreenRole.data(_step('ask', translated: true)),
        _brick([_permissionPath]),
      ];

      expect(_moduleIssues(_contributor, contributions), isEmpty);
      final messages = [
        for (final issue in _moduleIssues(_plainContributor, contributions))
          issue.message,
      ];
      expect(messages, hasLength(4));
      expect(
        messages.first,
        startsWith(
          'The text "askTitle" has a translation into uk, but the module '
          'permissions does not list the localization role among its roles',
        ),
      );
      expect(
        _moduleIssues(_plainContributor, [
          onboardingScreenRole.data(_step('ask')),
          _brick([_permissionPath]),
        ]),
        isEmpty,
      );
    });

    test('checks the steps of the provider of the role too', () {
      final issues = _moduleIssues(_provider, [
        routerRole.data(_routes.value as RoutesData),
        onboardingScreenRole.data(const OnboardingScreenRoute('onboarding')),
        onboardingScreenRole.data(_step('ask')),
      ]);

      expect(issues.single.message, contains('askPermission'));
      expect(issues.single.origin, _welcome);
    });
  });

  group('the module rule onboarding_screen.route', () {
    /// The issues for the provider, which contributes its routes and
    /// [named].
    List<SmfIssue> ofProvider(List<String> named) => _moduleIssues(_provider, [
          routerRole.data(_routes.value as RoutesData),
          for (final name in named)
            onboardingScreenRole.data(OnboardingScreenRoute(name)),
        ]);

    test('accepts a provider that names a route of its own', () {
      expect(ofProvider(['onboarding']), isEmpty);
      expect(ofProvider(['more']), isEmpty);
    });

    test('rejects a provider that names no route, or two', () {
      for (final (named, count) in [
        (<String>[], 0),
        (['onboarding', 'more'], 2),
      ]) {
        final issue = ofProvider(named).single;

        expect(
          issue.message,
          'The provider of the onboarding screen role names exactly one '
          'route as the onboarding screen, but the module names $count.',
        );
        expect(issue.hint, contains('OnboardingScreenRoute'));
        expect(issue.origin, _welcome);
      }
    });

    test('rejects a name that is of no route of the provider', () {
      expect(
        ofProvider(['end']).single.message,
        'The module names its route "end" as the onboarding screen, but '
        'declares no route of that name.',
      );
    });

    test('rejects a route that needs values', () {
      expect(
        ofProvider(['page']).single.message,
        'The route "page" (/welcome/pages/:page) of the onboarding screen '
        'needs :page; the onboarding screen is reached without values.',
      );
    });

    test('rejects a module that names the route without providing the role',
        () {
      final issue = _moduleIssues(
        _contributor,
        [onboardingScreenRole.data(const OnboardingScreenRoute('onboarding'))],
        others: [_routes, _screenRoute('onboarding')],
      ).single;

      expect(
        issue.message,
        'The module names the route of the onboarding screen, which only the '
        'provider of the onboarding screen role does.',
      );
      expect(issue.origin, _permissions);
    });

    test('asks nothing of a module that only has steps', () {
      expect(
        _moduleIssues(
          _contributor,
          [
            onboardingScreenRole.data(_step('ask')),
            _brick([_permissionPath]),
          ],
          others: [_routes, _screenRoute('onboarding')],
        ),
        isEmpty,
      );
    });
  });

  group('the structural rule onboarding_screen.step_functions', () {
    /// The messages of the issues of the rule for the steps [data] and the
    /// [files] of the functions, which the module `permissions` generated
    /// unless [owners] say otherwise.
    List<String> messagesOf(
      List<RoleData<Object>> data,
      List<DartFileIndex> files, {
      Map<String, ContributionOrigin>? owners,
    }) =>
        [
          for (final issue in _structureIssues(
            data,
            files: files,
            owners:
                owners ?? {for (final file in files) file.path: _permissions},
          ))
            issue.message,
        ];

    test(
        'accepts top-level functions of the contributor that require no '
        'arguments, a Future for the action and a bool for the condition', () {
      for (final type in [
        'Future<void>',
        'Future<bool>',
        'Future',
        'Future< List<int> >',
      ]) {
        expect(
          messagesOf(
            [_stepOf(_step('ask', showIf: _unasked))],
            [
              _functionsFile(_permissionPath, {
                'askPermission': type,
                'permissionUnasked': 'bool',
              }),
            ],
          ),
          isEmpty,
          reason: type,
        );
      }
      // An optional parameter takes nothing from the onboarding.
      expect(
        messagesOf(
          [_stepOf(_step('ask'))],
          [
            const DartFileIndex(
              path: _permissionPath,
              declarations: [
                IndexedDeclaration(
                  name: 'askPermission',
                  kind: DeclarationKind.function,
                  type: 'Future<void>',
                  parameters: [
                    IndexedParameter(
                      'again',
                      kind: ParameterKind.optionalNamed,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('rejects a missing file and a missing function', () {
      const missing = '$_permissionPath is missing, so it cannot declare';
      expect(messagesOf([_stepOf(_step('ask', showIf: _unasked))], []), [
        '$missing function askPermission().',
        '$missing function permissionUnasked().',
      ]);
      expect(
        messagesOf(
          [_stepOf(_step('ask', showIf: _unasked))],
          [
            _functionsFile(_permissionPath, {'askPermission': 'Future<void>'}),
          ],
        ),
        [
          '$_permissionPath does not declare function permissionUnasked().',
        ],
      );
    });

    test(
        'rejects an action that does not return a Future, and a condition '
        'that does not return a bool', () {
      // A function that may return null cannot be torn off as a run of the
      // list of the steps, whose type returns a Future.
      for (final type in [
        'void',
        'FutureOr<void>',
        'bool',
        'Future<void>?',
        'Future?',
        null,
      ]) {
        expect(
          messagesOf(
            [_stepOf(_step('ask'))],
            [
              _functionsFile(_permissionPath, {'askPermission': type}),
            ],
          ).single,
          'function askPermission() in $_permissionPath must return a Future, '
          'not ${type ?? 'an undeclared type'}.',
          reason: type,
        );
      }
      final issue = _structureIssues(
        [_stepOf(_step('ask', showIf: _unasked))],
        files: [
          _functionsFile(_permissionPath, {
            'askPermission': 'Future<void>',
            'permissionUnasked': 'Future<bool>',
          }),
        ],
        owners: {_permissionPath: _permissions},
      ).single;
      expect(
        issue.message,
        'function permissionUnasked() in $_permissionPath must return bool, '
        'not Future<bool>.',
      );
      expect(issue.hint, contains('takes the answer at once'));
      expect(issue.origin, _permissions);
      expect(issue.path, _permissionPath);
    });

    test('rejects a function that requires arguments, or is no function', () {
      final issues = _structureIssues(
        [_stepOf(_step('ask', showIf: _unasked))],
        files: [
          const DartFileIndex(
            path: _permissionPath,
            declarations: [
              IndexedDeclaration(
                name: 'askPermission',
                kind: DeclarationKind.function,
                type: 'Future<void>',
                parameters: [
                  IndexedParameter('again', kind: ParameterKind.requiredNamed),
                ],
              ),
              IndexedDeclaration(
                name: 'permissionUnasked',
                kind: DeclarationKind.variable,
                type: 'bool',
              ),
            ],
          ),
        ],
        owners: {_permissionPath: _permissions},
      );

      final messages = [for (final issue in issues) issue.message];
      expect(messages, hasLength(2));
      expect(
        messages.first,
        'function askPermission() in $_permissionPath must not require the '
        'parameter again.',
      );
      expect(
        messages.last,
        'function permissionUnasked() in $_permissionPath must be a function, '
        'not a variable.',
      );
      expect(issues.first.hint, contains('calls run without arguments'));
    });

    test('rejects a function in a file of another contributor', () {
      final issues = _structureIssues(
        [
          _stepOf(_step('ask', run: _showTips)),
          _stepOfRole(_step('alert'), _alertsRole),
        ],
        files: [
          _functionsFile(_tipsPath, {'showTips': 'Future<bool>'}),
          _functionsFile(_permissionPath, {'askPermission': 'Future<void>'}),
        ],
        owners: {
          _tipsPath: const ModuleOrigin(ModuleId('tips')),
          _permissionPath: _permissions,
        },
      );

      final messages = [for (final issue in issues) issue.message];
      expect(messages, hasLength(2));
      expect(
        messages.first,
        'The function showTips of the onboarding step "ask" of permissions is '
        'in $_tipsPath, a file of tips; a step calls functions of its own '
        'contributor.',
      );
      expect(
        messages.last,
        'The function askPermission of the onboarding step "alert" of '
        'role:alerts is in $_permissionPath, a file of permissions; a step '
        'calls functions of its own contributor.',
      );
      expect(issues.first.origin, _permissions);
      expect(issues.first.path, _tipsPath);
    });

    test(
        'accepts the files of a variant of the contributor and of the '
        'template that gives a step', () {
      expect(
        messagesOf(
          [
            _stepOf(_step('ask')),
            _stepOfRole(_step('tips', run: _showTips), _alertsRole),
          ],
          [
            _functionsFile(_permissionPath, {'askPermission': 'Future<void>'}),
            _functionsFile(_tipsPath, {'showTips': 'Future<bool>'}),
          ],
          owners: {
            _permissionPath: const ModuleOrigin(
              ModuleId('permissions'),
              variant: ModuleId('bloc'),
            ),
            _tipsPath: RoleTemplateOrigin(_alertsRole),
          },
        ),
        isEmpty,
      );
    });

    test(
        'leaves a function outside the app to the module rule and to the '
        'template of the role', () {
      expect(
        messagesOf(
          [
            _stepOf(
              _step(
                'ask',
                run: const FunctionRef(
                  'openAppSettings',
                  import: ImportRef('package:app_settings/app_settings.dart'),
                ),
              ),
            ),
          ],
          [],
        ),
        isEmpty,
      );
    });
  });

  group('the structural rule onboarding_screen.steps_shown', () {
    /// The file of the screen of the provider at [_welcomePath], which
    /// imports the file of the steps as [import] and reads [read] there,
    /// as itself or through a prefix.
    DartFileIndex screen({
      IndexedImport? import,
      List<IndexedReference> references = const [],
      List<IndexedMemberAccess> memberAccesses = const [],
    }) =>
        DartFileIndex(
          path: _welcomePath,
          imports: [if (import != null) import],
          references: references,
          memberAccesses: memberAccesses,
        );

    const stepsUri = 'package:my_app/core/onboarding/onboarding_steps.dart';

    /// The messages of the issues of the rule for an app with [data], whose
    /// provider generated [file], next to the file of the steps of the
    /// template.
    List<SmfIssue> issuesOf(
      List<RoleData<Object>> data,
      DartFileIndex file, {
      List<ModuleDescriptor> modules = const [_provider],
    }) =>
        _structureIssues(
          data,
          files: [
            file,
            const DartFileIndex(path: OnboardingScreenRole.stepsFile),
            _functionsFile(_permissionPath, {'askPermission': 'Future<void>'}),
          ],
          owners: {
            file.path: _welcome,
            OnboardingScreenRole.stepsFile:
                const RoleTemplateOrigin(onboardingScreenRole),
            _permissionPath: _permissions,
          },
          modules: modules,
        );

    final withStep = [
      _routes,
      _screenRoute('onboarding'),
      _stepOf(_step('ask')),
    ];

    test('accepts a provider whose files read the list of the steps', () {
      expect(
        issuesOf(
          withStep,
          screen(
            import: const IndexedImport(stepsUri),
            references: const [IndexedReference('appOnboardingSteps')],
          ),
        ),
        isEmpty,
      );
      expect(
        issuesOf(
          withStep,
          screen(
            import: const IndexedImport(stepsUri, prefix: 'steps'),
            memberAccesses: const [
              IndexedMemberAccess('steps', 'appOnboardingSteps'),
            ],
          ),
        ),
        isEmpty,
      );
    });

    test('reports a provider that does not read the list', () {
      for (final file in [
        screen(),
        // A list of the same name of another file is not the list of the
        // steps.
        screen(
          import: const IndexedImport('package:my_app/core/other.dart'),
          references: const [IndexedReference('appOnboardingSteps')],
        ),
      ]) {
        final issue = issuesOf(withStep, file).single;

        expect(
          issue.message,
          'The provider of the onboarding screen role does not show the steps '
          'of the onboarding: none of its files reads appOnboardingSteps of '
          'lib/core/onboarding/onboarding_steps.dart.',
        );
        expect(issue.hint, contains('on a page of its own'));
        expect(issue.origin, _welcome);
        expect(issue.path, _welcomePath);
      }
      // Without the route of the screen, the issue names no file.
      expect(
        issuesOf([_stepOf(_step('ask'))], screen()).single.path,
        isNull,
      );
    });

    test('asks nothing of an app without steps, or without a provider', () {
      expect(
        issuesOf([_routes, _screenRoute('onboarding')], screen()),
        isEmpty,
      );
      expect(issuesOf(withStep, screen(), modules: const []), isEmpty);
    });

    test('counts only the files of the provider', () {
      final issues = _structureIssues(
        withStep,
        files: [
          screen(),
          const DartFileIndex(
            path: 'lib/features/tips/tips_screen.dart',
            imports: [IndexedImport(stepsUri)],
            references: [IndexedReference('appOnboardingSteps')],
          ),
          _functionsFile(_permissionPath, {'askPermission': 'Future<void>'}),
        ],
        owners: {
          _welcomePath: _welcome,
          'lib/features/tips/tips_screen.dart':
              const ModuleOrigin(ModuleId('tips')),
          _permissionPath: _permissions,
        },
        modules: const [_provider],
      );

      expect(issues.single.message, contains('does not show the steps'));
    });
  });

  group('the note of the onboarding screen role for coding agents', () {
    test(
        'is a note of the role, which names the list and the class of the '
        'steps, and nothing of a provider', () async {
      final rendered = await renderTemplate(
        onboardingScreenRole,
        data: [_stepOf(_step('ask'))],
        present: {routerRole},
      );
      final note = agentNoteOf(onboardingScreenRole);

      expect(rendered.notes.single.socket, AppEntryRole.agentSections);
      expect(rendered.notes.single.entryKey, 'Onboarding screen');
      expect(rendered.notes.single.entryValue, note);
      expect(note.isOfRole, isTrue);
      expectNamesOfCode(
        note,
        {
          OnboardingScreenRole.stepsFile: [
            OnboardingScreenRole.appOnboardingSteps,
            for (final field in OnboardingScreenRole.step.getters)
              '${OnboardingScreenRole.step.name}.$field',
          ],
        },
        files: rendered.files,
      );
      // Every name of code in the note, so that it cannot name more: the
      // file of the steps, which every app with the role has, and no file
      // or class of the screen, which is of its provider.
      expect(codeSpansOf(note.text).toSet(), {
        OnboardingScreenRole.stepsFile,
        OnboardingScreenRole.appOnboardingSteps,
        OnboardingScreenRole.step.name,
        ...OnboardingScreenRole.step.getters,
        'const',
        'BuildContext',
        'Future',
        'bool',
        'false',
        'step.title(context)',
        'build',
      });
    });

    test(
        'tells that skipping the onboarding skips its steps, so that the '
        'app does not rely on an action alone', () {
      final text = agentNoteOf(onboardingScreenRole).text;

      expect(text, contains('Skipping the onboarding skips its steps.'));
      expect(text, contains('top-level functions'));
    });
  });
}
