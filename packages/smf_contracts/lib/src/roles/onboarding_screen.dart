import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/onboarding_screen_role_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contracts/src/roles/brick_templates.dart';
import 'package:smf_contracts/src/roles/contributors.dart';
import 'package:smf_contracts/src/roles/same_text.dart';
import 'package:smf_contracts/src/roles/screen_routes.dart';
import 'package:smf_contracts/src/roles/symbol_uses.dart';

/// The onboarding screen role; see [OnboardingScreenRole].
const onboardingScreenRole = OnboardingScreenRole._();

/// The role of the onboarding screen: the pages that a new user goes
/// through, to which the modules of the app add steps, such as a page that
/// asks for a permission.
///
/// A module that uses the role contributes an [OnboardingStep] for each of
/// its steps: an icon, a title, a text, the label of a button and the
/// function that the button calls, and optionally the label of a second
/// button that goes on without it and a function that says whether the
/// onboarding shows the step. The template of a role that uses this role
/// may contribute one too. The contributor knows nothing of the screen,
/// and the provider draws every step in the look of its own pages.
///
/// The steps of the app are those of [stepsIn], ordered by their
/// [OnboardingStage]. The role's template generates [stepsFile], whichever
/// provider is selected, with the class [step] and with the list
/// [appOnboardingSteps] of the steps of the app, in that order. A label of
/// a step is a text of its contributor, which the app shows in its
/// language, so the role uses the [LocalizationRole], and the template
/// reads the label as the layout role reads the label of a destination
/// (see [LocalizationRole.expressionOf]). In the app the label is a
/// top-level function of a `BuildContext`, so the list is a constant. The
/// template imports the file of the functions of a step with a prefix of its
/// own, such as `step0`, so that functions of the same name in the files of
/// two contributors do not clash.
///
/// A provider is a module with a route that shows the screen, which it
/// names with an [OnboardingScreenRoute]; the role requires the router. A
/// file of the provider reads [appOnboardingSteps], and the screen:
/// - asks each step for its [OnboardingStep.showIf] once each time it
///   shows, and leaves out a step whose function returns `false`. A step
///   that it shows stays while the user is on it, also once the function
///   would return `false`;
/// - shows each step that it kept on a page of its own, in the order of the
///   list, with no other page between two steps: the icon, the title as a
///   header for a screen reader, the text, the button of the action and,
///   if the step has one, the button of [OnboardingStep.later]. It calls
///   the functions of the labels in the `build` of the widget that shows
///   them, so that they follow the language of the app;
/// - calls [OnboardingStep.run] once when the user taps the button of the
///   action, and takes no tap on the buttons of the step until the future
///   completes. Then it goes on to the next page, also when the future
///   fails, and leaves the error uncaught or reports it with
///   `FlutterError.reportError`, so that it reaches the handlers of the
///   errors of the app. The button of `later` goes on without calling the
///   function;
/// - turns its pages with a swipe too, and calls no [OnboardingStep.run]
///   when the user swipes past a step or skips the onboarding;
/// - works also when code pushes it over the app as a new screen, as a
///   test of the role in a running app does.
///
/// The contract harness checks the functions of the steps (the rule
/// `onboarding_screen.step_functions`) and that the provider reads the
/// list (the rule `onboarding_screen.steps_shown`), so the tests of a
/// module with a step check it through [stepsIn], not in the files of a
/// provider. What only a running app shows is for a test of the role in
/// running apps: which steps the screen shows, in which order, their texts
/// and what each button does.
///
/// The action of a step may open a dialog of the system, such as the
/// question for a permission, which would stay over the app on a device.
/// So no probe of the start check turns the pages of the onboarding or
/// calls the action of a step: what a step does is for the tests of the app
/// under `flutter test`, where the platform side is mocked.
///
/// When the app shows the onboarding is up to the provider, which may keep
/// a new user on it with a guard of the routes.
final class OnboardingScreenRole extends Role<OnboardingData> {
  const OnboardingScreenRole._();

