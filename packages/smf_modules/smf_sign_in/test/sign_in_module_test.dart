@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_riverpod/smf_riverpod.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:smf_sign_in/bundles/sign_in_bloc_bundle.dart';
import 'package:smf_sign_in/bundles/sign_in_bundle.dart';
import 'package:smf_sign_in/bundles/sign_in_riverpod_bundle.dart';
import 'package:smf_sign_in/smf_sign_in.dart';
import 'package:smf_sign_in/src/agents.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/providers.dart';
import 'support/state_scripts.dart';

/// A feature of the tests whose screen can start the app.
const _feed = StartFeature('feed');

/// The modules of the tests: flutter_core, which creates the app,
/// go_router, which routes it and asks the guards of the module, the two
/// modules that manage state, sign-in with accounts in memory, gen_l10n,
/// which provides the localization role, with the preferences that it
/// requires, a feature that can start the app, and this module.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  BlocModule(),
  RiverpodModule(),
  MemoryAuthModule(),
  SharedPreferencesModule(),
  GenL10nModule(),
  _feed,
  SignInModule(),
];

/// The directory of the files of the module in the app.
const _folder = 'lib/features/sign_in';

/// The files of the look of the screens, which every app with the module
/// has: the three views, the frame of a screen, the fields and the buttons,
/// the values of the state, and the functions of the guards.
const _views = [
  '$_folder/sign_in_view.dart',
  '$_folder/sign_up_view.dart',
  '$_folder/reset_password_view.dart',
];
const _page = '$_folder/sign_in_page.dart';
const _widgets = '$_folder/sign_in_widgets.dart';
const _state = '$_folder/sign_in_state.dart';
const _guards = '$_folder/sign_in_guards.dart';
const List<String> _look = [..._views, _page, _widgets, _state, _guards];

/// The files of the screens, which each variant has at the same paths.
const _screens = {
  'SignInScreen': '$_folder/sign_in_screen.dart',
  'SignUpScreen': '$_folder/sign_up_screen.dart',
  'ResetPasswordScreen': '$_folder/reset_password_screen.dart',
};

/// The files of the state of the screens in the variant for bloc: the
/// file that creates the cubits, and the cubits.
const _composition = '$_folder/sign_in_composition.dart';
const _cubits = [
  '$_folder/sign_in_cubit.dart',
  '$_folder/sign_up_cubit.dart',
  '$_folder/reset_password_cubit.dart',
];

/// The files of the state of the screens in the variant for riverpod: the
/// provider of the session, and the providers of the screens.
const _sessionProvider = '$_folder/session_provider.dart';
const _notifiers = [
  '$_folder/sign_in_notifier.dart',
  '$_folder/sign_up_notifier.dart',
  '$_folder/reset_password_notifier.dart',
];

/// The variants of the module, each with the id of its state manager, the
/// package that it imports, and the files of its state.
const List<({ModuleId id, String package, List<String> stateFiles})> _variants =
    [
  (
    id: SignInModule.blocVariant,
    package: 'flutter_bloc',
    stateFiles: [_composition, ..._cubits],
  ),
  (
    id: SignInModule.riverpodVariant,
    package: 'flutter_riverpod',
    stateFiles: [_sessionProvider, ..._notifiers],
  ),
];

/// The owner of the files of the module.
const _module = ModuleOrigin(SignInModule.id);

/// The names of the texts of the module, in their order: those of the
/// sign-in, of the sign-up and of the password reset, what a form says of
/// a field, and the texts of the failures.
const _textNames = [
  'title',
  'intro',
  'email',
  'password',
  'showPassword',
  'hidePassword',
  'submit',
  'forgotPassword',
  'createAccount',
  'signUpTitle',
  'signUpIntro',
  'signUpSubmit',
  'haveAccount',
  'resetTitle',
  'resetIntro',
  'sendLink',
  'resetSentTitle',
  'resetSent',
  'backToSignIn',
  'emailRequired',
  'emailInvalid',
  'passwordRequired',
  'failureCredentials',
  'failureEmailInUse',
  'failureWeakPassword',
  'failureDisabled',
  'failureTooManyAttempts',
  'failureNoNetwork',
  'failureRecentSignIn',
  'failureNotSetUp',
  'failureUnknown',
];

/// The text of the module for each reason of a failure of the auth role,
/// by the name of the reason.
const _failureTexts = {
  'invalidCredentials': 'failureCredentials',
  'emailInUse': 'failureEmailInUse',
  'weakPassword': 'failureWeakPassword',
  // What the form says of an address without an @ too.
  'invalidEmail': 'emailInvalid',
  'userDisabled': 'failureDisabled',
  'tooManyAttempts': 'failureTooManyAttempts',
  'network': 'failureNoNetwork',
  'recentSignInRequired': 'failureRecentSignIn',
  'notConfigured': 'failureNotSetUp',
  'unknown': 'failureUnknown',
};

/// The name of the case of the harness for the app of the module with the
/// state manager [variant], with the localization role or without it.
String _caseOf(ModuleId variant, {bool localized = true}) =>
    'sign_in ($variant)${localized ? ' with localization' : ''}';

/// The annotation that [_Annotating] gives the classes of the screens.
const String _annotation = "@Deprecated('An annotation of the tests')";

/// A module that annotates the classes of the screens of the module through
/// the router role, as a router whose screens need annotations would.
final class _Annotating extends SmfModule {
  const _Annotating();

  static const id = ModuleId('annotating');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Annotates the screens of the sign-in (test)',
        kind: ModuleKinds.infrastructure,
        uses: {routerRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        for (final screen in _screens.keys)
          SocketContribution.code(
            RouterRole.screenAnnotations(
              (feature: SignInModule.id, screen: screen),
            ),
            const Fragment(_annotation),
            when: const {routerRole},
          ),
      ];
}

/// What the contract harness finds for [contractCase] among [registry], in
/// [context], which has no errors and is rendered.
Future<ContractResult> _checked(
  ContractCase contractCase, {
  List<SmfModule> registry = _modules,
  ModuleContext context = ContractHarness.defaultContext,
}) async {
  final result = await ContractHarness(
    ModuleRegistry(registry),
    context: context,
  ).check(contractCase);
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $contractCase has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The app of the module with the state manager [variant], with the modules
/// [others] too, and with the values [roleOptions] of the options of the
/// roles.
Future<ContractResult> _rendered(
  ModuleId variant, {
  List<ModuleId> others = const [GenL10nModule.id],
  Map<String, String?> roleOptions = const {},
  List<SmfModule> registry = _modules,
  ModuleContext context = ContractHarness.defaultContext,
}) =>
    _checked(
      ContractCase(
        'sign_in with $variant, ${others.join(', ')}',
        requested: [SignInModule.id, ...others],
        picks: {stateManagementRole: variant},
        roleOptions: roleOptions,
      ),
      registry: registry,
      context: context,
    );

/// The parsed file [path] of [app].
CompilationUnit _parsed(RenderedApp app, String path) =>
    parseString(content: app.files[path]!.text).unit;

/// The class [name] of [unit].
ClassDeclaration _classOf(CompilationUnit unit, String name) => unit
    .declarations
    .whereType<ClassDeclaration>()
    .singleWhere((declaration) => declaration.namePart.typeName.lexeme == name);

/// The top-level function [name] of [unit].
FunctionDeclaration _functionOf(CompilationUnit unit, String name) =>
    unit.declarations
        .whereType<FunctionDeclaration>()
        .singleWhere((declaration) => declaration.name.lexeme == name);

/// The code of the value of the top-level constant [name] of [unit].
String _constantOf(CompilationUnit unit, String name) => unit.declarations
    .whereType<TopLevelVariableDeclaration>()
    .expand((declaration) => declaration.variables.variables)
    .singleWhere((variable) => variable.name.lexeme == name)
    .initializer!
    .toSource();

/// The URIs of the imports of [unit].
List<String> _importsOf(CompilationUnit unit) => [
      for (final directive in unit.directives.whereType<ImportDirective>())
        directive.uri.stringValue!,
    ];

/// The values of the string literals in the declarations of [unit], in
/// the order of the code.
List<String> _stringsIn(CompilationUnit unit) {
  final visitor = _Strings();
  for (final declaration in unit.declarations) {
    declaration.accept(visitor);
  }
  return visitor.values;
}

final class _Strings extends RecursiveAstVisitor<void> {
  final List<String> values = [];

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) =>
      values.add(node.value);
}

/// The getters of the texts of the app that [node] reads, as
/// `context.l10n.<getter>`, in the order of the code.
List<String> _textsReadIn(AstNode node) {
  final visitor = _TextReads();
  node.accept(visitor);
  return visitor.getters;
}

final class _TextReads extends RecursiveAstVisitor<void> {
  final List<String> getters = [];

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.target?.toSource() == 'context.l10n') {
      getters.add(node.propertyName.name);
    }
    super.visitPropertyAccess(node);
  }
}

/// The identifiers of [unit] outside its directives, as written, and the
/// names of the variables, the functions and the classes that it declares.
Set<String> _identifiersIn(CompilationUnit unit) {
  final visitor = _Identifiers();
  for (final declaration in unit.declarations) {
    declaration.accept(visitor);
  }
  return visitor.names;
}

