/// Providers of roles with one known bug each, for the tests of the SMF
/// pipeline. Not modules to use.
///
/// A test of a role that passes whatever the provider of the role does
/// checks nothing. So the fixture registry generates an app with each of
/// these providers and runs the tests of its role there, which must fail on
/// its bug, and on nothing else (`brokenProviders` of `fixture_registry`).
/// Each keeps the rules of its role that the contract harness checks, since
/// the harness renders its app first: only a running app shows its bug.
/// None is in a registry of apps that must work.
library;

import 'dart:convert';

import 'package:fake_broken/bundles/broken_layout_bundle.dart';
import 'package:fake_broken/bundles/broken_layout_labels_bundle.dart';
import 'package:fake_broken/bundles/broken_settings_bundle.dart';
import 'package:fake_di/fake_di.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fake_router/fake_router.dart';
import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// A module with one known bug, which a change of the code that it renders
/// brings in: the rest of it is the module [of], under another id. The
/// module [of] has no sockets of its own, which would be those of its id.
/// The texts that [of] gives the localization role are texts of this
/// module, so the variables of its bricks that read them
/// ([LocalizationRole.varsOf]) read them under the id of this module.
///
/// The broken modules of this package change fixture modules. The package
/// depends on no module of the CLI, so that the app tests of the fixture
/// registry, which may use what the fixture modules generate, know none of
/// those either. A package that depends on such a module makes a broken
/// one of it itself, with [BrokenModule.new].
final class BrokenModule extends SmfModule {
  /// Creates the module [id], which [description] describes: the module
  /// [of] under that id, with the [changes] of its file [file], the path
  /// of a file of one of its bricks. Each change is a text that the file
  /// has once, and the text that takes its place.
  const BrokenModule(
    SmfModule of, {
    required ModuleId id,
    required String description,
    required String file,
    required List<(String, String)> changes,
  }) : this._(of, id, description, file, changes);

  const BrokenModule._(
    this.of,
    this.id,
    this._description,
    this._file,
    this._changes,
  );