  /// The path of the file with [step] and [appOnboardingSteps].
  static const stepsFile = 'lib/core/onboarding/onboarding_steps.dart';

  /// The class of a step in the app, which the role's template generates:
  /// `OnboardingStep(icon: ..., title: ..., text: ..., action: ..., run:
  /// ..., later: ..., showIf: ...)`, with an `IconData` icon, labels of the
  /// type `String Function(BuildContext context)`, which return the text in
  /// the language of the app, `run` of the type `Future<void> Function()`
  /// and `showIf` of the type `bool Function()`. `later` and `showIf` may be
  /// `null`.
  ///
  /// Its constructor is `const`, and the template creates the steps as
  /// constants in [appOnboardingSteps], each with top-level functions. The
  /// provider reads every field from a step.
  static const step = RequiredClass(
    'OnboardingStep',
    path: stepsFile,
    namedParameters: [
      'icon',
      'title',
      'text',
      'action',
      'run',
      'later',
      'showIf',
    ],
    constConstructor: true,
    getters: ['icon', 'title', 'text', 'action', 'run', 'later', 'showIf'],
  );

  /// The name of the list of the steps of the app, which the role's
  /// template generates in [stepsFile] as
  /// `const List<OnboardingStep> appOnboardingSteps`: a [step] for each
  /// step of [stepsIn], in their order. The list is empty in an app whose
  /// modules add no step.
  static const appOnboardingSteps = 'appOnboardingSteps';

  @override
  String get id => 'onboarding_screen';

  @override
  String get description => 'Onboarding screen';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get requires => {routerRole};

  @override
  Set<Role> get uses => {localizationRole};

  @override
  RoleInterface get interface => const RoleInterface(
        files: [stepsFile],
        symbols: [step],
      );

  @override
  RoleTemplate<OnboardingData> get template => const _OnboardingTemplate();

  @override
  List<ModuleRule<OnboardingData>> get moduleRules => const [
        ModuleRule(
          id: 'onboarding_screen.steps',
          description: 'The onboarding steps of a module have lowerCamelCase '
              'names that differ, an icon, texts with translations only if '
              'the module lists the localization role, and functions in '
              'files of the app that the bricks of the module generate.',
          check: _checkSteps,
        ),
        ModuleRule(
          id: 'onboarding_screen.route',
          description: 'The provider of the role, and no other module, '
              'names one route of its own that needs no values as the '
              'onboarding screen.',
          check: _checkRoute,
        ),
      ];

  @override
  List<StructuralRule<OnboardingData>> get structuralRules => const [
        StructuralRule(
          id: 'onboarding_screen.step_functions',
          description: 'The functions of every onboarding step are '
              'top-level functions in files of the contributor of the step '
              'that require no arguments: run returns a Future, and showIf '
              'a bool.',
          check: _checkStepFunctions,
        ),
        StructuralRule(
          id: 'onboarding_screen.steps_shown',
          description: 'In an app with onboarding steps, a file of the '
              'provider of the role reads appOnboardingSteps, the list of the '
              'steps that the template of the role generates.',
          check: _checkStepsShown,
        ),
      ];

  /// The steps of the onboarding in [input], the input of a hook of this
  /// role, of its provider, or of a role that requires or uses this role,
  /// in the order the screen shows them.
  ///
  /// The order is part of the contract of the role, so that an app has its
  /// steps in the same order whichever module provides the screen: by the
  /// [OnboardingStage] of each step, and the steps of one stage in the
  /// order of the data of the role ([RoleHookInput.data]): the steps of the
  /// modules, in the order the modules were selected, and then those of the
  /// templates of roles, in the order of the first provider of each role.
  /// The steps of one contributor keep its order.
  List<AppOnboardingStep> stepsIn(RoleHookInput<Object> input) {
    final steps = [
      for (final data in dataIn(input))
        if (data.value case final OnboardingStep step)
          // Every data that a hook gets has an origin.
          AppOnboardingStep._(_ownerOf(data.origin!), step),
    ];
    return [
      for (final stage in OnboardingStage.values)
        ...steps.where((step) => step.step.stage == stage),
    ];
  }

