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
import 'package:fake_router/fake_router.dart';
import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// The fake router with one known bug, which a change of the code that it
/// renders brings in: the rest of its code is that of [FakeRouterModule].
final class BrokenRouterModule extends SmfModule {
  const BrokenRouterModule._(this.id, this._description, this._changes);

  /// The fake router that tells the listeners of the screen of the page on
  /// top each time it builds its navigator, though the page on top did not
  /// change: it keeps no note of the page that they heard of last.
  static const repeatsScreens = BrokenRouterModule._(
    ModuleId('broken_router_repeats_screens'),
    'A plain navigator that repeats the screen (fixture)',
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

  /// The id of the module.
  final ModuleId id;

  final String _description;

  /// The changes of the code of the fake router in its file
  /// [RouterRole.appRouterFactoryFile]: the first text of each, which the
  /// file has once, becomes the second.
  final List<(String, String)> _changes;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: _description,
        kind: ModuleKinds.infrastructure,
        providers: const [FakeRouterProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        for (final contribution in const FakeRouterModule().contribute(context))
          if (contribution is BrickContribution)
            BrickContribution(
              _changed(contribution.bundle),
              vars: contribution.vars,
              when: contribution.when,
            )
          else
            contribution,
      ];

  /// [bundle], a brick of the fake router, under the id of this module and
  /// with the [_changes] of its file [RouterRole.appRouterFactoryFile].
  /// Throws a [StateError] when the file does not have the text of a change
  /// once, as when the code of the fake router changed: its app would not
  /// have the bug.
  MasonBundle _changed(MasonBundle bundle) {
    const path = RouterRole.appRouterFactoryFile;
    return MasonBundle(
      name: id.value,
      description: bundle.description,
      version: bundle.version,
      files: [
        for (final file in bundle.files)
          if (file.path == path)
            MasonBundledFile(
              file.path,
              base64.encode(
                utf8.encode(
                  _changes.fold(
                    utf8.decode(base64.decode(file.data)),
                    (text, change) => _changedOnce(text, change, path),
                  ),
                ),
              ),
              file.type,
            )
          else
            file,
      ],
    );
  }

  /// [text], the file at [path], with the first text of [change], which it
  /// has once, replaced by the second.
  String _changedOnce(String text, (String, String) change, String path) {
    final (from, to) = change;
    final count = from.allMatches(text).length;
    if (count != 1) {
      throw StateError(
        'The fake router has $count times rather than once in $path what '
        '$id changes, so its app would not have its bug: $from',
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
