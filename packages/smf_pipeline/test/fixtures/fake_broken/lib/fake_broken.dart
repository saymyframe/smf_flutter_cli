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