  /// The route of the onboarding screen in [input], the input of a hook of
  /// this role or of its provider: the route that the provider names with
  /// its [OnboardingScreenRoute]. It is `null` if no module names one, or
  /// if the module that does has no route of that name, which the module
  /// rule `onboarding_screen.route` reports.
  ///
  /// The route is one of the routes of the app, which are data of the
  /// router role. So a hook of another role reads it only if that role
  /// requires or uses the router role too, besides this role; otherwise
  /// this throws an [ArgumentError] once a module names the route.
  ///
  /// The hooks of a role see the data of the role but not its provider, so
  /// this route is how code that knows only the role finds the screen, such
  /// as a test of the role in a running app: at [FacadeRoute.fullPath],
  /// which needs no values, the app shows the screen of the route.
  FacadeRoute? screenIn(RoleHookInput<Object> input) => screenRouteIn(
        input,
        this,
        (data) => data is OnboardingScreenRoute ? data.name : null,
      );
}

/// What the [OnboardingScreenRole] takes from the modules of the app: an
/// [OnboardingStep] from a contributor with a step, and the
/// [OnboardingScreenRoute] from the provider of the role.
@immutable
sealed class OnboardingData {
  const OnboardingData();
}

/// When the onboarding shows a step among the steps of the app: the steps
/// of an earlier stage first, whatever the order of their contributors.
///
/// The stages come in the order in which a new user meets what they stand
/// for. Two steps of one stage come in the order of their contributors,
/// the modules first and then the templates of roles, and those of one
/// contributor in its order (see [OnboardingScreenRole.stepsIn]).
///
/// The list of stages is closed, so a module cannot add one. A step of
/// another kind takes the stage that is closest to what it does, and the
/// order of its contributor says where it comes among the steps of that
/// stage.
enum OnboardingStage {
  /// A permission that the app asks for, such as the one to show
  /// notifications.
  permission,
}

/// A step of the onboarding: a page in the look of the onboarding with an
/// icon, a title, a text and a button whose action is a function of its
/// contributor, such as one that asks for a permission.
///
/// ```dart
/// onboardingScreenRole.data(
///   const OnboardingStep(
///     name: 'permission',
///     stage: OnboardingStage.permission,
///     icon: Fragment(
///       'Icons.notifications_active_outlined',
///       imports: [ImportRef('package:flutter/material.dart')],
///     ),
///     title: LocalizedText('permissionTitle', en: 'Allow notifications'),
///     text: LocalizedText('permissionText', en: 'Hear of what is new.'),
///     action: LocalizedText('permissionAction', en: 'Allow'),
///     later: LocalizedText('permissionLater', en: 'Not now'),
///     run: FunctionRef(
///       'askNotificationPermission',
///       import: ImportRef.app('core/notifications/permission_step.dart'),
///     ),
///     showIf: FunctionRef(
///       'notificationPermissionUnasked',
///       import: ImportRef.app('core/notifications/permission_step.dart'),
///     ),
///   ),
/// )
/// ```
///
/// The data needs no condition, since it applies only when the role is
/// present. The contributor generates the file of the functions in a brick
/// of its own; the module rule `onboarding_screen.steps` reports a function
/// in a file that the bricks of a module do not generate. That brick needs
/// no condition either: the functions are of use without an onboarding
/// too, as the request for a permission is.
///
/// The texts of the step are texts of its contributor (see
/// [DataWithTexts]). A contributor that lists the [LocalizationRole] among
/// its roles gives that role each of them too, with
/// `localizationRole.data(TextsData([...]), when: {onboardingScreenRole})`,
/// and the app shows them in its language.
@immutable
final class OnboardingStep extends OnboardingData implements DataWithTexts {
  /// Creates the step [name].
  const OnboardingStep({
    required this.name,
    required this.stage,
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.run,
    this.later,
    this.showIf,
  });