  /// The fake router that tells the listeners of the screen of the page on
  /// top each time it builds its navigator, though the page on top did not
  /// change: it keeps no note of the page that they heard of last.
  static const routerRepeatingScreens = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_repeats_screens'),
    'A plain navigator that repeats the screen (fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '  /// The page on top, as the listeners of the screen last heard of '
            'it, or\n'
            '  /// `null` before the first screen; see [_top].\n'
            '  (int, AppLocation?)? _shown;\n'
            '\n',
        '',
      ),
      ('    if (top == _shown) return;\n    _shown = top;\n', ''),
    ],
  );

  /// The fake router that calls the listeners of the screen one after
  /// another, rather than each on its own: a listener that throws keeps the
  /// listeners after it from hearing the screen, and what it throws reaches
  /// the handlers of the errors of the app.
  static const routerStoppingAtThrowingListener = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_stops_at_throwing_listener'),
    'A plain navigator whose listeners of the screen fail together (fixture)',
    RouterRole.appRouterFactoryFile,
    [
      ("import 'package:flutter/foundation.dart';\n", ''),
      (_callsListenerAlone, _callsListener),
    ],
  );

  /// How the fake router calls a listener of the screen on its own.
  static const _callsListenerAlone = '      try {\n'
      '  $_callsListener'
      '      } on Object catch (error) {\n'
      '        if (kDebugMode) '
      "debugPrint('A listener of the screen failed: "
      r"$error');"
      '\n'
      '      }\n';

  /// How a router calls a listener of the screen.
  static const _callsListener =
      "      listener(location?.routeName, location?.path ?? '/');\n";

  /// The fake router that pushes a location in the main navigation over a
  /// page shown over the main navigation, rather than refusing it with a
  /// `StateError`.
  static const routerPushingOverMainNavigation = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_pushes_over_main_navigation'),
    'A plain navigator that pushes under a page over its tabs (fixture)',
    RouterRole.appRouterFactoryFile,
    [("    _checkMainNavigation(location, branch, 'push');\n", '')],
  );

  /// The fake router that creates its configuration anew each time the
  /// configuration is read, rather than once.
  static const routerCreatingConfigAgain = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_creates_config_again'),
    'A plain navigator with a new configuration each time (fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '  late final RouterConfig<Object> config = RouterConfig(',
        '  RouterConfig<Object> get config => RouterConfig(',
      ),
    ],
  );

  /// The fake router that shows the screen of the first destination of the
  /// main navigation in the page of each top-level route outside the main
  /// navigation, which it names after the route of the page as it should: a
  /// route builds the screen of another route.
  static const routerShowingAnotherScreen = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_shows_another_screen'),
    'A plain navigator that shows the screen of another route (fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '          child: _screen(location),\n',
        '          child: _screen(\n'
            '            location.parent == null &&\n'
            '                    _destinations.isNotEmpty &&\n'
            '                    !_destinations.any(\n'
            '                      (destination) =>\n'
            '                          destination.routeName == '
            'location.routeName,\n'
            '                    )\n'
            '                ? _destinations.first\n'
            '                : location,\n'
            '          ),\n',
      ),
    ],
  );

  /// The fake router that asks the guards of the routes about the screen
  /// that the app starts on, and again when one of them starts or stops
  /// allowing, but not about the locations that `go()`, `push()` and
  /// `replace()` are asked to show: it shows a location that a guard keeps
  /// the user from, and one in a flow that is over.
  static const routerAskingGuardsOnlyAtStart = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_asks_guards_at_start'),
    'A plain navigator that asks the guards only as it starts (fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '  WhenAsked<AppLocation?>? _asked(AppLocation location) => '
            '_guards.asked(\n'
            '        location.routeName,\n'
            '        location,\n'
            '        onTopOf: [for (final page in _pages) page.route],\n'
            '      );\n',
        '  WhenAsked<AppLocation?>? _asked(AppLocation location) => null;\n',
      ),
    ],
  );

  /// The fake router that tells the guards of the routes of its pages when
  /// one of them starts or stops allowing, and does not show what they
  /// answer. So the target of a guard stays once the guard allows, and the
  /// pages of the stack stay when a guard stops allowing.
  static const routerIgnoringGuardChanges = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_ignores_guard_changes'),
    'A plain navigator that ignores the changes of the guards (fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '    switch (_guards.changed(_pages)) {\n'
            '      case null:\n'
            '        break;\n'
            '      case ShowInstead(:final location):\n'
            '        _go(location);\n'
            '      case ClosePages(:final pages, :final dropsRequest):\n'
            '        _close(pages, dropsRequest: dropsRequest);\n'
            '    }\n',
        // It still tells an answer that closes pages from the others, and
        // closes none of them.
        '    if (_guards.changed(_pages) is ClosePages<AppLocation?>) {\n'
            '      _close(0, dropsRequest: false);\n'
            '    }\n',
      ),
    ],
  );

  /// The fake router whose `replace()` asks the guards of the routes about
  /// its location, and leaves the stack as it is when they answer another
  /// location, rather than showing that location in place of the whole
  /// stack. When a guard keeps the user from the location, the user stays
  /// on a page of the flow that is not the target. And for a location in a
  /// flow that is over, the user stays on the page that they are on, not
  /// on the screen that the app starts on.
  static const routerKeepingPageOnGuardedReplace = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_keeps_page_on_guarded_replace'),
    'A plain navigator whose guarded replace() shows nothing (fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '    {{#guards}}if (_redirected(location, again: () => '
            'replace(location))) return;\n'
            '    {{/guards}}final branch = _branchOf(location);\n'
            "    _checkMainNavigation(location, branch, 'replace');\n",
        '    {{#guards}}if (_asked(location) != null) return;\n'
            '    {{/guards}}final branch = _branchOf(location);\n'
            "    _checkMainNavigation(location, branch, 'replace');\n",
      ),
    ],
  );

  /// The fake router that, when it shows the location that the guards of
  /// the routes answer, puts the branches of the main navigation back on
  /// their destinations, but for the selected one, which keeps its pages.
  /// A location that brings the user back into that branch makes its stack
  /// anew, so the bug shows only when the user comes back somewhere else,
  /// as after a guard that does not bring the user back: the branch then
  /// still has a page that the guard kept the user from.
  static const routerKeepingSelectedBranch = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_keeps_selected_branch'),
    'A plain navigator whose guards leave the selected branch (fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '    for (final (index, branch) in _branches.indexed) {\n'
            '      branch\n'
            '        ..clear()\n'
            '        ..add(_destinations[index]);\n'
            '    }\n'
            '    if (location != null) _show(location);\n',
        '    for (final (index, branch) in _branches.indexed) {\n'
            '      if (index == _selected) continue;\n'
            '      branch\n'
            '        ..clear()\n'
            '        ..add(_destinations[index]);\n'
            '    }\n'
            '    if (location != null) _show(location);\n',
      ),
    ],
  );

  /// The fake router that tells the guards of the routes of a page that a
  /// push showed under the route of the location below the pushed pages,
  /// not under its own. A gate keeps the user from every route outside its
  /// flow, so its answer is the same. A guard that stands for a condition
  /// keeps the user only from the routes that ask for it: when the
  /// condition stops holding, a pushed page that asks for it stays if the
  /// page below asks for nothing.
  static const routerNamingPushedPagesAfterPageBelow = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_names_pushed_pages_after_page_below'),
    'A plain navigator that names a pushed page after the page below it '
    '(fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '            (\n'
            '              route: location.routeName,\n'
            '              location: location,\n'
            '              pushed: _results.containsKey(location),\n'
            '            ),\n'
            '        if (_overFallback) (route: null, location: null, '
            'pushed: false),\n'
            '      ];\n',
        '            (\n'
            '              route: _results.containsKey(location)\n'
            '                  ? _belowPushed?.routeName\n'
            '                  : location.routeName,\n'
            '              location: location,\n'
            '              pushed: _results.containsKey(location),\n'
            '            ),\n'
            '        if (_overFallback) (route: null, location: null, '
            'pushed: false),\n'
            '      ];\n'
            '\n'
            '  /// The location below the pages that pushes showed, or `null` '
            'if\n'
            '  /// pushes showed every page.\n'
            '  AppLocation? get _belowPushed {\n'
            '    for (final entry in _stack.reversed) {\n'
            '      final locations = entry is AppLocation\n'
            '          ? [entry]\n'
            '          : _branches[_selected].reversed;\n'
            '      for (final location in locations) {\n'
            '        if (!_results.containsKey(location)) return location;\n'
            '      }\n'
            '    }\n'
            '    return null;\n'
            '  }\n',
      ),
    ],
  );

  /// The fake router that asks the guards of the routes about a location
  /// that `go()`, `push()` or `replace()` is asked to show by the name of
  /// its top-level route, not by that of its own route. The flow of a
  /// guard is a top-level route with the routes below it, so a gate
  /// answers the same. A guard that stands for a condition does not: a
  /// route that asks for the condition below a route that asks for
  /// nothing shows to everyone.
  static const routerAskingAboutTopLevelRoute = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_asks_about_top_level_route'),
    'A plain navigator that asks the guards about the top-level route '
    '(fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '  WhenAsked<AppLocation?>? _asked(AppLocation location) => '
            '_guards.asked(\n'
            '        location.routeName,\n',
        '  WhenAsked<AppLocation?>? _asked(AppLocation location) => '
            '_guards.asked(\n'
            '        location.chain.first.routeName,\n',
      ),
    ],
  );

  /// The fake router that shows the target of a guard that stands for a
  /// condition in place of its whole stack, as it shows the target of a
  /// gate, where the guards answer to show it over the page on top, and
  /// that keeps no request waiting. So the user cannot go back from the
  /// target to the page that they were on, and nothing happens once the
  /// condition holds but that the flow, which is over, leaves for the
  /// screen that the app starts on.
  static const routerShowingFlowInPlace = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_shows_flow_in_place'),
    'A plain navigator that opens the flow of a condition in place of its '
    'stack (fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '      case ShowOver(location: final target, :final flow):\n'
            '        _drop();\n'
            '        _stack.add(target!);\n'
            '        _results[target] = Completer<Object?>();\n'
            '        _waiting = (flow: flow, again: again, drop: drop);\n'
            '        notifyListeners();\n',
        '      case ShowOver(location: final target):\n'
            '        _go(target);\n'
            '        drop?.call();\n',
      ),
    ],
  );

  /// The fake router that opens the target of a guard that stands for a
  /// condition over the page on top and keeps the request waiting, but
  /// drops the request when the guards close the pages of the flow, rather
  /// than making it again. So once the condition holds, the user is back on
  /// the page that the flow was opened over, the location that was asked
  /// for does not show, and a `push()` that waited completes with `null`.
  static const routerForgettingWaitingRequest = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_forgets_waiting_request'),
    'A plain navigator that forgets the request that waits for a flow '
    '(fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '      } else {\n'
            '        waiting.again();\n'
            '      }\n',
        '      } else {\n'
            '        waiting.drop?.call();\n'
            '      }\n',
      ),
    ],
  );

  /// The fake router that, when it shows the location that the guards of
  /// the routes answer, leaves the pages of the branches of the main
  /// navigation where they are, and takes them when it next builds its
  /// pages without the main navigation, as a router does that keeps the
  /// pages of the branches with the page of the main navigation. A branch
  /// that the user does not come back to is on its destination once a
  /// frame showed the target of a guard. But when the guard stops allowing
  /// and allows again in one turn, no frame shows the target, and that
  /// branch still has a page that the guard kept the user from.
  static const routerKeepingBranchesForAFrame = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_keeps_branches_for_a_frame'),
    'A plain navigator whose guards take the branches at a frame (fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '    _stack.clear();\n'
            '    for (final (index, branch) in _branches.indexed) {\n'
            '      branch\n'
            '        ..clear()\n'
            '        ..add(_destinations[index]);\n'
            '    }\n'
            '    if (location != null) _show(location);\n',
        '    _stack.clear();\n'
            '    if (location != null) _show(location);\n',
      ),
      (
        '  Widget build(BuildContext context) {\n'
            '    _showScreen();\n',
        '  Widget build(BuildContext context) {\n'
            '    if (!_stack.contains(_mainNavigation)) {\n'
            '      for (final (index, branch) in _branches.indexed) {\n'
            '        branch\n'
            '          ..clear()\n'
            '          ..add(_destinations[index]);\n'
            '      }\n'
            '    }\n'
            '    _showScreen();\n',
      ),
    ],
  );

  /// The fake router that keeps the navigators of the branches of the main
  /// navigation when the main navigation leaves its stack, as when the
  /// location that the guards of the routes answer takes its place, or
  /// `go()` shows a page outside it. The page of the main navigation that
  /// left stays in the tree, with those navigators, until the transition
  /// to the page that took its place is over. So a main navigation that
  /// comes back before that, as when the guard allows again, has the keys
  /// of the navigators in the tree a second time, which Flutter throws for.
  static const routerKeepingNavigatorsOfBranches = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_keeps_navigators_of_branches'),
    'A plain navigator whose branches keep their navigators (fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '    if (!_stack.contains(_mainNavigation)) {\n'
            '      _branchNavigators.clear();\n'
            '      _branchObservers.clear();\n'
            '    }\n'
            '    super.notifyListeners();\n',
        '    super.notifyListeners();\n',
      ),
    ],
  );

  /// The fake router that throws when the back button of the system has no
  /// route to close, rather than leaving the button to the system: its
  /// navigators still close a route on top, such as a dialog or a pushed
  /// page, but on the first page of the app it throws a `StateError`, as a
  /// router does that looks for the last of its pages where it has none.
  static const routerThrowingWithNoRouteToClose = BrokenModule._(
    FakeRouterModule(),
    ModuleId('broken_router_throws_with_no_route_to_close'),
    'A plain navigator whose back button throws on its first page (fixture)',
    RouterRole.appRouterFactoryFile,
    [
      (
        '      if (await navigator.maybePop()) return true;\n'
            '    }\n'
            '    return false;\n',
        '      if (await navigator.maybePop()) return true;\n'
            '    }\n'
            "    throw StateError('No element');\n",
      ),
    ],
  );

  /// The fixture events whose `on<T>()` gives a listener the events of
  /// every type, cast to its type, rather than only those of its type: an
  /// event of another type reaches the listener as an error.
  static const eventsOfEveryType = BrokenModule._(
    FakeEventsModule(),
    ModuleId('broken_events_of_every_type'),
    'Events that reach the listeners of every type (fixture)',
    'lib/core/fixture_events/fixture_events.dart',
    [
      (
        '_events.stream.where((event) => event is T).cast<T>()',
        '_events.stream.cast<T>()',
      ),
    ],
  );

  /// The fixture preferences whose writes never reach their disk: a
  /// value that was saved is read back as long as the app runs, and gone at
  /// its next start.
  static const preferencesForgettingWrites = BrokenModule._(
    FakePreferencesModule(),
    ModuleId('broken_preferences_forget_writes'),
    'Preferences in memory that save nothing (fixture)',
    'lib/core/fixture_preferences/fixture_preferences.dart',
    [('    fixturePreferencesDisk[key] = _copyOf(value);\n', '')],
  );

  /// The fixture preferences that never copy a list: they keep the list
  /// that they are given, and a read returns the list that they keep. So a
  /// later change of the list that was saved, or of one that was read,
  /// changes what they read.
  static const preferencesNeverCopyingLists = BrokenModule._(
    FakePreferencesModule(),
    ModuleId('broken_preferences_never_copy_lists'),
    'Preferences in memory that never copy a list (fixture)',
    'lib/core/fixture_preferences/fixture_preferences.dart',
    [
      ('      _save(key, List.of(value));\n', '      _save(key, value);\n'),
      (
        '    final List<String> list => List.of(list),\n',
        '    final List<String> list => list,\n',
      ),
    ],
  );

  /// The fixture preferences whose reads cast the value of a key to the
  /// type they ask for, rather than returning `null` for a value of another
  /// type: such a read throws a `TypeError`.
  static const preferencesCastingValues = BrokenModule._(
    FakePreferencesModule(),
    ModuleId('broken_preferences_cast_values'),
    'Preferences in memory whose reads cast (fixture)',
    'lib/core/fixture_preferences/fixture_preferences.dart',
    [
      (
        '  T? _read<T>(String key) => switch (_values[key]) {\n'
            '    final T value => value,\n'
            '    _ => null,\n'
            '  };\n',
        '  T? _read<T>(String key) => _values[key] as T?;\n',
      ),
    ],
  );

  /// The fixture texts whose delegate supports English only, whatever the
  /// languages of the app: in another language of the app, the root of the
  /// app loads no texts of the app, and the code that reads one throws.
  static const textsDelegateForEnglishOnly = BrokenModule._(
    FakeL10nModule(),
    ModuleId('broken_texts_delegate_for_english_only'),
    'The texts of the app with a delegate for English only (fixture)',
    LocalizationRole.textsFile,
    [
      ("import 'app_locale.dart';\n\n", ''),
      (
        '  bool isSupported(Locale locale) => appLocales.any(\n'
            '        (supported) => supported.languageCode == '
            'locale.languageCode,\n'
            '      );\n',
        "  bool isSupported(Locale locale) => locale.languageCode == 'en';\n",
      ),
    ],
  );

  /// The fixture texts that are always in the first language of the app,
  /// whatever language the root of the app is in: the delegate of the texts
  /// supports each language of the app, and loads the texts of the first
  /// one for it.
  static const textsInFirstLanguage = BrokenModule._(
    FakeL10nModule(),
    ModuleId('broken_texts_in_first_language'),
    'The texts of the app, always in its first language (fixture)',
    LocalizationRole.textsFile,
    [
      (
        '      SynchronousFuture(FixtureTexts(locale.languageCode));\n',
        '      SynchronousFuture(\n'
            '        FixtureTexts(appLocales.first.languageCode),\n'
            '      );\n',
      ),
    ],
  );

  /// The fixture theme whose dark theme is light: `createDarkTheme()`
  /// returns the theme that `createLightTheme()` does, so an app in the dark
  /// mode looks as it does in the light one.
  static const themeWithLightDarkTheme = BrokenModule._(
    FakeThemeModule(),
    ModuleId('broken_theme_dark_is_light'),
    'A light and a dark theme that are both light (fixture)',
    ThemeRole.appThemeFile,
    [
      (
        '_themeOf(context, Brightness.dark)',
        '_themeOf(context, Brightness.light)',
      ),
    ],
  );

  /// The service log of the fixtures whose analytics service notes each
  /// call twice, as a service does that sends each event twice: to the
  /// tests of the analytics role, each call of the analytics service of the
  /// app reaches it twice. Its crash reporter notes each call once.
  static const serviceLogNotingAnalyticsTwice = BrokenModule._(
    FakeServiceLogModule(),
    ModuleId('broken_service_log_notes_analytics_twice'),
    'Analytics that notes every call twice, and crash reporting (fixture)',
    'lib/core/fixture_service_log/fixture_service_log.dart',
    [
      (
        '  calls.add(call);\n',
        '  calls.add(call);\n'
            '  if (identical(calls, loggedAnalyticsCalls)) calls.add(call);\n',
      ),
    ],
  );

  /// The fixture crash reporting whose start sets the handler of the errors
  /// of Flutter to a report of its own, as the guide of a crash reporting
  /// SDK may tell an app to do, rather than leaving the handlers to the
  /// role: the handler of the role then calls it in place of the handler
  /// that presented the errors of Flutter, so none is presented, and the
  /// fixture reports each of them twice.
  static const crashReportingTakingFlutterErrors = BrokenModule._(
    FakeCrashModule(),
    ModuleId('broken_crash_takes_flutter_errors'),
    'Crash reporting that takes the errors of Flutter for itself (fixture)',
    'lib/core/fixture_crash/fixture_crash.dart',
    [
      (
        '  return const FixtureCrashReporter();\n',
        '  const reporter = FixtureCrashReporter();\n'
            '  FlutterError.onError = (details) {\n'
            '    reporter.recordFlutterError(details, fatal: true);\n'
            '  };\n'
            '  return reporter;\n',
      ),
    ],
  );

  /// The fixture sign-in whose function returns its service before it has
  /// read who is signed in on the device, as a provider does that takes its
  /// user from a stream of its SDK rather than from what the SDK has
  /// already: the service has nobody at first, and tells of the user of the
  /// device a moment later. So a start of the app is over without that
  /// user, and the first frame of the app has nobody signed in.
  static const authRestoringUserLate = BrokenModule._(
    FakeAuthModule(),
    ModuleId('broken_auth_restores_user_late'),
    'Sign-in that finds its user after the start (fixture)',
    _fixtureAuthFile,
    [('  await service._restore();\n', '  unawaited(service._restore());\n')],
  );

  /// The fixture sign-in whose `linkPassword()` creates a new user for the
  /// account, rather than giving the account to the anonymous user who is
  /// signed in: the user of the account has another id than the anonymous
  /// user had, so what the app keeps under that id is left behind.
  static const authLinkingAsNewUser = BrokenModule._(
    FakeAuthModule(),
    ModuleId('broken_auth_links_as_new_user'),
    'Sign-in that gives an anonymous user a new id with an account (fixture)',
    _fixtureAuthFile,
    [
      (
        '    // The anonymous user keeps the id.\n'
            '    final uid = user.uid;\n',
        '    final uid = _newUid();\n',
      ),
    ],
  );

  /// The file of the fixture sign-in.
  static const _fixtureAuthFile = 'lib/core/fixture_auth/fixture_auth.dart';

  /// The module with the bug.
  final SmfModule of;

  /// The id of the module.
  final ModuleId id;

  final String _description;

  /// The path of the file that the bug changes, among the files of the
  /// bricks of [of].
  final String _file;

  /// The changes of the code of [of] in its file [_file]: the first text of
  /// each, which the file has once, becomes the second.
  final List<(String, String)> _changes;

  @override
  ModuleDescriptor get descriptor {
    final fixture = of.descriptor;
    return ModuleDescriptor(
      id: id,
      description: _description,
      kind: fixture.kind,
      dependsOn: fixture.dependsOn,
      requires: fixture.requires,
      uses: fixture.uses,
      providers: fixture.providers,
      variants: fixture.variants,
    );
  }

  /// The contributions of [of], with its brick that has [_file] under the
  /// id of this module and with the [_changes] of the file, and with the
  /// variables of its bricks that read its texts reading them as texts of
  /// this module. Throws a [StateError] when no brick of [of] has the file,
  /// or the file does not have the text of a change once, as when the code
  /// of the fixture changed: the app would not have the bug.
  @override
  List<Contribution> contribute(ModuleContext context) {
    final contributed = of.contribute(context);
    // The getter of a text starts with the id of the module that gives it.
    final texts = localizationRole.varsOf(
      id,
      TextsData([
        for (final contribution in contributed)
          if (contribution case RoleData(value: TextsData(:final texts)))
            ...texts,
      ]),
    );
    final contributions = [
      for (final contribution in contributed)
        if (contribution case BrickContribution(:final bundle, :final vars))
          BrickContribution(
            bundle.files.any((file) => file.path == _file)
                ? _changed(bundle)
                : bundle,
            vars: {
              for (final MapEntry(key: name, :value) in vars.entries)
                name: value is RoleVar ? texts[name] ?? value : value,
            },
            when: contribution.when,
          )
        else
          contribution,
    ];
    if (!contributions.any(_isChanged)) {
      throw StateError('No brick of ${of.descriptor.id} has $_file.');
    }
    return contributions;
  }

  /// Whether [contribution] is a brick that this module changed.
  bool _isChanged(Contribution contribution) =>
      contribution is BrickContribution && contribution.bundle.name == id.value;

  /// [bundle], the brick of [of] with [_file], under the id of this module
  /// and with the [_changes] of the file.
  MasonBundle _changed(MasonBundle bundle) => MasonBundle(
        name: id.value,
        description: bundle.description,
        version: bundle.version,
        files: [
          for (final file in bundle.files)
            if (file.path == _file)
              MasonBundledFile(
                file.path,
                base64.encode(
                  utf8.encode(
                    _changes.fold(
                      utf8.decode(base64.decode(file.data)),
                      _changedOnce,
                    ),
                  ),
                ),
                file.type,
              )
            else
              file,
        ],
      );

  /// [text], the file [_file], with the first text of [change], which it
  /// has once, replaced by the second.
  String _changedOnce(String text, (String, String) change) {
    final (from, to) = change;
    final count = from.allMatches(text).length;
    if (count != 1) {
      throw StateError(
        '${of.descriptor.id} has $count times rather than once in $_file '
        'what $id changes, so its app would not have its bug: $from',
      );
    }
    return text.replaceFirst(from, to);
  }
}

