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
import 'package:fake_di/fake_di.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fake_router/fake_router.dart';
import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// A fixture module with one known bug, which a change of the code that it
/// renders brings in: the rest of it is the fixture module [of], under
/// another id. The fixture has no sockets of its own, which would be those
/// of its id.
final class BrokenModule extends SmfModule {
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

  /// The fixture module with the bug.
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
  /// id of this module and with the [_changes] of the file. Throws a
  /// [StateError] when no brick of [of] has the file, or the file does not
  /// have the text of a change once, as when the code of the fixture
  /// changed: the app would not have the bug.
  @override
  List<Contribution> contribute(ModuleContext context) {
    final contributions = [
      for (final contribution in of.contribute(context))
        if (contribution case BrickContribution(:final bundle)
            when bundle.files.any((file) => file.path == _file))
          BrickContribution(
            _changed(bundle),
            vars: contribution.vars,
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

/// A layout with one known bug: its `AppShell` shows a tab at the bottom
/// for each destination, but gives only the first one to the code that
/// reads its `destinations`, as code that knows only the layout role does.
final class BrokenLayoutModule extends SmfModule {
  /// Creates the module.
  const BrokenLayoutModule();

  /// The id of the module.
  static const id = ModuleId('broken_layout_first_destination');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Tabs at the bottom that hide a destination (fixture)',
        kind: ModuleKinds.layout,
        providers: [_BrokenLayoutProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      [BrickContribution(brokenLayoutBundle)];
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