  /// The name of the step among those of its contributor, a lowerCamelCase
  /// identifier such as `permission`.
  final String name;

  /// When the onboarding shows the step among the steps of the app.
  final OnboardingStage stage;

  /// The icon of the page of the step, a constant expression of the type
  /// `IconData` with the imports it needs, such as
  /// `Icons.notifications_active_outlined` of
  /// `package:flutter/material.dart`.
  final Fragment icon;

  /// The title of the page of the step.
  final LocalizedText title;

  /// The text of the page of the step, below its title.
  final LocalizedText text;

  /// The label of the button that calls [run].
  final LocalizedText action;

  /// The label of the button that goes on to the next page without calling
  /// [run], such as `Not now`, or `null` for a step without that button.
  final LocalizedText? later;

  /// The function that the button [action] calls, such as one that asks
  /// for a permission: a top-level function of a file of the app that the
  /// contributor generates, which requires no arguments and returns a
  /// `Future`.
  ///
  /// The template of the role imports the file with a prefix of its own,
  /// so [ImportRef.prefix] and [ImportRef.show] do not apply.
  final FunctionRef run;

  /// The function that says whether the onboarding shows the step, or
  /// `null` for a step that it always shows: a top-level function of a file
  /// of the app that the contributor generates, which requires no arguments,
  /// returns a `bool` at once and has no side effects, such as whether the
  /// app has not asked for a permission yet.
  ///
  /// The onboarding asks it once each time it shows, so it reads what the
  /// app knows already, such as what the start-up of the app restored.
  final FunctionRef? showIf;

  /// The functions of the step: [run], and [showIf] if it is set.
  List<FunctionRef> get functions => [run, if (showIf != null) showIf!];

  /// The texts of the step that a user sees: its title, its text and the
  /// labels of its buttons.
  @override
  Iterable<LocalizedText> get shownTexts => [
        title,
        text,
        action,
        if (later != null) later!,
      ];

  /// Describes what is wrong with the step on its own, apart from its
  /// texts, or returns an empty list.
  List<String> problems() {
    final what = 'The onboarding step "$name"';
    final problems = <String>[];
    if (!_stepName.hasMatch(name)) {
      problems.add(
        '$what needs a name that is a lowerCamelCase identifier, such as '
        'permission.',
      );
    }
    if (icon.isWrapper || icon.code.trim().isEmpty) {
      problems.add(
        '$what has an icon that is not an expression, such as '
        'Icons.notifications.',
      );
    }
    problems.addAll(icon.problems());
    for (final function in functions) {
      problems.addAll(function.problems());
      if (!function.import.isAppFile) {
        problems.add(
          'The function ${function.name} of the onboarding step "$name" '
          'must be a function of a file of the app, imported with '
          'ImportRef.app.',
        );
      }
    }
    return problems;
  }

  @override
  String toString() => 'onboarding step "$name"';
}

/// The route that shows the onboarding screen, which the provider of the
/// [OnboardingScreenRole] names among its own routes:
///
/// ```dart
/// routerRole.data(RoutesData([Route('/', name: 'onboarding', ...)])),
/// onboardingScreenRole.data(const OnboardingScreenRoute('onboarding')),
/// ```
///
/// The route needs no values, so that code which knows only the role can
/// go to the screen; see [OnboardingScreenRole.screenIn].
@immutable
final class OnboardingScreenRoute extends OnboardingData {
  /// Names the route [name] of the provider as the onboarding screen.
  const OnboardingScreenRoute(this.name);

  /// The name of the route in the module of the provider, as [Route.name]
  /// has it, such as `onboarding`.
  final String name;

  @override
  String toString() => 'onboarding screen route "$name"';
}

/// A step of the onboarding of an app: an [OnboardingStep] with its owner.
///
/// Obtain the steps of an app with [OnboardingScreenRole.stepsIn].
@immutable
final class AppOnboardingStep {
  const AppOnboardingStep._(this.owner, this.step);