/// A layout with one known bug: a bar at the bottom with a tab for each
/// destination, whose `AppShell` breaks what the layout role says of it in
/// one way.
final class BrokenLayoutModule extends SmfModule {
  /// The layout whose `AppShell` shows a tab for each destination, but
  /// gives only the first one to the code that reads its `destinations`, as
  /// code that knows only the layout role does.
  const BrokenLayoutModule.givingFirstDestination()
      : id = const ModuleId('broken_layout_first_destination'),
        _description = 'Tabs at the bottom that hide a destination (fixture)',
        _keepsLabels = false;

  /// The layout whose `AppShell` reads the label of each destination when
  /// it is first built and keeps it, rather than reading it each time it
  /// builds: once the app is in another language, its tabs still show the
  /// labels in the language of before.
  const BrokenLayoutModule.keepingLabels()
      : id = const ModuleId('broken_layout_keeps_labels'),
        _description = 'Tabs at the bottom with the labels of the first '
            'build (fixture)',
        _keepsLabels = true;

  /// The id of the module.
  final ModuleId id;

  final String _description;

  /// Whether the bug is that of [BrokenLayoutModule.keepingLabels].
  final bool _keepsLabels;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: _description,
        kind: ModuleKinds.layout,
        providers: const [_BrokenLayoutProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          _keepsLabels ? brokenLayoutLabelsBundle : brokenLayoutBundle,
        ),
      ];
}

