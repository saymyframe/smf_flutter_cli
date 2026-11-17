part of '../services.dart';

/// The review role; see [ReviewRole].
const reviewRole = ReviewRole._();

/// The role of the reviews of the app in its store: the review dialog of
/// the App Store or Google Play, which the app asks for when a review is
/// due, and the page of the app in its store.
///
/// The role's template generates these files, whichever module provides
/// the role:
/// - [serviceFile] with `ReviewService`, the interface that the provider
///   implements;
/// - [controllerFile] with `appReview`, the `AppReviewController` of the
///   app, `ReviewPolicy` with the numbers of when a review is due, and
///   `googlePlayId`, the application id of the app in Google Play.
///
/// The provider contributes its implementation of `ReviewService` as a
/// [RoleImplementation], created with the app or asynchronously. The role
/// registers nothing in a DI container: the code of an app uses
/// `appReview`, a top-level variable, and no module or template of another
/// role reaches the service of the provider.
///
/// The template also writes the section [readmeHeading] of the README of
/// the app, from its render hook, since the section tells of the guards of
/// the routes and of the entry of the settings screen, which depend on the
/// roles of the app. In the guide for coding agents of the app, the
/// template writes the note of the role under its description, and a note
/// of the entry of the settings screen in an app with the
/// [SettingsScreenRole]. It gives the [EnvRole] the key [appStoreIdKey],
/// and lists the step by hand [appStoreIdStep].
///
/// ## The request
///
/// The app asks for a review only where its code calls
/// `appReview.requestIfDue()`, at a natural break, such as when the user
/// has finished a task. The role asks for nothing on its own: the App Store
/// asks apps not to request a review when the user launches them. When a
/// review is due, the call asks the store for its own review dialog, and
/// the app shows nothing around it, as the stores ask: no question of its
/// own, no text and no screen. The store tells the app nothing of what the
/// user did, nor whether the dialog showed, so the call returns nothing,
/// and nothing in the app may depend on it.
///
/// A review is due once each of these holds:
/// - this launch is at least the third of the app (`ReviewPolicy.launches`),
///   and three days have passed since its first launch
///   (`ReviewPolicy.sinceFirstLaunch`);
/// - the app did not ask yet, or 14 days have passed since it last asked
///   (`ReviewPolicy.between`), also in a new version. A time of the last
///   request that is to come, as after the clock of the device went back,
///   counts as recent;
/// - the version of the app is known and is not the version in which the
///   app last asked, so the app asks at most once a version. The version
///   comes from `appVersion()` of the service, and an unknown one makes no
///   review due and prints a hint in debug mode;
/// - the store of the device can show the dialog (`isAvailable()` of the
///   service);
/// - the user is in no flow of a guard of the routes, such as the
///   onboarding or a sign-in, before the call asks the service and once
///   more right before it asks for the dialog.
///
/// The app counts its launches and remembers when it last asked, and in
/// which version, in the preferences, under [launchesKey],
/// [firstLaunchKey], [askedAtKey] and [askedVersionKey]. So the role
/// requires the [PreferencesRole]. `restoreReview`, the restorer that the
/// template puts into [PreferencesRole.restorers], reads them, and
/// `initReview()`, which `bootstrap()` awaits in its last phase
/// ([AppEntryRole.bootstrapLate]), creates the service with the provider's
/// function and starts `appReview` with it: the start counts this launch
/// and saves it. A request saves its time and its version once the service
/// completes it. A call while a request is on its way gets that request.
/// `requestIfDue()` never throws: an error of the service counts as no
/// dialog, prints in debug mode and saves nothing, so a later call asks
/// again.
///
/// The template knows the guards of the routes through what the
/// [RouterRole] publishes, which the role uses: in an app with guards, a
/// gate that does not allow keeps the user in its flow, and so does a
/// screen of the flow of any guard on top, which the template hears of
/// through a listener of [RouterRole.screenListeners]. In an app without
/// guards, no flow keeps the request back.
///
/// ## The page of the app in its store
///
/// `appReview.storePage()` is the page of the app in the store of the
/// platform: on Android the Google Play page of `googlePlayId`, the
/// application id of the flavor for a release
/// ([AppEntryRole.releaseFlavor]), also from a build of another flavor,
/// whose own id has no page there; on iOS the App Store page of the App
/// Store ID in [appStoreIdKey], which the role requires the [EnvRole] for.
/// The ID is all digits, and any other value counts as none, so an app
/// without it has no App Store page, and `appReview.hasStorePage` is
/// `false` on iOS. `storePage(review: true)` is the page on which the user
/// writes a review, which differs from the other page only on iOS.
/// `appReview.openStorePage()` opens the page outside the app through the
/// service, and returns whether an app of the device opened it, `false`
/// without a page, and never throws. So other code, such as a screen that
/// asks for an update, opens the store page without knowing a provider.
///
/// In an app with the [SettingsScreenRole], the template generates
/// [settingFile] with `ReviewSetting`, an entry of the settings screen that
/// opens the page for a review on a tap and never asks for the dialog:
/// Google Play forbids the dialog from a button and points a button to the
/// page. Its function `reviewSettingShows()` ([SettingsEntry.showIf]) shows
/// the entry only where the app has a store page. When no app of the device
/// opens the page, a snack bar says so. Its texts are [settingTitle] and
/// [settingFailed], texts of the template in English and in Ukrainian, which
/// it gives the [LocalizationRole] only in an app with a settings screen.
///
/// ## What a provider keeps to
///
/// The contract of `ReviewService` is in [serviceFile]. In short:
/// - the function of the implementation asks the user nothing, and may be
///   called again;
/// - `isAvailable` and `appVersion` never throw;
/// - `requestReview` asks the store for its dialog and shows nothing of
///   its own around it: no question, no text and no screen. It completes
///   once the store took the request, and throws when the platform refused
///   it;
/// - `openStorePage` opens exactly the page that it gets, outside the app,
///   and never throws.
///
/// Only a running app shows whether a provider keeps to it.
///
/// ## Rules
///
/// The structural rules of the role read the index and the text of each
/// Dart file of an app, so they see what a file itself imports, calls and
/// writes:
/// - `review.factory_calls`: no file of a module, and none of the template
///   of another role, calls `createReviewService()`, and of such files only
///   those of the provider's implementation, the files of its class and of
///   its function, import or export [serviceFile];
/// - `review.start_calls`: only the file of `bootstrap()` calls
///   `initReview()`, and no file of a module or of the template of another
///   role calls `appReview.start()`, which `initReview()` and tests call;
/// - `review.implementation_factories`: the function of the implementation
///   is in its file and takes no arguments;
/// - `review.requests`: no file of a module, and none of the template of
///   another role, calls `appReview.requestIfDue()` or tears it off, as the
///   callback of a button does, or has one of the keys of the role as a
///   string. So no module asks for a review in a flow of its own or from a
///   button, or puts something of its own around the request, and none
///   reads or writes what the role keeps. The code of the app asks at a
///   natural break of its own.
///
/// They do not see a `part` file of a library that imports
/// [controllerFile], a file that reaches [controllerFile] through an export
/// of another file of the app, `appReview` under another name, or a key that
/// a file builds from parts. Nor do they see a question that the code of the
/// app puts around the request, which the README of the app and the guide
/// for coding agents forbid.
///
/// ## Tests
///
/// A test creates an `AppReviewController` of its own, with a clock of its
/// own and a function that gives the App Store ID, gives it the
/// preferences with `restore()`, and starts it with a service of its own,
/// which scripts what a provider answers. A test runs `initPreferences()`
/// and `initReview()` again to see what the next launch of the app finds,
/// after it saved a state of its own under the keys of the role through
/// the preferences.
///
/// The mocks of the platform side of every provider, with which the tests
/// of the apps run, keep to one convention, so that the tests of the role
/// hold with each: the store of the device can show the dialog, a request
/// completes at once and shows nothing, a page opens, and the version of
/// the app is `1.0.0`.
final class ReviewRole extends Role<RoleImplementation> {
  const ReviewRole._();