  /// Who gave the app the step: a module, also for a step of its variant,
  /// or the template of a role. The texts of the step are texts of the
  /// owner, such as for [LocalizationRole.appTextOf].
  final ContributionOrigin owner;

  /// The step.
  final OnboardingStep step;

  /// The full name of the step: the id of its owner and the name of the
  /// step, such as `notifications.permission`.
  String get fullName => '${_idOf(owner)}.${step.name}';

  @override
  String toString() => 'onboarding step $fullName';
}

final RegExp _stepName = RegExp(r'^[a-z][a-zA-Z0-9]*$');

/// The onboarding screen as messages name it.
const _screen = 'onboarding screen';

/// Who owns the steps that [origin] gave: a variant of a module gives the
/// steps of its module.
ContributionOrigin _ownerOf(ContributionOrigin origin) => switch (origin) {
      ModuleOrigin(:final module) => ModuleOrigin(module),
      _ => origin,
    };

/// The id of [owner], who gave the app a step: that of the template of a
/// role, or that of a module, which a module origin without a variant
/// names.
String _idOf(ContributionOrigin owner) =>
    owner is RoleTemplateOrigin ? owner.role.id : '$owner';

/// The path of the file of [function] relative to the project root, such
/// as `lib/core/notifications/permission_step.dart`, or `null` if it is
/// not of a file of the app.
String? _fileOf(FunctionRef function) =>
    function.import.isAppFile ? 'lib/${function.import.uri}' : null;

/// The note of the onboarding screen role in the guide for coding agents:
/// what a step of the onboarding is and how code adds one, whichever module
/// provides the screen. It names the file of the steps, which every app
/// with the role has, and no file of the screen, which is a file of its
/// provider.
final String _agentNote = '''
- The onboarding shows the steps of `${OnboardingScreenRole.appOnboardingSteps}` in `${OnboardingScreenRole.stepsFile}`, each on a page of its own, in the order of the list. A step is an `${OnboardingScreenRole.step.name}`: an `icon`, a `title`, a `text`, the label of its `action` and the function `run` that the action calls. Its `later` is the label of a button that goes on without calling `run`, and the onboarding leaves the step out when its `showIf` returns `false` as the onboarding opens.
- To add a step, add an `${OnboardingScreenRole.step.name}` to `${OnboardingScreenRole.appOnboardingSteps}`. Its labels, `run` and `showIf` are top-level functions, so that the list stays `const`: a label takes a `BuildContext` and returns the text, `run` returns a `Future`, and `showIf` returns a `bool` at once. Show a label with `step.title(context)` in the `build` of the widget that shows it, and do not keep what it returned: the text follows the language of the app.
- Skipping the onboarding skips its steps. So the app does not rely on `run` alone for what a step does, such as asking for a permission: the code that needs it calls the same function too.
''';