/// Provides the layout role, with any number of destinations.
final class _BrokenLayoutProvider extends LayoutProvider {
  const _BrokenLayoutProvider();
}

/// A DI container with one known bug: the fake DI container of the
/// fixtures, which renders the registration of every service, but that of
/// one service in a condition that is false when the app runs, so the
/// service does not resolve. It is the last service in the order of the
/// registrations ([DiGraph.ordered]) that has no function to dispose of it,
/// so resetting the container disposes of the same services as before.
///
/// The file of the container still calls the factory of every
/// registration, as the rule `di.registrations_rendered` of the role wants,
/// and the app analyzes: only a running app shows the bug.
final class BrokenDiModule extends SmfModule {
  /// Creates the module.
  const BrokenDiModule();

  /// The id of the module.
  static const id = ModuleId('broken_di_leaves_out_a_service');

  /// The fake DI container, whose bricks this module contributes.
  static const _fixture = FakeDiModule();

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'DI with a map of factories that leaves out a service '
            '(fixture)',
        kind: _fixture.descriptor.kind,
        providers: [_BrokenDiProvider(FakeDiProvider(_fixture.capabilities))],
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      _fixture.contribute(context);
}

/// Renders the registrations as [_fixture] does, but that of the last
/// service without a function to dispose of it in a condition that is
/// false when the app runs.
final class _BrokenDiProvider extends DiProvider {
  const _BrokenDiProvider(this._fixture);