  /// The path of the file with `ReviewService`, which the provider
  /// implements.
  static const serviceFile = 'lib/core/review/review_service.dart';

  /// The path of the file with `appReview`, which the code of the app uses.
  static const controllerFile = 'lib/core/review/app_review.dart';

  /// The path of the file with `ReviewSetting`, the entry of the settings
  /// screen, and `reviewSettingShows()`, which only an app with the
  /// [SettingsScreenRole] has. So it is no file of the [interface] of the
  /// role: the provider of the settings screen creates the entry, and no
  /// other code names it.
  static const settingFile = 'lib/core/review/review_setting.dart';

  /// The heading of the section of the README of the app in which the
  /// template tells how the app asks for a review. The section of a
  /// provider can refer to it.
  static const readmeHeading = 'Store reviews';

  /// The key of the App Store ID of the app, its Apple ID in App Store
  /// Connect, which the App Store page of the app takes.
  static const appStoreIdKey = EnvKey(
    'REVIEW_APP_STORE_ID',
    description: 'The App Store ID of the app, its Apple ID in App Store '
        'Connect, such as 1234567890',
  );

  /// The step by hand in which the developer of the app copies the App
  /// Store ID of the app into `.env`, without which the app has no App Store
  /// page.
  static const appStoreIdStep = ManualStep(
    ManualStepId.role(reviewRole, 'app_store_id'),
    'Copy the App Store ID of the app from App Store Connect into .env',
  );