/// The template of the [OnboardingScreenRole]: the file of the steps of
/// the onboarding, the note of the role for coding agents, and the checks
/// of the data of the role that the module rules cannot make.
final class _OnboardingTemplate extends RoleTemplate<OnboardingData> {
  const _OnboardingTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(onboardingScreenRoleBundle),
        AppEntryRole.agentSections.entry(
          onboardingScreenRole.description,
          AgentNote.ofRole(_agentNote),
        ),
      ];

  /// Checks what the module rules of the role cannot see: the steps of the
  /// templates of roles, and a route of the screen that no module names.
  ///
  /// The steps of a template are checked as those of a module are, but
  /// for the files of their functions, which the structural rule
  /// `onboarding_screen.step_functions` checks. The texts of such a step
  /// are read from the texts of the app in every app with the localization
  /// role (see [LocalizationRole.expressionOf]), so the role of the
  /// template lists that role, and the template gives it each text of the
  /// step.
  @override
  List<SmfIssue> validate(RoleHookInput<OnboardingData> input) {
    // The names of the steps of each template, by the template.
    final named = <RoleTemplateOrigin, Set<String>>{};
    return [
      for (final RoleData(:value, :origin) in input.data)
        ...switch ((value, origin)) {
          (final OnboardingStep step, final RoleTemplateOrigin template) => [
              for (final problem in _templateStepProblems(
                input,
                step,
                template,
                named.putIfAbsent(template, () => {}),
              ))
                SmfIssue(problem, origin: template),
            ],
          (OnboardingStep(), _) => const <SmfIssue>[],
          (OnboardingScreenRoute(), _) => screenRouteOriginIssues(
              origin,
              onboardingScreenRole,
              screen: _screen,
            ),
        },
    ];
  }

  /// The problems of [step], which [template], the template of a role,
  /// gives: those of the step and of its texts, a name that [names], the
  /// names of the steps that the template gave before, has, and texts that
  /// the app would read from the texts of the app though the template does
  /// not give them to the localization role, or gives it other texts of
  /// their names. The name of the step goes into [names].
  static List<String> _templateStepProblems(
    RoleHookInput<OnboardingData> input,
    OnboardingStep step,
    RoleTemplateOrigin template,
    Set<String> names,
  ) {
    final role = template.role;
    final who = 'The template of the $role';
    final what = 'the onboarding step "${step.name}"';
    final problems = [
      ...step.problems(),
      for (final text in step.shownTexts) ...text.problems(),
      if (!names.add(step.name))
        '$who gives two onboarding steps named "${step.name}".',
    ];
    if (!role.visibleRoles.contains(localizationRole)) {
      return problems
        ..add(
          '$who gives $what, whose texts an app with the $localizationRole '
          'reads from its texts, but the $role neither requires nor uses '
          'the $localizationRole, so it cannot give them. Add the '
          '$localizationRole to the uses of the $role, and give it the '
          'texts of the step.',
        );
    }
    if (!input.has(localizationRole)) return problems;
    for (final text in step.shownTexts) {
      final given = localizationRole.appTextOf(input, template, text)?.text;
      if (given == null) {
        problems.add(
          '$who gives $what the text "${text.name}", but not the '
          '$localizationRole, so the app would read a text that it lacks. '
          'Give the role the texts of the step too: '
          'localizationRole.data(TextsData([...]), when: '
          '{onboardingScreenRole}).',
        );
      } else if (!sameText(given, text)) {
        problems.add(
          '$who gives $what the text "${text.name}", and the '
          '$localizationRole a text of that name that differs from it. Give '
          'both roles the same text, such as one constant.',
        );
      }
    }
    return problems;
  }

  /// The steps of the app as the items of the list of
  /// [OnboardingScreenRole.stepsFile], with the imports of their icons and
  /// of the files of their functions, each with a prefix of the template's
  /// own, and the functions of their labels, each of which reads the text
  /// of the owner of the step from the texts of the app, or is its English
  /// text; see [LocalizationRole.expressionOf].
  @override
  RoleOutput render(RoleHookInput<OnboardingData> input) {
    // A function is in a file of the app, which its path identifies.
    final files = <String, ImportRef>{};
    String codeOf(FunctionRef function) => function.codeWith(
          files
              .putIfAbsent(
                function.import.uri,
                () => function.import.withPrefix('step${files.length}'),
              )
              .prefix,
        );
    final items = <String>[];
    final labels = <String>[];
    final iconImports = <ImportRef>[];
    final textImports = <ImportRef>[];
    final names = <String>{};
    for (final placed in onboardingScreenRole.stepsIn(input)) {
      final step = placed.step;
      final name = _labelPrefixOf(placed, names);
      String label(LocalizedText text, String suffix) {
        final function = '$name$suffix';
        final code = localizationRole.expressionOf(input, placed.owner, text);
        labels.add('String $function(BuildContext context) => ${code.code};');
        textImports.addAll(code.imports);
        return function;
      }

      final item = StringBuffer()
        ..writeln('  ${OnboardingScreenRole.step.name}(')
        ..writeln('    icon: ${step.icon.code},')
        ..writeln('    title: ${label(step.title, 'Title')},')
        ..writeln('    text: ${label(step.text, 'Text')},')
        ..writeln('    action: ${label(step.action, 'Action')},')
        ..writeln('    run: ${codeOf(step.run)},');
      if (step.later case final later?) {
        item.writeln('    later: ${label(later, 'Later')},');
      }
      if (step.showIf case final showIf?) {
        item.writeln('    showIf: ${codeOf(showIf)},');
      }
      items.add('$item  ),');
      iconImports.addAll(step.icon.imports);
    }
    return RoleOutput(
      vars: {
        'steps': Fragment(
          items.join('\n'),
          imports: [...iconImports, ...files.values],
        ),
        // A blank line before each function, the first after the list.
        'labels': Fragment(
          [for (final label in labels) '\n$label'].join('\n'),
          imports: textImports,
        ),
      },
    );
  }
}