final class _Identifiers extends RecursiveAstVisitor<void> {
  final Set<String> names = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) => names.add(node.name);

  // What a file declares has its name as a token, not as an identifier.
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    names.add(node.name.lexeme);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    names.add(node.name.lexeme);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    names.add(node.namePart.typeName.lexeme);
    super.visitClassDeclaration(node);
  }

  @override
  void visitNamedType(NamedType node) {
    names.add(node.name.lexeme);
    super.visitNamedType(node);
  }
}

/// The calls in [node] that create a `type`, or call a function or a
/// constructor of that name, such as `InputDecoration(...)` and
/// `Card.outlined(...)`, each with its arguments by their names; an
/// argument without a name has the name of its place, such as `0`.
List<Map<String, String>> _callsOf(AstNode node, String type) {
  final visitor = _Calls(type);
  node.accept(visitor);
  return visitor.found;
}

final class _Calls extends RecursiveAstVisitor<void> {
  _Calls(this.type);

  final String type;
  final List<Map<String, String>> found = [];

  void _add(ArgumentList arguments) {
    var place = 0;
    found.add({
      for (final argument in arguments.arguments)
        if (argument is NamedArgument)
          argument.name.lexeme: argument.argumentExpression.toSource()
        else
          '${place++}': argument.toSource(),
    });
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName.toSource();
    if (name == type || name.startsWith('$type.')) _add(node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Without resolution, the parser reads `Card.outlined(...)` and
    // `Text(...)` as the invocation of a method or of a function.
    final target = node.target?.toSource();
    if ((target == null && node.methodName.name == type) || target == type) {
      _add(node.argumentList);
    }
    super.visitMethodInvocation(node);
  }
}

/// The reasons of a failure of the auth role in [app], as the role's file
/// declares them, in their order.
List<String> _reasonsOf(RenderedApp app) => [
      for (final constant in _parsed(app, AuthRole.serviceFile)
          .declarations
          .whereType<EnumDeclaration>()
          .singleWhere(
            (declaration) =>
                declaration.namePart.typeName.lexeme == 'AuthFailureReason',
          )
          .body
          .constants)
        constant.name.lexeme,
    ];

/// The code that `authFailureText()` of [app] returns for each reason of a
/// failure, by the name of the reason.
Map<String, String> _failureCodeOf(RenderedApp app) {
  final function = _functionOf(_parsed(app, _widgets), 'authFailureText');
  final body = function.functionExpression.body as ExpressionFunctionBody;
  final cases = (body.expression as SwitchExpression).cases;
  return {
    for (final switchCase in cases)
      switchCase.guardedPattern.pattern.toSource().split('.').last:
          switchCase.expression.toSource(),
  };
}

/// The texts of the app of [result], as the localization role gives them
/// to every provider, each by the getter that reads it.
Map<String, LocalizedText> _appTextsOf(ContractResult result) => {
      for (final text in localizationRole.textsIn(
        localizationRole.hookInput(result.hook!),
      ))
        if (text.owner == _module) text.getter: text.text,
    };

/// The getter of the text [name] of the module in an app with the
/// localization role.
String _getterOf(String name) =>
    'signIn${name[0].toUpperCase()}${name.substring(1)}';

/// The text [name] of the module.
LocalizedText _textOf(String name) =>
    SignInModule.texts.texts.singleWhere((text) => text.name == name);

/// The routes and the guards of the app of [result], as the router role
/// gives them to every router.
RouterFacade _facadeOf(ContractResult result) =>
    routerRole.facadeOf(routerRole.hookInput(result.hook!));

/// The modules that provide [role] in the app of [result], whichever they
/// are.
Set<ModuleId> _providersOf(ContractResult result, Role role) => {
      for (final module in result.resolution!.providersOf(role)) module.id,
    };

/// The index of the Dart file at [path] of [app].
DartFileIndex _indexOf(RenderedApp app, String path) =>
    DartFileIndexer.index(path, app.files[path]!.text);

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

/// Whether [origin] is the module, or its variant for a state manager.
bool _isOwn(ContributionOrigin? origin) =>
    origin is ModuleOrigin && origin.module == SignInModule.id;

/// The paths of the files of [app] that the module owns, those of its
/// variant included.
List<String> _ownFilesOf(RenderedApp app) => [
      for (final file in app.files.values)
        if (_isOwn(file.owner)) file.path,
    ];

/// What opens the state of each screen in the script of a variant, over
/// the cubits of the variant for bloc: a cubit is created with the session,
/// tells of its states on its stream, and is closed when the user leaves
/// the screen.
const _blocScreens = '''
Screen signInScreen(AppSessionController session) {
  final cubit = SignInCubit(session);
  final states = <String>[];
  cubit.stream.listen((state) => states.add(show(state)));
  return Screen(
    state: () => show(cubit.state),
    states: states,
    submit: () => cubit.signIn(email: email, password: password),
    leave: cubit.close,
  );
}

Screen signUpScreen(AppSessionController session) {
  final cubit = SignUpCubit(session);
  final states = <String>[];
  cubit.stream.listen((state) => states.add(show(state)));
  return Screen(
    state: () => show(cubit.state),
    states: states,
    submit: () => cubit.signUp(email: email, password: password),
    leave: cubit.close,
  );
}

Screen resetScreen(AppSessionController session) {
  final cubit = ResetPasswordCubit(session);
  final states = <String>[];
  cubit.stream.listen((state) => states.add(show(state)));
  return Screen(
    state: () => show(cubit.state),
    states: states,
    submit: () => cubit.send(email),
    leave: cubit.close,
  );
}
''';

/// The same over the providers of the variant for riverpod: a container
/// has the session in place of that of the app, a screen watches its
/// provider, and stops when the user leaves it, which disposes of the
/// provider.
const _riverpodScreens = '''
Screen _screenOf<T>(
  AppSessionController session,
  ProviderListenable<T> provider,
  Future<void> Function(ProviderContainer container) submit,
) {
  final container = ProviderContainer(
    overrides: [appSessionProvider.overrideWithValue(session)],
  );
  final states = <String>[];
  final watching = container.listen<T>(
    provider,
    (_, state) => states.add(show(state)),
  );
  return Screen(
    state: () => show(container.read(provider)),
    states: states,
    submit: () => submit(container),
    leave: () async {
      watching.close();
      await container.pump();
    },
  );
}

Screen signInScreen(AppSessionController session) => _screenOf(
  session,
  signInProvider,
  (container) => container
      .read(signInProvider.notifier)
      .signIn(email: email, password: password),
);

Screen signUpScreen(AppSessionController session) => _screenOf(
  session,
  signUpProvider,
  (container) => container
      .read(signUpProvider.notifier)
      .signUp(email: email, password: password),
);

Screen resetScreen(AppSessionController session) => _screenOf(
  session,
  resetPasswordProvider,
  (container) => container.read(resetPasswordProvider.notifier).send(email),
);
''';

/// What the script of every variant does: the scenarios of each screen,
/// and the sign-up of an anonymous user.
const _scenarios = '''
  result['sign-in'] = await scenariosOf(signInScreen);
  result['sign-up'] = await scenariosOf(signUpScreen);
  result['reset'] = await scenariosOf(resetScreen);

  // An anonymous user signs up, in an app that signs such a user in.
  {
    final service = Scripted();
    final session = await sessionOf(service, mode: AuthMode.anonymous);
    final screen = signUpScreen(session);
    result['anonymous: before'] = show(session.value);
    await screen.submit();
    await turn();
    result['anonymous: calls'] = [...service.calls];
    result['anonymous: session'] = show(session.value);
    session.dispose();
  }
''';

/// What the script of each variant does last: the state of a screen in the
/// app, as the app creates it, has the session of the app.
const _blocApp = r'''
  {
    final service = Scripted();
    await appSession.start(service);
    final cubit = createSignInCubit();
    await cubit.signIn(email: email, password: password);
    result['app: created'] = [
      '${createSignUpCubit().runtimeType}',
      '${createResetPasswordCubit().runtimeType}',
    ];
    result['app: calls'] = [...service.calls];
    result['app: session'] = show(appSession.value);
  }
''';

const _riverpodApp = '''
  {
    final service = Scripted();
    await appSession.start(service);
    final container = ProviderContainer();
    result['app: provider'] =
        identical(container.read(appSessionProvider), appSession);
    container.listen(signInProvider, (_, _) {});
    await container
        .read(signInProvider.notifier)
        .signIn(email: email, password: password);
    result['app: calls'] = [...service.calls];
    result['app: session'] = show(appSession.value);
  }
''';

/// The package of the files of the app in a script.
String _import(String path) =>
    'package:contract_app/${path.substring('lib/'.length)}';

void main() {
  const module = SignInModule();

  group('SignInModule', () {
    test(
        'is a feature that requires the router, sign-in and a state '
        'manager, uses the localization, and needs neither a DI container '
        'nor a settings screen', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('sign_in'));
      expect(descriptor.kind, ModuleKinds.feature);
      expect(descriptor.provides, isEmpty);
      expect(descriptor.requires, {authRole});
      // The kind makes a feature require the router, and the variants the
      // state management.
      expect(
        descriptor.effectiveRequires,
        {authRole, routerRole, stateManagementRole},
      );
      expect(descriptor.effectiveUses, {localizationRole});
      expect(descriptor.dependsOn, isEmpty);
    });

    test(
        'has a variant for bloc and one for riverpod, by the ids of the '
        'modules that provide the state management', () {
      final variants = module.descriptor.variants!;

      expect(variants.role, stateManagementRole);
      expect(variants.byProvider.keys, [BlocModule.id, RiverpodModule.id]);
      expect(SignInModule.blocVariant, BlocModule.id);
      expect(SignInModule.riverpodVariant, RiverpodModule.id);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'declares the sign-in at / of the module, with the sign-up and the '
        'password reset below it, none of them a destination, a screen '
        'that starts the app or a route with a condition', () {
      final data = [
        for (final contribution
            in module.contribute(ContractHarness.defaultContext))
          if (contribution is RoleData<RoutesData>) contribution,
      ].single;

      expect(data.role, routerRole);
      final signIn = data.value.routes.single;
      expect(signIn.path, '/');
      expect(signIn.name, 'signIn');
      expect(
        [
          for (final route in signIn.children) (route.path, route.name),
        ],
        [('sign_up', 'signUp'), ('reset_password', 'resetPassword')],
      );
      final routes = [signIn, ...signIn.children];
      expect(
        {
          for (final route in routes) route.screen.className: route.screen.file,
        },
        _screens,
      );
      for (final route in routes) {
        expect(route.params, isEmpty, reason: route.name);
        expect(route.destination, isNull, reason: route.name);
        expect(route.startCandidate, isFalse, reason: route.name);
        expect(route.conditions, isEmpty, reason: route.name);
      }
      expect(signIn.children.expand((route) => route.children), isEmpty);
    });

    test(
        'declares a gate and a guard for the account condition of the auth '
        'role, which both show the sign-in, come after the guards of a '
        'first launch, and do not bring the next user back', () {
      final data = [
        for (final contribution
            in module.contribute(ContractHarness.defaultContext))
          if (contribution is RoleData<RoutesData>) contribution,
      ].single;

      final [gate, account] = data.value.guards;
      expect(gate.name, SignInModule.gate);
      expect(gate.name, 'gate');
      expect(gate.condition, isNull);
      expect(gate.allows.name, 'signInAllowsApp');
      expect(account.name, SignInModule.accountGuard);
      expect(account.name, 'account');
      expect(account.condition, AuthRole.account);
      expect(account.allows.name, 'signInHasAccount');
      for (final guard in [gate, account]) {
        expect(guard.redirectTo, data.value.routes.single.name);
        expect(
          guard.allows.import,
          const ImportRef.app('features/sign_in/sign_in_guards.dart'),
        );
        // The onboarding of an app comes first, whatever the order of the
        // modules, and after a sign-out the next user starts on the screen
        // that the app starts on.
        expect(guard.stage, GuardStage.identity, reason: guard.name);
        expect(guard.resumes, isFalse, reason: guard.name);
      }
    });

    test(
        'has each of its texts in English and in Ukrainian, without '
        'parameters', () {
      expect(
        [for (final text in SignInModule.texts.texts) text.name],
        _textNames,
      );
      for (final text in SignInModule.texts.texts) {
        expect(text.problems(), isEmpty, reason: '$text');
        expect(text.languages, ['en', 'uk'], reason: '$text');
        expect(text.textIn('uk'), isNot(text.en), reason: '$text');
      }
    });

    test(
        'contributes the brick of the look with the symbol and the number '
        'of the app and the texts, its routes with the guards, its texts '
        'and its note for coding agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(4));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(signInBundle));
      expect(brick.bundle.name, 'sign_in');
      expect(
        [for (final file in brick.bundle.files) file.path]..sort(),
        [..._look]..sort(),
      );
      expect(brick.when, isEmpty);
      expect(brick.vars.keys, [
        'app_symbol',
        'app_number',
        for (final name in _textNames) 'text_${SmfNames.snakeCaseOf(name)}',
      ]);
      // The symbol and the number of the app of the context, contract_app.
      expect(brick.vars['app_symbol'], "'Ca'");
      expect(brick.vars['app_number'], 11);
      // Each text is a text of the app with the localization role, and its
      // English text without it.
      expect(
        [
          for (final variable in brick.vars.values.whereType<RoleVar>())
            (
              variable.role,
              (variable.present as Fragment).code,
              variable.absent,
            ),
        ],
        [
          for (final text in SignInModule.texts.texts)
            (
              localizationRole,
              'context.l10n.${_getterOf(text.name)}',
              SmfNames.dartString(text.en),
            ),
        ],
      );
      expect(contributions[1], isA<RoleData<RoutesData>>());
      final texts = contributions[2] as RoleData<TextsData>;
      expect(texts.role, localizationRole);
      expect(texts.value, same(SignInModule.texts));
      final note = contributions[3] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, agentHeading);
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
    });