  /// The key of the preferences under which the app counts its launches, as
  /// an `int`, this one included. The file of the role keeps the keys to
  /// itself, so a test of an app takes them from here.
  static const launchesKey = 'review.launches';

  /// The key of the preferences under which the app remembers the time of
  /// its first launch, as an `int` of the milliseconds since the epoch, in
  /// UTC.
  static const firstLaunchKey = 'review.first_launch';

  /// The key of the preferences under which the app remembers the time of
  /// its last request for a review, as an `int` of the milliseconds since
  /// the epoch, in UTC.
  static const askedAtKey = 'review.asked_at';

  /// The key of the preferences under which the app remembers the version
  /// of the app in which it last asked for a review, as a `String`.
  static const askedVersionKey = 'review.asked_version';

  /// The keys of the preferences that the role keeps, which no module reads
  /// or writes (the rule `review.requests`).
  static const List<String> keys = [
    launchesKey,
    firstLaunchKey,
    askedAtKey,
    askedVersionKey,
  ];

  /// The title of the entry of the settings screen, a text of the template
  /// of the role in an app with a settings screen.
  static const settingTitle = LocalizedText(
    'settingTitle',
    en: 'Rate the app',
    translations: {'uk': 'Оцінити застосунок'},
  );

  /// What the entry shows when no app of the device opened the page of the
  /// app in its store.
  static const settingFailed = LocalizedText(
    'settingFailed',
    en: "Couldn't open the store.",
    translations: {'uk': 'Не вдалося відкрити магазин.'},
  );

  /// The implementation of `ReviewService`, which the template renders
  /// from the provider's [RoleImplementation]; modules do not contribute
  /// to it.
  static const implementations = SocketRef<CodeSocket>.role(
    reviewRole,
    'implementations',
    CodeSocket(),
  );

  @override
  String get id => 'review';

  @override
  String get description => 'Store reviews';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  /// The preferences, which count the launches and remember the last
  /// request, and the values of the app, of which the App Store ID is one.
  @override
  Set<Role> get requires => {preferencesRole, envRole};

  /// The router, whose guards keep the request out of their flows, the
  /// settings screen, to which the template gives the entry that opens the
  /// page of the app in its store, and the languages of the app, in which
  /// that entry shows its texts.
  @override
  Set<Role> get uses => {routerRole, settingsScreenRole, localizationRole};

  @override
  List<SocketRef> get sockets => const [implementations];

  @override
  RoleInterface get interface => const RoleInterface(
        files: [serviceFile, controllerFile],
      );

  @override
  RoleTemplate<RoleImplementation> get template => const _ReviewTemplate();