/// The start of the names of the functions of the labels of [placed], a
/// step of the app, in [OnboardingScreenRole.stepsFile]: the id of its
/// owner and the name of the step in lowerCamelCase, after an underscore,
/// such as `_notificationsPermission`, and then a number if [names], the
/// names that the steps before have, has that name already, as when the
/// id of one owner continues in the name of its step to that of another.
/// The name goes into [names].
String _labelPrefixOf(AppOnboardingStep placed, Set<String> names) {
  final base = '_${SmfNames.lowerCamelCase(_idOf(placed.owner))}'
      '${SmfNames.upperCamelCase(placed.step.name)}';
  var name = base;
  for (var number = 2; !names.add(name); number++) {
    name = '$base$number';
  }
  return name;
}

/// The problems of the steps of the module of [input], which the module
/// rule `onboarding_screen.steps` reports: those of each step on its own,
/// those of its texts for the module (see
/// [LocalizationRole.dataTextProblems]), two steps of one name, and a
/// function in a file that the bricks of the module, those that apply in
/// the app, do not generate.
///
/// The template of the role checks the steps of the templates of roles.
List<SmfIssue> _checkSteps(ModuleRuleInput<OnboardingData> input) {
  final module = input.module;
  final origin = ModuleOrigin(module.id);
  final generated = textTemplatesOf(input.contributions);
  final names = <String>{};
  final issues = <SmfIssue>[];
  for (final data in input.data) {
    if (data.value case final OnboardingStep step) {
      issues.addAll([
        for (final problem in [
          ...step.problems(),
          for (final text in step.shownTexts)
            ...localizationRole.dataTextProblems(module, text),
          if (!names.add(step.name))
            'The module gives two onboarding steps named "${step.name}".',
        ])
          SmfIssue(problem, origin: origin),
        for (final function in step.functions)
          if (_fileOf(function) case final path?
              when !generated.containsKey(path))
            SmfIssue(
              'The function ${function.name} of the onboarding step '
              '"${step.name}" is in $path, which the bricks of the module '
              'do not generate.',
              hint: 'Generate the file of the function in a brick of the '
                  'module.',
              origin: origin,
              path: path,
            ),
      ]);
    }
  }
  return issues;
}

/// The problems of the routes that the module of [input] names as the
/// onboarding screen: only the provider of the role names one, exactly
/// one, which is a route of its own that needs no values.
List<SmfIssue> _checkRoute(ModuleRuleInput<OnboardingData> input) =>
    screenRouteIssues(
      input,
      onboardingScreenRole,
      [
        for (final data in input.data)
          if (data.value case OnboardingScreenRoute(:final name)) name,
      ],
      screen: _screen,
      routeClass: 'OnboardingScreenRoute',
    );

/// Whether [type], the return type of a function as written, is a
/// `Future`, such as `Future<void>` or `Future<bool>`, and not one that may
/// be `null`, such as `Future<void>?`, whose function the list of the steps
/// cannot take as the action of a step.
bool _isFuture(String? type) {
  final written = type?.replaceAll(RegExp(r'\s+'), '');
  return written != null &&
      !written.endsWith('?') &&
      (written == 'Future' || written.startsWith('Future<'));
}