  /// The provider of the fake DI container.
  final FakeDiProvider _fixture;

  /// The condition, false when the app runs, of the registration that the
  /// container leaves out, which the analyzer cannot tell.
  static const _never = 'DateTime.now().year < 2000';

  @override
  Set<DiCapability> get capabilities => _fixture.capabilities;

  /// The output of [_fixture], with the registration that the container
  /// leaves out in [_never]. [_fixture] renders the registrations as a line
  /// that takes the service locator and then a line for each registration,
  /// in their order. The output stays as it is when every service has a
  /// function to dispose of it. Throws a [StateError] when [_fixture]
  /// renders the registrations otherwise, so the app would not have the
  /// bug.
  @override
  RoleOutput render(RoleHookInput<DiRegistration> input) {
    final output = _fixture.render(input);
    final ordered = diRole.graphOf(input).ordered;
    final index = ordered.lastIndexWhere(
      (registration) => registration.dispose == null,
    );
    if (index < 0) return output;
    final registrations = output.vars['registrations']! as Fragment;
    final lines = registrations.code.split('\n');
    if (lines.length != ordered.length + 1) {
      throw StateError(
        'fake_di renders ${lines.length} lines for ${ordered.length} '
        'registrations rather than one more, so the app of '
        '${BrokenDiModule.id} would not have its bug.',
      );
    }
    lines[index + 1] = '  if ($_never) {\n  ${lines[index + 1]}\n  }';
    return RoleOutput(
      fragments: output.fragments,
      vars: {
        ...output.vars,
        'registrations': Fragment(
          lines.join('\n'),
          imports: registrations.imports,
        ),
      },
      files: output.files,
    );
  }
}

