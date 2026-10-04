import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';

/// The brick [name] with the text files [files], each by its path in the
/// app.
MasonBundle _bundle(String name, Map<String, String> files) => MasonBundle(
      name: name,
      description: name,
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
    );

/// A Dart file with a widget for each of [widgets], the classes of the
/// entries of the settings screen that a contributor of the tests has: a
/// row with the name of the class.
String _widgetsFile(List<String> widgets) => [
      "import 'package:flutter/material.dart';",
      for (final widget in widgets) ...[
        '',
        '/// A setting of the tests.',
        'class $widget extends StatelessWidget {',
        '  /// Creates the setting.',
        '  const $widget({super.key});',
        '',
        '  @override',
        '  Widget build(BuildContext context) =>',
        "      const ListTile(title: Text('$widget'));",
        '}',
      ],
      '',
    ].join('\n');

/// The entries of the settings screen for the classes [widgets] of the
/// file at [path] below `lib/`.
List<Contribution> _entries(String path, List<String> widgets) => [
      for (final widget in widgets)
        settingsScreenRole.data(
          SettingsEntry(widget: TypeRef(widget, import: ImportRef.app(path))),
        ),
    ];

/// A feature for the tests with one route, `/<name>`, which can start the
/// app and is a destination of the main navigation labelled with [name] in
/// title case, and with a setting for each of [settings], the classes of
/// its widgets, which it gives the settings screen role when the app has
/// one.
final class SettingsFeature extends SmfModule {
  /// Creates the feature [name] with [settings].
  const SettingsFeature(this.name, {this.settings = const []});

  /// The id of the feature and the name of its route.
  final String name;

  /// The classes of the widgets of its settings, in order.
  final List<String> settings;

  /// The id of the module.
  ModuleId get id => ModuleId(name);

  /// The label of the destination, such as `Feed`.
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  String get _screen => '${label}Screen';

  String get _screenFile => 'features/$name/${name}_screen.dart';

  /// The path below `lib/` of the file of the widgets of [settings].
  String get settingsFile => 'features/$name/${name}_settings.dart';

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'The feature $name (test)',
        kind: ModuleKinds.feature,
        uses: const {settingsScreenRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) {
    final tag = RouterRole.screenAnnotations((feature: id, screen: _screen));
    return [
      BrickContribution(
        _bundle(name, {
          'lib/$_screenFile': [
            "import 'package:flutter/widgets.dart';",
            '',
            '/// A screen of the tests.',
            '{{{${tag.tag}}}}',
            'class $_screen extends StatelessWidget {',
            '  /// Creates the screen.',
            '  const $_screen({super.key});',
            '',
            '  @override',
            '  Widget build(BuildContext context) => const SizedBox();',
            '}',
            '',
          ].join('\n'),
        }),
      ),
      routerRole.data(
        RoutesData([
          Route(
            '/',
            name: name,
            screen: ScreenRef(_screen, import: ImportRef.app(_screenFile)),
            destination: Destination(
              label: label,
              icon: const Fragment(
                'Icons.star',
                imports: [
                  ImportRef('package:flutter/material.dart', show: ['Icons']),
                ],
              ),
            ),
            startCandidate: true,
          ),
        ]),
      ),
      if (settings.isNotEmpty) ...[
        // Only an app with a settings screen gets the widgets.
        BrickContribution(
          _bundle('${name}_settings', {
            'lib/$settingsFile': _widgetsFile(settings),
          }),
          when: const {settingsScreenRole},
        ),
        ..._entries(settingsFile, settings),
      ],
    ];
  }
}

/// A module without screens for the tests, such as one that sets up a
/// library, with a setting for each of [settings], the classes of its
/// widgets, which it gives the settings screen role when the app has one.
final class SettingsInfrastructure extends SmfModule {
  /// Creates the module [name] with [settings].
  const SettingsInfrastructure(this.name, {required this.settings});

  /// The id of the module.
  final String name;

  /// The classes of the widgets of its settings, in order.
  final List<String> settings;

  /// The id of the module.
  ModuleId get id => ModuleId(name);

  /// The path below `lib/` of the file of the widgets of [settings].
  String get settingsFile => 'core/$name/${name}_settings.dart';

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'The library $name (test)',
        kind: ModuleKinds.infrastructure,
        uses: const {settingsScreenRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          _bundle('${name}_settings', {
            'lib/$settingsFile': _widgetsFile(settings),
          }),
          when: const {settingsScreenRole},
        ),
        ..._entries(settingsFile, settings),
      ];
}

/// The zoom role of the tests; see [ZoomRole].
const zoomRole = ZoomRole._();

/// A role of the tests whose template has a setting of its own, whichever
/// module provides the role: the template gives the settings screen role an
/// entry, and generates its widget in an app with a settings screen.
final class ZoomRole extends Role<NoDsl> {
  const ZoomRole._();

  /// The class of the widget of the setting.
  static const setting = 'ZoomSetting';

  /// The path below `lib/` of the file of [setting].
  static const settingFile = 'core/zoom/zoom_setting.dart';

  @override
  String get id => 'zoom';

  @override
  String get description => 'Zoom';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get uses => {settingsScreenRole};

  @override
  RoleTemplate<NoDsl> get template => const _ZoomTemplate();
}

final class _ZoomTemplate extends RoleTemplate<NoDsl> {
  const _ZoomTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          _bundle('zoom_role_setting', {
            'lib/${ZoomRole.settingFile}': _widgetsFile([ZoomRole.setting]),
          }),
          when: const {settingsScreenRole},
        ),
        ..._entries(ZoomRole.settingFile, [ZoomRole.setting]),
      ];
}

/// A module of the tests that provides the [ZoomRole], with nothing of its
/// own.
final class ZoomModule extends SmfModule {
  /// Creates the module.
  const ZoomModule();

  /// The id of the module.
  static const id = ModuleId('pinch_zoom');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Zoom with two fingers (test)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(zoomRole)],
      );
}