/// The problems with the functions that the steps of [input] name: a
/// function in a file of another contributor, a function missing from its
/// file, one that requires arguments, and one that does not return what
/// the list of the steps takes, a `Future` for `run` and a `bool` for
/// `showIf`.
///
/// The template of the role and the module rule `onboarding_screen.steps`
/// report a function outside the app.
List<SmfIssue> _checkStepFunctions(StructuralRuleInput<OnboardingData> input) {
  final issues = <SmfIssue>[];
  for (final data in input.roleInput.data) {
    final origin = data.origin;
    if (data.value case final OnboardingStep step) {
      for (final (function, isRun) in [
        (step.run, true),
        if (step.showIf case final showIf?) (showIf, false),
      ]) {
        final path = _fileOf(function);
        if (path == null) continue;
        final owner = input.owners[path];
        if (owner != null && !isContributor(owner, origin)) {
          issues.add(
            SmfIssue(
              'The function ${function.name} of the onboarding step '
              '"${step.name}" of $origin is in $path, a file of $owner; a '
              'step calls functions of its own contributor.',
              origin: origin,
              path: path,
            ),
          );
          continue;
        }
        final symbol = RequiredFunction(
          function.name,
          path: path,
          returnType: isRun ? null : 'bool',
        );
        final hint = isRun
            ? 'The button of the action of a step calls run without '
                'arguments and awaits the future that it returns.'
            : 'The onboarding asks showIf without arguments whether it '
                'shows the step, and takes the answer at once.';
        final problems = [
          for (final issue in symbol.checkIn(input.files)) issue.message,
        ];
        final declaration = input.files[path]?.declaration(function.name);
        if (isRun &&
            declaration?.kind == DeclarationKind.function &&
            !_isFuture(declaration!.type)) {
          problems.add(
            '$symbol in $path must return a Future, not '
            '${declaration.type ?? 'an undeclared type'}.',
          );
        }
        for (final problem in problems) {
          issues.add(
            SmfIssue(problem, hint: hint, origin: origin, path: path),
          );
        }
      }
    }
  }
  return issues;
}

/// The problem of an app with onboarding steps whose provider does not
/// show them: none of the files of the provider reads
/// [OnboardingScreenRole.appOnboardingSteps] of
/// [OnboardingScreenRole.stepsFile].
///
/// The template of the role generates that list from the steps of the app,
/// in their order, each with its labels in the language of the app.
/// Whether the screen shows each step as the role says, only a running app
/// shows. Without the descriptor of a provider in [input], no file shows
/// the steps and there is nothing to check.
List<SmfIssue> _checkStepsShown(StructuralRuleInput<OnboardingData> input) {
  if (!input.roleInput.data.any((data) => data.value is OnboardingStep)) {
    return const [];
  }
  final providers = [
    for (final module in input.modules)
      if (module.provides.contains(onboardingScreenRole)) module.id,
  ];
  if (providers.isEmpty) return const [];
  final reads = input.files.entries.any(
    (file) => switch (input.owners[file.key]) {
      ModuleOrigin(:final module) when providers.contains(module) =>
        usesSymbols(
          file.value,
          {OnboardingScreenRole.appOnboardingSteps},
          OnboardingScreenRole.stepsFile,
        ),
      _ => false,
    },
  );
  if (reads) return const [];
  return [
    SmfIssue(
      'The provider of the $onboardingScreenRole does not show the steps '
      'of the onboarding: none of its files reads '
      '${OnboardingScreenRole.appOnboardingSteps} of '
      '${OnboardingScreenRole.stepsFile}.',
      hint: 'A provider shows each step of '
          '${OnboardingScreenRole.appOnboardingSteps} that its showIf keeps, '
          'on a page of its own, in the order of the list.',
      origin: ModuleOrigin(providers.first),
      path: onboardingScreenRole.screenIn(input.roleInput)?.route.screen.file,
    ),
  ];
}