    test(
        'adds with each variant the brick of its state, the package of its '
        'state manager with the constraint of the provider, and its part '
        'of the note, and nothing else', () {
      final variants = module.descriptor.variants!.byProvider;
      final expected = {
        SignInModule.blocVariant: (
          bundle: signInBlocBundle,
          name: 'sign_in_bloc',
          files: [_composition, ..._cubits, ..._screens.values],
          package: 'flutter_bloc',
          note: blocAgentNote,
        ),
        SignInModule.riverpodVariant: (
          bundle: signInRiverpodBundle,
          name: 'sign_in_riverpod',
          files: [_sessionProvider, ..._notifiers, ..._screens.values],
          package: 'flutter_riverpod',
          note: riverpodAgentNote,
        ),
      };

      expect(variants.keys, expected.keys);
      for (final MapEntry(key: id, value: variant) in expected.entries) {
        final contributions = variants[id]!(ContractHarness.defaultContext);

        expect(contributions, hasLength(3), reason: '$id');
        final brick = contributions[0] as BrickContribution;
        expect(brick.bundle, same(variant.bundle), reason: '$id');
        expect(brick.bundle.name, variant.name);
        expect(
          [for (final file in brick.bundle.files) file.path]..sort(),
          [...variant.files]..sort(),
          reason: '$id',
        );
        expect(brick.vars, isEmpty, reason: '$id');
        expect(brick.when, isEmpty, reason: '$id');
        final package = contributions[1] as PubspecDependency;
        expect(package.package, variant.package, reason: '$id');
        // The version is that of the module that provides the role.
        expect(package.constraint, 'any', reason: '$id');
        expect(package.source, PubspecSource.hosted);
        expect(package.dev, isFalse);
        final note = contributions[2] as SocketContribution;
        expect(note.socket, AppEntryRole.agentSections);
        expect(note.entryKey, agentHeading);
        expect(note.entryValue, AgentNote(variant.note), reason: '$id');
      }
    });
  });

  group('the contract harness', () {
    late ContractHarness harness;
    late List<ContractResult> results;

    setUpAll(() async {
      harness = ContractHarness(ModuleRegistry(_modules));
      results = await harness.checkAll();
    });

    test(
        'builds the app of the module with each state manager, with the '
        'localization and without, each with the router and the sign-in '
        'that it requires', () {
      final own = [
        for (final result in results)
          if (result.contractCase.name.startsWith('sign_in')) result,
      ];

      expect(own.map((result) => result.contractCase.name), [
        _caseOf(BlocModule.id),
        _caseOf(RiverpodModule.id),
        _caseOf(BlocModule.id, localized: false),
        _caseOf(RiverpodModule.id, localized: false),
      ]);
      for (final result in own) {
        final name = result.contractCase.name;
        expect(
          [
            for (final role in <Role>[routerRole, authRole])
              _providersOf(result, role),
          ],
          [
            {GoRouterModule.id},
            {MemoryAuthModule.id},
          ],
          reason: name,
        );
        expect(
          _providersOf(result, stateManagementRole),
          {if (name.contains('bloc')) BlocModule.id else RiverpodModule.id},
          reason: name,
        );
        expect(
          _providersOf(result, localizationRole),
          name.contains('localization') ? {GenL10nModule.id} : isEmpty,
          reason: name,
        );
        // The module asks for no DI container and no settings screen.
        expect(result.hook!.presentRoles, isNot(contains(diRole)));
        expect(
          result.hook!.presentRoles,
          isNot(contains(settingsScreenRole)),
        );
      }
    });

    test('finds no errors in any app, rendered code included', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });

    test(
        'finds no warning in an app of the module, such as that of a route '
        'that asks for an account without a guard', () {
      for (final result in results) {
        if (!result.contractCase.name.startsWith('sign_in')) continue;
        expect(
          result.issues.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
      }
    });

    test(
        'checks each module with the provider of each role it requires or '
        'uses', () async {
      expect(await harness.uncheckedProviders(), isEmpty);
    });

    test(
        'finds no errors in the apps of the module in the other modes of '
        'the auth role, where the module generates the same files', () async {
      for (final contractCase in harness.casesOfModule(SignInModule.id)) {
        final byDefault = (await harness.check(contractCase)).app!;
        for (final mode in AuthRole.modeOption.allowed!.skip(1)) {
          final name = '${contractCase.name} --auth-mode=$mode';
          final result = await harness.check(
            ContractCase(
              name,
              requested: contractCase.requested,
              picks: contractCase.picks,
              roleOptions: {AuthRole.modeOption.name: mode},
            ),
          );

          expect(result.issues.map((issue) => '$issue'), isEmpty, reason: name);
          final app = result.app!;
          expect(
            authRole.modeIn(authRole.hookInput(result.hook!)).name,
            mode,
            reason: name,
          );
          // The module is no provider of the role, so its code is the same
          // in every mode, and reads the mode when the app runs.
          expect(_ownFilesOf(app), _ownFilesOf(byDefault), reason: name);
          for (final path in _ownFilesOf(app)) {
            expect(
              app.files[path]!.text,
              byDefault.files[path]!.text,
              reason: '$name: $path',
            );
          }
        }
      }
    });
  });

  group('the app with the sign-in', () {
    late Map<ModuleId, ContractResult> localized;
    late Map<ModuleId, ContractResult> english;

    setUpAll(() async {
      localized = {
        for (final variant in _variants)
          variant.id: await _rendered(variant.id),
      };
      english = {
        for (final variant in _variants)
          variant.id: await _rendered(variant.id, others: const []),
      };
    });

    test(
        'has the files of the look and of the guards, the same with each '
        'state manager, and the screens of each variant at the same paths', () {
      for (final apps in [localized, english]) {
        final [bloc, riverpod] = [
          for (final variant in _variants) apps[variant.id]!.app!,
        ];

        expect(
          _ownFilesOf(bloc),
          [..._look, _composition, ..._cubits, ..._screens.values]..sort(),
        );
        expect(
          _ownFilesOf(riverpod),
          [..._look, _sessionProvider, ..._notifiers, ..._screens.values]
            ..sort(),
        );
        for (final path in _look) {
          expect(
            bloc.files[path]!.text,
            riverpod.files[path]!.text,
            reason: path,
          );
        }
        for (final app in [bloc, riverpod]) {
          for (final MapEntry(key: screen, value: path) in _screens.entries) {
            // A widget with a constructor that takes no values, as a
            // route without parameters needs.
            final constructor = _classOf(_parsed(app, path), screen)
                .body
                .members
                .whereType<ConstructorDeclaration>()
                .single;
            expect(constructor.constKeyword, isNotNull, reason: path);
            expect(
              constructor.parameters.parameters
                  .map((parameter) => '$parameter'),
              ['super.key'],
              reason: path,
            );
          }
        }
      }
    });

    test(
        'keeps the look free of the state managers, and the state and the '
        'screens of a variant free of the widgets of the look', () {
      for (final variant in _variants) {
        final app = localized[variant.id]!.app!;

        for (final path in _look) {
          expect(
            _importsOf(_parsed(app, path)).where(
              (uri) => uri.contains('bloc') || uri.contains('riverpod'),
            ),
            isEmpty,
            reason: path,
          );
        }
        // A screen builds its view and nothing else, and what keeps its
        // state draws nothing.
        for (final path in [...variant.stateFiles, ..._screens.values]) {
          final imports = _importsOf(_parsed(app, path));
          expect(
            imports.where(
              (uri) =>
                  uri.endsWith('material.dart') ||
                  uri.endsWith('cupertino.dart') ||
                  uri.endsWith('sign_in_page.dart') ||
                  uri.endsWith('sign_in_widgets.dart'),
            ),
            isEmpty,
            reason: path,
          );
        }
        for (final path in _screens.values) {
          expect(
            _importsOf(_parsed(app, path)),
            contains('package:${variant.package}/${variant.package}.dart'),
            reason: path,
          );
        }
        // Each screen builds the view of its name.
        for (final MapEntry(key: screen, value: path) in _screens.entries) {
          final view = screen.replaceFirst('Screen', 'View');
          expect(_identifiersIn(_parsed(app, path)), contains(view));
          expect(
            _importsOf(_parsed(app, path)),
            contains(path.split('/').last.replaceFirst('_screen', '_view')),
            reason: path,
          );
        }
      }
    });

    test(
        'names the session of the app in the file of the guards and in one '
        'file of the state of each variant, and the service of the '
        'provider nowhere', () {
      const naming = {
        SignInModule.blocVariant: _composition,
        SignInModule.riverpodVariant: _sessionProvider,
      };
      for (final variant in _variants) {
        final app = localized[variant.id]!.app!;

        expect(
          [
            for (final path in _ownFilesOf(app))
              if (_identifiersIn(_parsed(app, path)).contains('appSession'))
                path,
          ],
          unorderedEquals([_guards, naming[variant.id]]),
          reason: '${variant.id}',
        );
        for (final path in _ownFilesOf(app)) {
          final unit = _parsed(app, path);
          expect(
            _importsOf(unit).where((uri) => uri.endsWith('auth_service.dart')),
            isEmpty,
            reason: path,
          );
          expect(
            _identifiersIn(unit).intersection({
              'AuthService',
              'createAuthService',
              'initAuth',
              'authMode',
              'AuthMode',
              'linkPassword',
              'signInAnonymously',
            }),
            isEmpty,
            reason: path,
          );
        }
      }
    });

    test(
        'navigates only to the two screens over the sign-in, each on top '
        'of the stack, and back from them by closing their page', () {
      for (final variant in _variants) {
        final app = localized[variant.id]!.app!;
        final accesses = {
          for (final path in _ownFilesOf(app))
            path: [
              for (final access in _indexOf(app, path).memberAccesses)
                if (access.target.startsWith('context.nav'))
                  '${access.target}.${access.name}',
            ],
        }..removeWhere((path, accesses) => accesses.isEmpty);

        expect(accesses.keys, [_screens['SignInScreen']], reason: '$variant');
        final source = app.files[_screens['SignInScreen']]!.text;
        expect(
          RegExp(r'context\.nav\.signIn\.(\w+)\(\)\.(\w+)<void>\(\)')
              .allMatches(source)
              .map((match) => (match[1], match[2])),
          [('signUp', 'push'), ('resetPassword', 'push')],
          reason: '$variant',
        );
        for (final screen in ['SignUpScreen', 'ResetPasswordScreen']) {
          final unit = _parsed(app, _screens[screen]!);
          final pops = _Invocations('maybePop');
          unit.accept(pops);
          expect(
            pops.found.map((call) => call.toSource()),
            ['Navigator.of(context).maybePop()'],
            reason: screen,
          );
        }
        // No screen goes anywhere once the user is signed in.
        for (final path in _ownFilesOf(app)) {
          final unit = _parsed(app, path);
          for (final method in ['go', 'replace', 'pushReplacement']) {
            final calls = _Invocations(method);
            unit.accept(calls);
            expect(calls.found, isEmpty, reason: '$path: $method');
          }
        }
      }
    });

    test(
        'gives no field a colour, a border or a padding of its own: a '
        'field has only the button of the password and the lines of a '
        'mistake', () {
      final app = localized[SignInModule.blocVariant]!.app!;
      final decorations = [
        for (final path in _look)
          ..._callsOf(_parsed(app, path), 'InputDecoration'),
      ];

      expect(decorations.map((arguments) => arguments.keys.toList()), [
        ['errorMaxLines'],
        ['errorMaxLines', 'suffixIcon'],
      ]);
      expect(
        _callsOf(_parsed(app, _widgets), 'TextFormField'),
        hasLength(2),
      );
      final styling = {
        'OutlineInputBorder',
        'UnderlineInputBorder',
        'InputDecorationTheme',
        'fillColor',
        'filled',
        'contentPadding',
        'enabledBorder',
        'focusedBorder',
        'errorBorder',
        'suffixIconColor',
        'styleFrom',
        'ButtonStyle',
      };
      for (final path in _look) {
        expect(
          _identifiersIn(_parsed(app, path)).intersection(styling),
          isEmpty,
          reason: path,
        );
      }
    });

    test(
        'shows the address and a failure on cards of the theme, and names '
        'no colour of its own', () {
      final app = localized[SignInModule.blocVariant]!.app!;
      final widgets = _parsed(app, _widgets);

      expect(_callsOf(widgets, 'Card'), hasLength(2));
      for (final card in _callsOf(widgets, 'Card')) {
        expect(card.keys, isNot(contains('shape')));
        expect(card.keys, isNot(contains('elevation')));
      }
      for (final path in _look) {
        final unit = _parsed(app, path);
        // A colour is one of the theme, or made of one: no file has the
        // value of a colour, or a colour of Material by its name.
        expect(
          RegExp(r'\bColor(\.from\w+)?\(\s*\d').allMatches(unit.toSource()),
          isEmpty,
          reason: path,
        );
        expect(
          _identifiersIn(unit).intersection({'Colors', 'CupertinoColors'}),
          isEmpty,
          reason: path,
        );
      }
    });

    test(
        'animates the box of a failure only in an app that allows motion: '
        'an AnimatedSize with no duration fails an assertion of Flutter', () {
      final app = localized[SignInModule.blocVariant]!.app!;
      final build = _classOf(_parsed(app, _widgets), 'FailureMessage')
          .body
          .members
          .whereType<MethodDeclaration>()
          .singleWhere((method) => method.name.lexeme == 'build');
      final statements = (build.body as BlockFunctionBody).block.statements;

      final sized = _callsOf(build, 'AnimatedSize').single;
      expect(sized['duration'], 'Durations.short4');
      // The message alone, before the widget that animates it.
      final guard = statements[statements.length - 2];
      expect(
        guard.toSource(),
        'if (MediaQuery.disableAnimationsOf(context)) return message;',
      );
      expect(statements.last, isA<ReturnStatement>());
      for (final path in _look) {
        for (final sized in _callsOf(_parsed(app, path), 'AnimatedSize')) {
          expect(sized['duration'], isNot(contains('Duration.zero')));
        }
      }
    });

    test(
        'spins only while a call is on its way, which a widget test that '
        'waits for the screen to settle has to know', () {
      final app = localized[SignInModule.blocVariant]!.app!;
      final spinners = {
        for (final path in _ownFilesOf(app))
          path: _callsOf(_parsed(app, path), 'CircularProgressIndicator'),
      }..removeWhere((path, calls) => calls.isEmpty);

      // The one animation of the screens without an end.
      expect(spinners.keys, [_widgets]);
      expect(spinners[_widgets], hasLength(1));
      final button = _classOf(_parsed(app, _widgets), 'SubmitButton');
      expect(_callsOf(button, 'CircularProgressIndicator'), hasLength(1));
      expect(
        button.toSource(),
        contains(
          'final spins = busy && !MediaQuery.disableAnimationsOf(context);',
        ),
      );
      expect(button.toSource(), contains('if (spins)'));
      expect(
        button.documentationComment!.tokens.map((token) => token.lexeme).join(),
        contains('pumpAndSettle()'),
      );
      expect(agentNote, contains('`pumpAndSettle()`'));
    });

    test(
        'tells a screen reader of the title, of the fields by their labels '
        'and of a failure, and passes over the picture', () {
      final app = localized[SignInModule.blocVariant]!.app!;
      final page = _parsed(app, _page);
      final widgets = _parsed(app, _widgets);

      expect(
        _callsOf(page, 'Semantics').map((arguments) => arguments['header']),
        ['true'],
      );
      expect(_callsOf(_classOf(page, '_Cells'), 'ExcludeSemantics'), [
        isNotEmpty,
      ]);
      // The letters of the cell are part of the picture.
      expect(
        _callsOf(_classOf(page, '_Cell'), 'MediaQuery'),
        hasLength(1),
      );
      expect(
        _classOf(page, '_Cell').toSource(),
        contains('MediaQuery.withNoTextScaling('),
      );
      final labelled = _classOf(widgets, '_Labelled');
      expect(
        _callsOf(labelled, 'Semantics').single,
        containsPair('label', 'label'),
      );
      expect(_callsOf(labelled, 'ExcludeSemantics'), hasLength(1));
      expect(
        _callsOf(_classOf(widgets, '_Failure'), 'Semantics').single,
        containsPair('liveRegion', 'true'),
      );
    });

    test(
        'has the keyboard and the autofill of the device fit each field: '
        'an address and the password of an account in the sign-in, new '
        'ones in the sign-up', () {
      final app = localized[SignInModule.blocVariant]!.app!;
      final widgets = _parsed(app, _widgets);
      final [email, password] = _callsOf(widgets, 'TextFormField');

      expect(email['keyboardType'], 'TextInputType.emailAddress');
      expect(email['autocorrect'], 'false');
      expect(email.keys, isNot(contains('obscureText')));
      expect(email.keys, isNot(contains('autofocus')));
      expect(password['obscureText'], '_hidden');
      expect(password['textInputAction'], 'TextInputAction.done');
      expect(password['autocorrect'], 'false');
      expect(password['enableSuggestions'], 'false');
      expect(password.keys, isNot(contains('autofocus')));

      String? hintsOf(String path, String field) =>
          _callsOf(_parsed(app, path), field).single['autofillHints'];
      expect(
        hintsOf(_views[0], 'EmailField'),
        'const [AutofillHints.username, AutofillHints.email]',
      );
      expect(
        hintsOf(_views[0], 'PasswordField'),
        'const [AutofillHints.password]',
      );
      expect(
        hintsOf(_views[1], 'EmailField'),
        'const [AutofillHints.email, AutofillHints.newUsername]',
      );
      expect(
        hintsOf(_views[1], 'PasswordField'),
        'const [AutofillHints.newPassword]',
      );
      // The one field of the reset submits its form.
      final reset = _callsOf(_parsed(app, _views[2]), 'EmailField').single;
      expect(reset['textInputAction'], 'TextInputAction.done');
      expect(reset['onSubmitted'], '_submit');
      for (final path in _views.take(2)) {
        expect(_callsOf(_parsed(app, path), 'AutofillGroup'), hasLength(1));
      }
    });

    test(
        'has one filled action and one text action on the sign-in and on '
        'the sign-up, the text action leading to the other screen and '
        'waiting while the form submits', () {
      final app = localized[SignInModule.blocVariant]!.app!;
      final signIn = _parsed(app, _views[0]);
      final signUp = _parsed(app, _views[1]);

      for (final view in [signIn, signUp]) {
        // The button that submits is the one filled button of the screen.
        expect(_callsOf(view, 'SubmitButton'), hasLength(1));
        expect(_callsOf(view, 'FilledButton'), isEmpty);
        expect(_callsOf(view, 'OutlinedButton'), isEmpty);
      }
      final [forgot, create] = _callsOf(signIn, 'TextButton');
      final have = _callsOf(signUp, 'TextButton').single;
      // What belongs to the password is at the end of its field, inside
      // the form, and takes no input while the form submits, as the form.
      expect(forgot['onPressed'], 'widget.onForgotPassword');
      expect(forgot['child'], contains('TextAlign.end'));
      // The way to the other screen is the same kind of action on both
      // screens, in the middle below the button.
      expect(
          create['onPressed'], 'widget.busy ? null : widget.onCreateAccount');
      expect(have['onPressed'], 'widget.busy ? null : widget.onSignIn');
      for (final action in [create, have]) {
        expect(action.keys, ['onPressed', 'child']);
        expect(action['child'], contains('TextAlign.center'));
      }
      expect(
        _textsReadIn(_classOf(signIn, '_SignInViewState')),
        containsAllInOrder([
          _getterOf('forgotPassword'),
          _getterOf('submit'),
          _getterOf('createAccount'),
        ]),
      );
      expect(
        _textsReadIn(_classOf(signUp, '_SignUpViewState')),
        containsAllInOrder([
          _getterOf('signUpSubmit'),
          _getterOf('haveAccount'),
        ]),
      );
    });

    test(
        'lets the parts of a page rise in once, and not at all in an app '
        'that asks for less motion', () {
      final app = localized[SignInModule.blocVariant]!.app!;
      final state = _classOf(_parsed(app, _page), '_AuthPageState');
      final source = state.toSource();

      expect(_callsOf(state, 'AnimationController'), hasLength(1));
      expect(source, contains('if (_started) return;'));
      expect(
        source,
        contains(
          'if (MediaQuery.disableAnimationsOf(context)) {_entrance.value = 1;} '
          'else {_entrance.forward();}',
        ),
      );
      // Nothing of a page repeats.
      for (final path in _look) {
        final unit = _parsed(app, path);
        final repeats = _Invocations('repeat');
        unit.accept(repeats);
        expect(repeats.found, isEmpty, reason: path);
      }
    });

    test('shows the symbol and the number of the app in the cell of a page',
        () async {
      final result = await _rendered(
        SignInModule.blocVariant,
        context: const ModuleContext(
          appName: 'my_app',
          orgName: 'org.example',
          appIdentity: AppIdentity(
            platforms: ['android', 'ios'],
            androidApplicationId: 'org.example.my_app',
            iosBundleId: 'org.example.my-app',
            androidNamespace: 'org.example.my_app',
          ),
        ),
      );
      final page = _parsed(result.app!, _page);

      expect(_constantOf(page, '_appSymbol'), "'Ma'");
      expect(_constantOf(page, '_appNumber'), '5');
      final contract =
          _parsed(localized[SignInModule.blocVariant]!.app!, _page);
      expect(_constantOf(contract, '_appSymbol'), "'Ca'");
      expect(_constantOf(contract, '_appNumber'), '11');
    });

    test(
        'reads each text of the module once from the texts of an app with '
        'the localization, but for the text of an address that is none, '
        'which a form and a failure share', () {
      for (final variant in _variants) {
        final result = localized[variant.id]!;
        final app = result.app!;
        final read = [
          for (final path in _ownFilesOf(app))
            ..._textsReadIn(_parsed(app, path)),
        ]..sort();

        expect(
          _appTextsOf(result).keys,
          [for (final name in _textNames) _getterOf(name)],
        );
        expect(
          read,
          [
            for (final name in _textNames) _getterOf(name),
            _getterOf('emailInvalid'),
          ]..sort(),
          reason: '${variant.id}',
        );
        // Only the look reads a text.
        for (final path in [...variant.stateFiles, ..._screens.values]) {
          expect(_textsReadIn(_parsed(app, path)), isEmpty, reason: path);
        }
      }
    });

    test(
        'has the English texts in an app without the localization, which '
        'imports no texts', () {
      for (final variant in _variants) {
        final app = english[variant.id]!.app!;
        final strings = [
          for (final path in _look) ..._stringsIn(_parsed(app, path)),
        ];

        for (final text in SignInModule.texts.texts) {
          expect(strings, contains(text.en), reason: '$text');
        }
        for (final path in _ownFilesOf(app)) {
          final unit = _parsed(app, path);
          expect(_textsReadIn(unit), isEmpty, reason: path);
          expect(
            _importsOf(unit).where((uri) => uri.contains('l10n')),
            isEmpty,
            reason: path,
          );
        }
      }
    });

    test(
        'has the annotations that a router gives the classes of the '
        'screens, in each variant', () async {
      for (final variant in _variants) {
        final result = await _rendered(
          variant.id,
          others: const [_Annotating.id],
          registry: const [..._modules, _Annotating()],
        );

        for (final MapEntry(key: screen, value: path) in _screens.entries) {
          final declaration = _classOf(_parsed(result.app!, path), screen);
          expect(
            declaration.metadata.map((annotation) => annotation.toSource()),
            [_annotation],
            reason: '${variant.id}: $screen',
          );
        }
        // Without such a module, the classes have none.
        final plain = localized[variant.id]!.app!;
        for (final MapEntry(key: screen, value: path) in _screens.entries) {
          expect(_classOf(_parsed(plain, path), screen).metadata, isEmpty);
        }
      }
    });

    test(
        'takes the package of its state manager with the version of the '
        'module that provides it, and no other package', () {
      for (final variant in _variants) {
        for (final apps in [localized, english]) {
          final pubspec = loadYaml(
            apps[variant.id]!.app!.files['pubspec.yaml']!.text,
          ) as YamlMap;
          final dependencies = pubspec['dependencies'] as YamlMap;
          final other =
              _variants.singleWhere((other) => other.id != variant.id).package;

          // The constraint is that of the provider, which the constraint
          // any of the variant leaves to it.
          expect(
            dependencies[variant.package],
            matches(RegExp(r'^\^\d+\.\d+\.\d+$')),
            reason: '${variant.id}',
          );
          expect(dependencies.keys, isNot(contains(other)));
          // What every app of the tests has, and the package of the state
          // manager: the module adds nothing else.
          expect(
            dependencies.keys.toSet().difference({
              'flutter',
              'flutter_localizations',
              'go_router',
              'intl',
              'shared_preferences',
            }),
            {variant.package},
            reason: '${variant.id}',
          );
        }
      }
    });
  });

  group('the texts of the failures', () {
    late ContractResult localized;
    late ContractResult english;

    setUpAll(() async {
      localized = await _rendered(SignInModule.blocVariant);
      english = await _rendered(SignInModule.blocVariant, others: const []);
    });

    test(
        'are one for every reason of a failure of the auth role, in '
        'English and in Ukrainian', () {
      final reasons = _reasonsOf(localized.app!);
      final code = _failureCodeOf(localized.app!);
      final texts = _appTextsOf(localized);

      // The reasons as the role has them, each with its text.
      expect(reasons, _failureTexts.keys);
      expect(code.keys, reasons);
      expect(code, {
        for (final MapEntry(key: reason, value: name) in _failureTexts.entries)
          reason: 'context.l10n.${_getterOf(name)}',
      });
      for (final MapEntry(key: reason, value: expression) in code.entries) {
        final text = texts[expression.split('.').last]!;
        expect(text.en.trim(), isNotEmpty, reason: reason);
        expect(text.textIn('uk')?.trim(), isNotEmpty, reason: reason);
        expect(text.textIn('uk'), isNot(text.en), reason: reason);
      }
    });

    test(
        'differ for every two reasons, in both languages: a user tells '
        'each failure from the others', () {
      for (final language in ['en', 'uk']) {
        final shown = {
          for (final MapEntry(key: reason, value: name)
              in _failureTexts.entries)
            reason: _textOf(name).textIn(language)!,
        };

        expect(
          shown.values.toSet(),
          hasLength(_failureTexts.length),
          reason: 'Two reasons share a text in $language: $shown',
        );
      }
    });

    test(
        'share one text on purpose: an address that the provider takes for '
        'none reads as an address that the form takes for none', () {
      final widgets = _parsed(localized.app!, _widgets);
      final invalid = _getterOf('emailInvalid');

      expect(_failureTexts['invalidEmail'], 'emailInvalid');
      expect(
        _textsReadIn(_classOf(widgets, 'EmailField')),
        contains(invalid),
      );
      expect(_failureCodeOf(localized.app!)['invalidEmail'], endsWith(invalid));
      // No other text of a failure is one of a form.
      final ofForms = {
        ..._textsReadIn(_classOf(widgets, 'EmailField')),
        ..._textsReadIn(_classOf(widgets, '_PasswordFieldState')),
      };
      expect(
        [
          for (final MapEntry(key: reason, value: name)
              in _failureTexts.entries)
            if (ofForms.contains(_getterOf(name))) reason,
        ],
        ['invalidEmail'],
      );
    });

    test(
        'say of a sign-in that is not set up only that it is unavailable, '
        'and of a call that needs a recent sign-in to sign out and in '
        'again', () {
      final notSetUp = _textOf(_failureTexts['notConfigured']!);
      final recent = _textOf(_failureTexts['recentSignInRequired']!);

      expect(notSetUp.en, 'Sign-in is unavailable right now.');
      expect(notSetUp.textIn('uk'), 'Вхід зараз недоступний.');
      expect(recent.en, contains('Sign out and sign in again'));
      expect(recent.textIn('uk'), contains('Вийдіть і увійдіть знову'));
    });

    test('are the English ones in an app without the localization', () {
      expect(_failureCodeOf(english.app!), {
        for (final MapEntry(key: reason, value: name) in _failureTexts.entries)
          reason: SmfNames.dartString(_textOf(name).en),
      });
    });

    test(
        'show with what the provider tells the developer of the app in '
        'debug mode only', () {
      final failure = _classOf(_parsed(localized.app!, _widgets), '_Failure');

      expect(
        failure.toSource(),
        contains('final hint = kDebugMode ? failure.developerHint : null;'),
      );
      expect(
        _callsOf(failure, 'authFailureText').single,
        {'0': 'context', '1': 'failure.reason'},
      );
    });
  });

  for (final variant in _variants) {
    final isBloc = variant.id == SignInModule.blocVariant;

    group('the state of the screens with ${variant.id}', () {
      late RenderedApp app;
      late Map<Object?, Object?> result;

      Map<Object?, Object?> of(String screen) =>
          result[screen]! as Map<Object?, Object?>;

      setUpAll(() async {
        app = (await _rendered(variant.id)).app!;
        result = await runState(
          app,
          imports: [
            'package:${variant.package}/${variant.package}.dart',
            // What a test of providers needs beyond what an app does.
            if (!isBloc) 'package:riverpod/misc.dart',
            for (final path in variant.stateFiles) _import(path),
          ],
          declarations: isBloc ? _blocScreens : _riverpodScreens,
          body: '$_scenarios\n${isBloc ? _blocApp : _riverpodApp}',
        );
      });

      test(
          'type-checks with the files of the auth role and the package '
          'that the state manager builds on', () async {
        expect(
          await analysisProblemsOf(app, [
            AuthRole.serviceFile,
            AuthRole.sessionFile,
            AuthRole.guestDataFile,
            _state,
            _guards,
            ...variant.stateFiles,
          ]),
          isEmpty,
        );
      });

      test(
          'signs in through the session, and stays busy once the user is '
          'signed in: the router leaves the screen then', () {
        final signIn = of('sign-in');

        expect(signIn['at first'], 'busy: false, failure: null');
        expect(signIn['success: calls'], ['signIn ann@example.com secret']);
        expect(signIn['success: session'], 'account account ann@example.com');
        expect(signIn['success: states'], ['busy: true, failure: null']);
        expect(signIn['success: state'], 'busy: true, failure: null');
      });

      test(
          'signs up through the session in the same way, with the same '
          'call for a new user and for an anonymous one', () {
        final signUp = of('sign-up');

        expect(signUp['at first'], 'busy: false, failure: null');
        expect(signUp['success: calls'], ['signUp ann@example.com secret']);
        expect(signUp['success: session'], 'account new ann@example.com');
        expect(signUp['success: states'], ['busy: true, failure: null']);
        expect(signUp['success: state'], 'busy: true, failure: null');
        // The session gives the anonymous user the account: the screen
        // does not ask who is signed in.
        expect(result['anonymous: before'], 'anonymous guest');
        expect(result['anonymous: calls'], [
          'signInAnonymously',
          'linkPassword ann@example.com secret',
        ]);
        expect(result['anonymous: session'], 'account guest ann@example.com');
      });

      test(
          'sends the message that resets a password through the session, '
          'and then has the address that it went to', () {
        final reset = of('reset');

        expect(reset['at first'], 'busy: false, failure: null, sent to: null');
        expect(reset['success: calls'], ['sendPasswordReset ann@example.com']);
        expect(reset['success: session'], 'nobody');
        expect(reset['success: states'], [
          'busy: true, failure: null, sent to: null',
          'busy: false, failure: null, sent to: ann@example.com',
        ]);
        expect(
          reset['success: state'],
          'busy: false, failure: null, sent to: ann@example.com',
        );
      });

      test(
          'ends the busy state of a screen with the failure of its call, '
          'and takes the next call', () {
        for (final screen in ['sign-in', 'sign-up']) {
          final states = of(screen);

          expect(
            states['failure: states'],
            ['busy: true, failure: null', 'busy: false, failure: network'],
            reason: screen,
          );
          expect(states['failure: state'], 'busy: false, failure: network');
          expect(states['failure: session'], 'nobody', reason: screen);
          // The next call starts without the failure.
          expect(
            states['again: states'],
            [
              'busy: true, failure: null',
              'busy: false, failure: network',
              'busy: true, failure: null',
            ],
            reason: screen,
          );
          expect(states['again: calls'], 2, reason: screen);
        }
        final reset = of('reset');
        expect(reset['failure: states'], [
          'busy: true, failure: null, sent to: null',
          'busy: false, failure: network, sent to: null',
        ]);
        expect(reset['again: states'], [
          'busy: true, failure: null, sent to: null',
          'busy: false, failure: network, sent to: null',
          'busy: true, failure: null, sent to: null',
          'busy: false, failure: null, sent to: ann@example.com',
        ]);
      });

      test('does nothing with a second submit while a call is on its way', () {
        for (final screen in ['sign-in', 'sign-up', 'reset']) {
          final states = of(screen);

          expect(states['busy: state'], startsWith('busy: true'));
          expect(states['busy: states'], hasLength(1), reason: screen);
          // The service got the first call and no other.
          expect(
            states['busy: calls in the end'],
            hasLength(1),
            reason: screen,
          );
        }
      });

      test(
          'tells nothing more, and fails with nothing, once the user has '
          'left the screen while its call was on its way', () {
        for (final screen in ['sign-in', 'sign-up', 'reset']) {
          final states = of(screen);

          for (final end in ['a failure', 'a success']) {
            expect(states['left, then $end: error'], isNull, reason: screen);
            expect(
              states['left, then $end: states told since'],
              0,
              reason: '$screen, $end',
            );
          }
        }
      });

      test(
          'has the session of the app in the app, from the one file of '
          'the state that names it', () {
        expect(result['app: calls'], ['signIn ann@example.com secret']);
        expect(result['app: session'], 'account account ann@example.com');
        if (isBloc) {
          expect(result['app: created'], ['SignUpCubit', 'ResetPasswordCubit']);
        } else {
          expect(result['app: provider'], isTrue);
        }
      });
    });
  }

  group('the guards of the sign-in', () {
    /// What the two functions of the guards say in an app in the mode
    /// [mode] of the auth role, while nobody is signed in, with an account
    /// and after a sign-out, and what their listeners heard.
    Future<Map<Object?, Object?>> guardsIn(String? mode) async {
      final result = await _rendered(
        SignInModule.blocVariant,
        roleOptions: {if (mode != null) AuthRole.modeOption.name: mode},
      );
      return runState(
        result.app!,
        imports: const [],
        body: r'''
  final service = Scripted();
  await appSession.start(service);
  final allows = signInAllowsApp();
  final has = signInHasAccount();
  result['mode'] = authMode.name;
  result['of the session'] =
      identical(allows, appSession.allowsApp) &&
      identical(has, appSession.hasAccount);
  final heard = <String>[];
  allows.addListener(() => heard.add('gate ${allows.value}'));
  has.addListener(() => heard.add('account ${has.value}'));
  result['at first'] = [show(appSession.value), allows.value, has.value];
  await appSession.signIn(email: email, password: password);
  result['signed in'] = [show(appSession.value), allows.value, has.value];
  await appSession.signOut();
  result['signed out'] = [show(appSession.value), allows.value, has.value];
  result['heard'] = heard;
''',
      );
    }

    test(
        'are those of the router role, in the order the app asks them: '
        'the gate, and then the guard of the account, both over the three '
        'screens', () async {
      final result = await _rendered(SignInModule.blocVariant);
      final facade = _facadeOf(result);
      final [gate, account] = facade.guards;

      expect(gate.fullName, 'sign_in.gate');
      expect(gate.isGate, isTrue);
      expect(account.fullName, 'sign_in.account');
      expect(account.isGate, isFalse);
      expect(facade.guardFor(AuthRole.account), same(account));
      for (final guard in [gate, account]) {
        expect(guard.target.fullPath, '/sign_in');
        expect(
          [for (final route in guard.flow) (route.fullName, route.fullPath)],
          [
            ('sign_in.signIn', '/sign_in'),
            ('sign_in.signUp', '/sign_in/sign_up'),
            ('sign_in.resetPassword', '/sign_in/reset_password'),
          ],
        );
      }
      // No route of the module asks for the account, and none can start
      // the app: an app with the module alone starts on the fallback
      // screen of its app entry, and one with another feature on a screen
      // of that feature.
      expect(facade.routesAsking(AuthRole.account), isEmpty);
      expect(routerRole.startIn(routerRole.hookInput(result.hook!)), isNull);
      final withFeed = await _rendered(
        SignInModule.blocVariant,
        others: [_feed.id],
      );
      expect(
        routerRole.startIn(routerRole.hookInput(withFeed.hook!))?.fullName,
        'feed.feed',
      );
      // The functions as the app declares them.
      final guards = _indexOf(result.app!, _guards);
      for (final guard in [gate, account]) {
        expect(
          guards.declaration(guard.guard.allows.name)?.kind,
          DeclarationKind.function,
        );
      }
      expect(
        [
          for (final access in guards.memberAccesses)
            '${access.target}.${access.name}',
        ],
        ['appSession.allowsApp', 'appSession.hasAccount'],
      );
    });

    test(
        'keep a user without an account from the whole app in an app that '
        'needs one', () async {
      final guards = await guardsIn(null);

      expect(guards['mode'], 'required');
      expect(guards['of the session'], isTrue);
      expect(guards['at first'], ['nobody', false, false]);
      expect(guards['signed in'], [
        'account account ann@example.com',
        true,
        true,
      ]);
      expect(guards['signed out'], ['nobody', false, false]);
      // Each listener hears of each change of the session, with both
      // values up to date.
      expect(guards['heard'], [
        'gate true',
        'account true',
        'gate false',
        'account false',
      ]);
    });

    test(
        'keep a guest only from what needs an account in an app that '
        'everyone may use', () async {
      final guards = await guardsIn('guest');

      expect(guards['mode'], 'guest');
      expect(guards['at first'], ['nobody', true, false]);
      expect(guards['signed in'], [
        'account account ann@example.com',
        true,
        true,
      ]);
      expect(guards['signed out'], ['nobody', true, false]);
    });

    test('keep an anonymous user only from what needs an account too',
        () async {
      final guards = await guardsIn('anonymous');

      expect(guards['mode'], 'anonymous');
      expect(guards['at first'], ['anonymous guest', true, false]);
      expect(guards['signed in'], [
        'account account ann@example.com',
        true,
        true,
      ]);
      // The app signs an anonymous user in again.
      expect(guards['signed out'], ['anonymous guest', true, false]);
    });
  });

  group('the note of the module for coding agents', () {
    late Map<ModuleId, ContractResult> results;

    setUpAll(() async {
      results = {
        for (final variant in _variants)
          variant.id: await _rendered(variant.id),
      };
    });

    test(
        'is a section of its own in the guide of the app, with what the '
        'variant of the app adds after it', () {
      const added = {
        SignInModule.blocVariant: blocAgentNote,
        SignInModule.riverpodVariant: riverpodAgentNote,
      };

      expect(agentHeading, 'Sign-in');
      for (final variant in _variants) {
        final app = results[variant.id]!.app!;

        expect(
          [
            for (final (origin, heading, note)
                in app.entriesOf(AppEntryRole.agentSections))
              if (origin is ModuleOrigin && origin.module == SignInModule.id)
                (heading, note),
          ],
          [
            (agentHeading, AgentNote(agentNote)),
            (agentHeading, AgentNote(added[variant.id]!)),
          ],
          reason: '${variant.id}',
        );
        expect(
          app.files[AppEntryRole.agentsFile]!.text,
          contains(
            '\n## $agentHeading\n\n${agentNote.trim()}\n\n'
            '${added[variant.id]!.trim()}\n',
          ),
          reason: '${variant.id}',
        );
        // What the other variant adds is not in the guide.
        for (final other in added.entries) {
          if (other.key == variant.id) continue;
          expect(
            app.files[AppEntryRole.agentsFile]!.text,
            isNot(contains(other.value.trim())),
          );
        }
      }
    });

    test(
        'names the screens, their routes and the guards as the router '
        'role has them, and the functions of the guards with what they '
        'read', () {
      final code = _codeOf(agentNote);
      final result = results[SignInModule.blocVariant]!;
      final facade = _facadeOf(result);

      expect(
        code,
        containsAll([
          for (final guard in facade.guards) guard.fullName,
          RouterRole.routeGuards,
          for (final route in facade.guards.first.flow) ...[
            route.route.screen.className,
            route.fullPath,
          ],
          facade.guards.first.target.fullName,
          '$_folder/',
          _guards,
          'appSession.allowsApp',
          'appSession.hasAccount',
        ]),
      );
      expect(
        [
          for (final access in _indexOf(result.app!, _guards).memberAccesses)
            '${access.target}.${access.name}',
        ],
        ['appSession.allowsApp', 'appSession.hasAccount'],
      );
      // The list of the guards, which the template of the router role
      // generates, with the guards by their names.
      expect(
        _indexOf(result.app!, RouterRole.appRouterFile)
            .declaration(RouterRole.routeGuards)
            ?.kind,
        DeclarationKind.variable,
      );
      expect(
        _stringsIn(_parsed(result.app!, RouterRole.appRouterFile)),
        containsAll([for (final guard in facade.guards) guard.fullName]),
      );
    });

    test(
        'names the views, the frame of a screen, the values of the state, '
        'and what gives a failure its text, as the files of the app '
        'declare them', () {
      final code = _codeOf(agentNote);
      final app = results[SignInModule.blocVariant]!.app!;
      const declared = {
        'SignInView': '$_folder/sign_in_view.dart',
        'SignUpView': '$_folder/sign_up_view.dart',
        'ResetPasswordView': '$_folder/reset_password_view.dart',
        'AuthPage': _page,
        'AuthActionState': _state,
        'ResetPasswordState': _state,
        'FailureMessage': _widgets,
        'SubmitButton': _widgets,
      };

      expect(
        code,
        containsAll([
          ...declared.keys,
          _views.first,
          _page,
          _widgets,
          _state,
          _screens['SignInScreen'],
          'authFailureText()',
          'AuthFailureReason',
          'developerHint',
        ]),
      );
      for (final MapEntry(key: name, value: path) in declared.entries) {
        expect(
          _indexOf(app, path).declaration(name)?.kind,
          DeclarationKind.classType,
          reason: name,
        );
      }
      expect(
        _indexOf(app, _widgets).declaration('authFailureText')?.kind,
        DeclarationKind.function,
      );
      // What the role declares, and the note names.
      final service = _indexOf(app, AuthRole.serviceFile);
      expect(
        service.declaration('AuthFailureReason')?.kind,
        DeclarationKind.enumType,
      );
      expect(
        {
          for (final member in service.declaration('AuthFailure')!.members)
            member.name: member.kind,
        },
        containsPair('developerHint', MemberKind.field),
      );
    });

    test(
        'names with bloc the cubits of the screens and the file that '
        'creates them with the session', () {
      final code = _codeOf(blocAgentNote);
      final app = results[SignInModule.blocVariant]!.app!;
      const cubits = {
        'SignInCubit': '$_folder/sign_in_cubit.dart',
        'SignUpCubit': '$_folder/sign_up_cubit.dart',
        'ResetPasswordCubit': '$_folder/reset_password_cubit.dart',
      };

      expect(
        code,
        {...cubits.keys, _composition, 'appSession', 'AppSessionController'},
      );
      for (final MapEntry(key: name, value: path) in cubits.entries) {
        expect(
          _indexOf(app, path).declaration(name)?.kind,
          DeclarationKind.classType,
          reason: name,
        );
      }
      expect(
        _indexOf(app, AuthRole.sessionFile)
            .declaration('AppSessionController')
            ?.kind,
        DeclarationKind.classType,
      );
    });

    test(
        'names with riverpod the providers of the screens and the '
        'provider through which they reach the session', () {
      final code = _codeOf(riverpodAgentNote);
      final app = results[SignInModule.riverpodVariant]!.app!;
      const providers = {
        'signInProvider': '$_folder/sign_in_notifier.dart',
        'signUpProvider': '$_folder/sign_up_notifier.dart',
        'resetPasswordProvider': '$_folder/reset_password_notifier.dart',
        'appSessionProvider': _sessionProvider,
      };

      expect(code, {
        ...providers.keys,
        _sessionProvider,
        'Notifier',
        'appSession',
        'AppSessionController',
      });
      for (final MapEntry(key: name, value: path) in providers.entries) {
        expect(
          _indexOf(app, path).declaration(name)?.kind,
          DeclarationKind.variable,
          reason: name,
        );
      }
      // Each provider of a screen lasts as long as the screen.
      for (final path in _notifiers) {
        expect(
          app.files[path]!.text,
          contains('NotifierProvider.autoDispose<'),
          reason: path,
        );
      }
    });

    test(
        'says nothing of how a widget reads who uses the app: no file of '
        'the module gives the widgets of the app the session', () {
      for (final variant in _variants) {
        final app = results[variant.id]!.app!;

        expect(
          [
            for (final path in _ownFilesOf(app))
              ..._identifiersIn(_parsed(app, path)).intersection({
                'SessionCubit',
                'sessionProvider',
                'createSessionCubit',
              }),
          ],
          isEmpty,
          reason: '${variant.id}',
        );
      }
      for (final note in [agentNote, blocAgentNote, riverpodAgentNote]) {
        expect(note, isNot(contains('context.watch')));
        expect(note, isNot(contains('ref.watch')));
      }
      // Nor does the module put a widget around the root of the app.
      final bloc = results[SignInModule.blocVariant]!;
      expect(
        [
          for (final collected in bloc.app!
                  .socketOrders[AppEntryRole.rootWrappers]?.contributions ??
              const <Collected>[])
            if (collected.origin == _module) collected,
        ],
        isEmpty,
      );
    });
  });
  group('the documentation of the package', () {
    late Map<ModuleId, RenderedApp> apps;
    late Set<String> paths;

    /// The text of [path] in the package, with the line endings of Git on
    /// any system.
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    setUpAll(() async {
      // The example generates an app without localization.
      final results = {
        for (final variant in _variants)
          variant.id: await _rendered(variant.id, others: const []),
      };
      apps = {
        for (final MapEntry(key: id, value: result) in results.entries)
          id: result.app!,
      };
      paths = {
        for (final route in _facadeOf(results.values.first).routes)
          route.fullPath,
      };
    });

    test(
        'shows in its example parts of the files of the app, with each '
        'state manager', () {
      final example = read('example/README.md');
      final shown = [
        for (final block
            in RegExp(r'```dart\n([\s\S]*?)```').allMatches(example))
          block[1]!,
      ];
      String? fileWith(RenderedApp app, String part) => _ownFilesOf(app)
          .where((path) => app.files[path]!.text.contains(part))
          .firstOrNull;

      expect(shown, hasLength(5));
      expect(
        [
          for (final part in shown)
            (
              fileWith(apps[SignInModule.blocVariant]!, part),
              fileWith(apps[SignInModule.riverpodVariant]!, part),
            ),
        ],
        [
          // The screen and the cubit of the variant for bloc, the screen of
          // the variant for riverpod, and the two functions of the guards,
          // which every app has.
          (_screens['SignInScreen'], null),
          (_cubits.first, null),
          (null, _screens['SignInScreen']),
          (_guards, _guards),
          (_guards, _guards),
        ],
      );
      expect(example, contains('smf create my_app -m home,sign_in,bloc'));
    });

    test(
        'names in its README and in its example the files, the classes and '
        'the routes of the module as the apps have them', () {
      for (final document in ['README.md', 'example/README.md']) {
        final code = _codeOf(
          // Without the blocks of code, whose backticks are no inline code.
          read(document).replaceAll(RegExp(r'```[\s\S]*?```'), ''),
        );
        final files = {
          for (final app in apps.values)
            for (final path in _ownFilesOf(app)) path.split('/').last,
        };
        final declared = {
          for (final app in apps.values)
            for (final path in _ownFilesOf(app))
              for (final declaration in _indexOf(app, path).declarations)
                declaration.name,
        };

        // Every file that the text names is a file of the module.
        expect(
          code
              .where((name) => name.endsWith('.dart'))
              .toSet()
              .difference(files),
          isEmpty,
          reason: document,
        );
        // Every class, function and provider of the module that it names
        // is declared in one of them.
        final named = code
            .map((name) => name.replaceFirst('()', ''))
            .where(
              (name) => RegExp(
                r'^(\w+(Screen|View|Cubit|Provider|State|Page|Message)|'
                r'authFailureText|signIn\w+)$',
              ).hasMatch(name),
            )
            .toSet();
        expect(named, isNotEmpty, reason: document);
        expect(named.difference(declared), isEmpty, reason: document);
        // The paths of the routes are those of the router role.
        final routes =
            code.where((name) => name.startsWith('/sign_in')).toSet();
        expect(routes, isNotEmpty, reason: document);
        expect(routes.difference(paths), isEmpty, reason: document);
      }
    });
  });
}

/// The invocations of the method or the function [name] in a node.
final class _Invocations extends RecursiveAstVisitor<void> {
  _Invocations(this.name);

  final String name;
  final List<MethodInvocation> found = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == name) found.add(node);
    super.visitMethodInvocation(node);
  }
}