/// A provider of the settings screen role with one known bug: a feature
/// whose screen creates the widget of every entry of the role, in a list of
/// its file, but shows them all but the last one.
///
/// The file of the screen still creates the widget of every entry, as the
/// rule `settings_screen.entries_rendered` of the role wants, and the app
/// analyzes: only a running app shows the bug.
final class BrokenSettingsModule extends SmfModule {
  /// Creates the module.
  const BrokenSettingsModule();

  /// The id of the module.
  static const id = ModuleId('broken_settings_hides_last_entry');

  /// The name of the route of the screen.
  static const _route = 'settings';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A settings screen that hides its last entry (fixture)',
        kind: ModuleKinds.feature,
        providers: [_BrokenSettingsProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(brokenSettingsBundle),
        routerRole.data(
          const RoutesData([
            Route(
              '/',
              name: _route,
              screen: ScreenRef(
                'BrokenSettingsScreen',
                import: ImportRef.app(
                  'features/broken_settings_hides_last_entry/'
                  'broken_settings_screen.dart',
                ),
              ),
            ),
          ]),
        ),
        settingsScreenRole.data(const SettingsScreenRoute(_route)),
      ];
}

/// Renders the widgets of the entries of the settings screen role as the
/// items of the list of the file of the screen, in the order of the role,
/// each through an import of its file with a prefix of its own.
final class _BrokenSettingsProvider extends RoleProvider<SettingsData> {
  const _BrokenSettingsProvider();

  @override
  Role<SettingsData> get role => settingsScreenRole;

  @override
  RoleOutput render(RoleHookInput<SettingsData> input) {
    final files = <String, ImportRef>{};
    final items = <String>[];
    for (final entry in settingsScreenRole.entriesIn(input)) {
      // The template of the role rejects an entry outside the app, so each
      // has an import.
      final import = entry.widget.import!;
      final prefix = files
          .putIfAbsent(
            import.uri,
            () => import.withPrefix('entry${files.length}'),
          )
          .prefix;
      items.add('  ${entry.widget.codeWith(prefix)}(),');
    }
    return RoleOutput(
      vars: {
        'entries': Fragment(items.join('\n'), imports: [...files.values]),
      },
    );
  }
}