  @override
  List<ModuleRule<RoleImplementation>> get moduleRules =>
      const [_implementationsRule];

  @override
  List<StructuralRule<RoleImplementation>> get structuralRules => const [
        StructuralRule(
          id: 'review.factory_calls',
          description: 'No module calls createReviewService(), and only the '
              'files of the implementation of the provider import the file '
              'of ReviewService: the code of the app asks for a review '
              'through appReview.',
          check: _checkReviewService,
        ),
        StructuralRule(
          id: 'review.start_calls',
          description: 'Only bootstrap() calls initReview(), and no module '
              'calls appReview.start().',
          check: _checkReviewStart,
        ),
        StructuralRule(
          id: 'review.implementation_factories',
          description: 'The function of every implementation is in its file '
              'and takes no arguments.',
          check: _checkImplementationFactories,
        ),
        StructuralRule(
          id: 'review.requests',
          description: 'No module calls or tears off '
              'appReview.requestIfDue(), or has a key of the role as a string: '
              'the code of the app asks for a review at a natural break of its '
              'own, and the role keeps its state to itself.',
          check: _checkReviewRequests,
        ),
      ];
}

/// The problems with the service of the provider in [input]; see
/// [_checkServiceReach].
///
/// Code that reached the service would ask the store around `appReview`,
/// which is what decides whether a review is due.
List<SmfIssue> _checkReviewService(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkServiceReach(
      input,
      factory: 'createReviewService',
      service: 'ReviewService',
      serviceFile: ReviewRole.serviceFile,
      controllerFile: ReviewRole.controllerFile,
      hint: 'Open the page of the app in its store with appReview of '
          '${ReviewRole.controllerFile}.',
    );

/// The problems with the start of `appReview` in [input]; see
/// [_checkControllerStart].
List<SmfIssue> _checkReviewStart(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkControllerStart(
      input,
      init: 'initReview',
      controller: 'appReview',
      controllerFile: ReviewRole.controllerFile,
      hint: 'The role starts the reviews in bootstrap(), which counts each '
          'launch of the app.',
    );

/// The problems of the files of modules, and of the templates of other
/// roles, in [input] that ask for a review or touch what the role keeps:
/// a Dart file that calls `appReview.requestIfDue()` or tears it off, or
/// that has a key of the role as a string ([ReviewRole.keys]).
///
/// The code of the app asks at a natural break of its own, which no module
/// knows, and nothing in the app may depend on what the role keeps. A file
/// of the template of the role itself has the keys, which it keeps.
List<SmfIssue> _checkReviewRequests(
  StructuralRuleInput<RoleImplementation> input,
) {
  const hint = 'The code of the app asks for a review at a natural break of '
      'its own, and the role keeps its state to itself.';
  final issues = <SmfIssue>[];
  for (final MapEntry(key: path, value: index) in input.files.entries) {
    final owner = input.owners[path];
    if (!_usesController(owner, reviewRole)) continue;
    final String use;
    if (invokesOn(
      index,
      'appReview',
      'requestIfDue',
      ReviewRole.controllerFile,
    )) {
      use = 'calls appReview.requestIfDue()';
    } else if (readsOn(
      index,
      'appReview',
      'requestIfDue',
      ReviewRole.controllerFile,
    )) {
      // A tear-off, such as the callback of a button, asks when it is
      // called.
      use = 'tears off appReview.requestIfDue';
    } else {
      continue;
    }
    issues.add(
      SmfIssue(
        '$path $use, which no module calls.',
        hint: hint,
        origin: owner,
        path: path,
      ),
    );
  }
  for (final MapEntry(key: path, value: text) in input.texts.entries) {
    final owner = input.owners[path];
    if (!path.endsWith('.dart') || !_usesController(owner, reviewRole)) {
      continue;
    }
    for (final key in ReviewRole.keys) {
      if (!text.contains("'$key'") && !text.contains('"$key"')) continue;
      issues.add(
        SmfIssue(
          '$path has the key $key of the review role, which the role keeps '
          'to itself.',
          hint: hint,
          origin: owner,
          path: path,
        ),
      );
    }
  }
  return issues;
}

/// The texts of the entry of the settings screen, each with the variable
/// of its brick that reads it.
const Map<String, LocalizedText> _reviewSettingTexts = {
  'text_title': ReviewRole.settingTitle,
  'text_failed': ReviewRole.settingFailed,
};

/// The file of `appReview`, as code imports it.
const _reviewImport = ImportRef.app('core/review/app_review.dart');

/// The file of the entry of the settings screen, as code imports it.
const _reviewSettingImport = ImportRef.app('core/review/review_setting.dart');

/// The listener of the screen that the template gives the router in an app
/// with guards, so that the app asks for no review in the flow of a guard.
const _screenListener = 'noteScreenForReview';

/// The code of the controller that tells whether the user is in the flow
/// of a guard of the routes in the app of [input]: in an app with guards,
/// a gate that does not allow, or a screen on top that is in the flow of a
/// guard, which the listener of the screen notes; and never in an app
/// without guards, a router included.
Object _guardFlowsOf(RoleHookInput<RoleImplementation> input) {
  final guarded =
      input.has(routerRole) && routerRole.facadeOf(input).guards.isNotEmpty;
  if (!guarded) {
    return '''
/// Whether the user is in the flow of a guard of the routes: never, since
/// the app has no guards.
bool _inAGuardFlow() => false;''';
  }
  return const Fragment(
    '''
/// The full name of the route of the screen that the user sees, as the
/// router last told [$_screenListener], or `null` before the first screen
/// and for a screen that is no route of a module.
String? _screen;

/// A listener of the screen that the user sees, which the router calls:
/// it notes the route of the screen, so that the app asks for no review in
/// the flow of a guard of the routes.
void $_screenListener(String? route, String location) => _screen = route;

/// Whether the user is in the flow of a guard of the routes, such as the
/// onboarding or a sign-in: a gate that does not allow keeps the user in
/// its flow, and the screen on top may be a route of the flow of a guard,
/// such as one that a guard of a condition opened over a page.
bool _inAGuardFlow() => ${RouterRole.routeGuards}.any(
      (guard) =>
          (guard.routes == null && !guard.allows.value) ||
          guard.flow.contains(_screen),
    );''',
    imports: [ImportRef.app('core/router/app_router.dart')],
  );
}

/// The section of the role in the README of an app: where the app asks for
/// a review and how, when a review is due, what the stores forbid, when
/// the dialog shows, the page of the app in its store and, in an app with
/// a settings screen, the entry that opens it. It holds with every provider
/// and names none. [googlePlayId] is the application id of the app in
/// Google Play.
String _reviewReadme({
  required String googlePlayId,
  required bool guards,
  required bool settings,
}) {
  final flows = guards
      ? ' It is never due in the flow of a guard of the routes, such as the '
          'onboarding or a sign-in.'
      : '';
  final entry = settings
      ? '\n\nThe entry `ReviewSetting` of the settings screen, in '
          '`${ReviewRole.settingFile}`, opens the page for a review, and '
          'shows only where the app has a store page. It never asks for the '
          'review dialog.'
      : '';
  return '''
The app asks for a review only where its code calls `appReview.requestIfDue()` of `${ReviewRole.controllerFile}`. Call it at a natural break, such as when the user has finished a task:

```dart
await saveNote(note);
unawaited(appReview.requestIfDue());
```

When a review is due, the call asks the App Store or Google Play for its own review dialog, and the app shows nothing around it. It returns nothing: the store tells no app whether the dialog showed or what the user did, so nothing in the app may depend on it. Never call it from a button, and never after a question of your own, such as "Do you like the app?": Google Play forbids both, and the App Store allows no prompt but its own.

A review is due as `ReviewPolicy` in that file says: from the third launch of the app (`ReviewPolicy.launches`), three days after its first launch (`ReviewPolicy.sinceFirstLaunch`), and at most once a version of the app and once in 14 days (`ReviewPolicy.between`). Change the numbers there.$flows The app counts its launches and remembers its last request in the preferences, under the keys `review.*`, so write nothing there.

The store decides whether the dialog shows. iOS shows it in a debug build each time, never in TestFlight, and at most three times in 365 days. Google Play shows it only in an app that it installed, such as from an internal test track. On a device without the review service of Google Play, such as an emulator without the Play Store, the store cannot take the request and the app records nothing, so the next call of `appReview.requestIfDue()` asks again, also in the same launch. On a device with the Play Store, for an app that Google Play did not install, such as a local build, the request completes and shows nothing, and the app counts it as a request, so it does not ask again in that version of the app.

`appReview.openStorePage()` opens the page of the app in its store, and `appReview.openStorePage(review: true)` the page where the user writes a review. On Android that is the Google Play page of `$googlePlayId` (`googlePlayId`), the id of the flavor for a release, also from a build of another flavor. On iOS it is the App Store page of `${ReviewRole.appStoreIdKey.name}` in `.env`, the Apple ID of the app in App Store Connect. While that key is empty, the app has no App Store page, and `appReview.hasStorePage` is `false` on iOS.$entry
''';
}

/// What the role adds to its note in an app with a settings screen: the
/// entry that opens the page of the app in its store, which only such an
/// app has.
const String _reviewSettingAgentNote = '''
- `ReviewSetting` in `${ReviewRole.settingFile}`, an entry of the settings screen, opens the page of the app in its store for a review. It shows only where the app has a store page, and it never asks for the review dialog.
''';

/// The template of the [ReviewRole]: the files of the role, the
/// implementation of the provider and the start of the reviews in
/// `bootstrap()`, the restorer of what the role keeps, the key of the App
/// Store ID and its step by hand, the entry of the settings screen with its
/// texts, the section of the role in the README of the app and its notes
/// for coding agents.
final class _ReviewTemplate extends _ServiceTemplate<RoleImplementation> {
  const _ReviewTemplate();

  @override
  Role<RoleImplementation> get role => reviewRole;

  @override
  MasonBundle get bundle => reviewRoleBundle;

  @override
  String get file => ReviewRole.controllerFile;

  @override
  String get service => 'ReviewService';

  @override
  String get factory => 'createReviewService';

  @override
  String get initFunction => 'initReview';

  @override
  String get variable => '_reviewService';

  @override
  SocketRef<CodeSocket> get implementations => ReviewRole.implementations;

  /// `initReview()` counts the launch once the services of the app are
  /// ready, in the last phase of `bootstrap()`.
  @override
  SocketRef<CodeSocket> get _bootstrapSocket => AppEntryRole.bootstrapLate;

  /// The note of the role in the guide for coding agents: where the code of
  /// an app asks for a review, when a review is due, what the stores
  /// forbid, how the app opens its store page, and which functions and keys
  /// of the role are not for the code of the app.
  @override
  String get agentNote => '''
- `appReview` in `$file` asks for the review dialog of the App Store or Google Play only where the code of the app calls `appReview.requestIfDue()`. Call it at a natural break, such as after the user has finished a task: `unawaited(appReview.requestIfDue());`. It asks only when `ReviewPolicy` says that a review is due: never on the first launch, in the flow of a guard of the routes, twice in a version or twice in 14 days. It returns nothing, since the store tells nothing.
- Never call it from a button or after a question of your own, and show nothing around the dialog. Nothing in the app may depend on whether the app asked.
- `appReview.openStorePage()` opens the page of the app in its store, and `appReview.openStorePage(review: true)` the page for a review. `appReview.hasStorePage` tells whether there is one: on iOS only once `${ReviewRole.appStoreIdKey.name}` in `.env` has the App Store ID. The Google Play page is that of `googlePlayId`, the id of the flavor for a release, also from a build of another flavor.
- A new provider implements `$service` of `${ReviewRole.serviceFile}`, and only the files of that implementation import it. The code of the app calls neither `$initFunction()`, `$factory()` nor `appReview.start()`, and writes nothing under the keys `review.*`.
''';

  /// The bricks, the restorer, the key of the App Store ID and its step by
  /// hand, the entry with its texts, and the notes of the role. The role
  /// registers nothing in a DI container: the code of an app uses
  /// `appReview`, not the service of the provider.
  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bundle),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(agentNote),
        ),
        SocketContribution.item(
          PreferencesRole.restorers,
          Fragment('restoreReview', imports: [import]),
        ),
        envRole.data(ReviewRole.appStoreIdKey),
        ReviewRole.appStoreIdStep,
        // Only an app with a settings screen gets the entry and its texts.
        BrickContribution(
          reviewRoleSettingBundle,
          when: const {settingsScreenRole},
        ),
        settingsScreenRole.data(
          const SettingsEntry(
            widget: TypeRef('ReviewSetting', import: _reviewSettingImport),
            showIf: FunctionRef(
              'reviewSettingShows',
              import: _reviewSettingImport,
            ),
          ),
        ),
        localizationRole.data(
          TextsData([..._reviewSettingTexts.values]),
          when: const {settingsScreenRole},
        ),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(_reviewSettingAgentNote),
          when: const {settingsScreenRole},
        ),
      ];

  /// The implementation, the listener of the screen in an app with guards
  /// of the routes, the section of the role in the README of the app, and
  /// the variables of the bricks: the keys of the role, the application id
  /// of the app in Google Play, the code that tells whether the user is in
  /// the flow of a guard, and the code that reads each text of the entry of
  /// the settings screen.
  @override
  RoleOutput render(RoleHookInput<RoleImplementation> input) {
    final googlePlayId = AppEntryRole.releaseFlavor.applicationIdIn(
      input.appIdentity,
    );
    final guardFlows = _guardFlowsOf(input);
    final guards = guardFlows is Fragment;
    return RoleOutput(
      fragments: [
        ...super.render(input).fragments,
        if (guards)
          const SocketContribution.item(
            RouterRole.screenListeners,
            Fragment(_screenListener, imports: [_reviewImport]),
          ),
        AppEntryRole.readmeSections.entry(
          ReviewRole.readmeHeading,
          _reviewReadme(
            googlePlayId: googlePlayId,
            guards: guards,
            settings: input.has(settingsScreenRole),
          ),
        ),
      ],
      vars: {
        'launches_key': SmfNames.dartString(ReviewRole.launchesKey),
        'first_launch_key': SmfNames.dartString(ReviewRole.firstLaunchKey),
        'asked_at_key': SmfNames.dartString(ReviewRole.askedAtKey),
        'asked_version_key': SmfNames.dartString(ReviewRole.askedVersionKey),
        'google_play_id': SmfNames.dartString(googlePlayId),
        'guard_flows': guardFlows,
        for (final MapEntry(key: variable, value: text)
            in _reviewSettingTexts.entries)
          variable: localizationRole.expressionOf(
            input,
            const RoleTemplateOrigin(reviewRole),
            text,
          ),
      },
    );
  }

  /// `bootstrap()` always awaits `initReview()`, which also starts
  /// `appReview`, whether the implementation is created asynchronously or
  /// not.
  @override
  String bootstrap({required bool hasAsync}) => 'await $initFunction();';

  /// The service of the provider, and `initReview()`, which creates it with
  /// the only implementation in [all] and starts `appReview` with it.
  ///
  /// It may run again, so the variable is not final.
  @override
  String _single(
    List<_Prefixed> all,
    RoleHookInput<RoleImplementation> input,
  ) {
    final (:implementation, :prefix) = all.single;
    final factory = implementation.factory.codeWith(prefix);
    final create = implementation.isAsync ? 'await $factory()' : '$factory()';
    return '''
late $service $variable;

/// Creates the service of the provider of the reviews and starts
/// [appReview] with it, which counts this launch of the app; `bootstrap()`
/// awaits it in its last phase, and nothing else in the app calls it.
///
/// It may run again, as a test does to see what the next launch of the app
/// finds: it creates the service anew and starts [appReview] with it.
Future<void> $initFunction() async {
  $variable = $create;
  await appReview.start($variable);
}''';
  }
}
