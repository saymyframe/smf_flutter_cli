import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/lego.dart';

/// A mason bundle named [name] with the text [files] by path.
MasonBundle bundleOf(String name, Map<String, String> files) => MasonBundle(
      name: name,
      description: name,
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
    );

/// A feature for the tests with one route, `/<name>`, named [name], whose
/// screen shows nothing. With [destination], the route is a destination of
/// the main navigation, labelled [name] with the icon `Icons.<name>`, and
/// the app can start on it.
final class TestFeature extends SmfModule {
  /// Creates the feature [name], which is the name of an icon of the
  /// material library too if it is a [destination].
  const TestFeature(this.name, {this.destination = true});

  /// The id of the feature and the name of its route.
  final String name;

  /// Whether the route is a destination of the main navigation.
  final bool destination;

  /// The id of the module.
  ModuleId get id => ModuleId(name);

  String get _screen => '${name[0].toUpperCase()}${name.substring(1)}Screen';

  String get _file => 'features/$name/${name}_screen.dart';

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'The feature $name (test)',
        kind: ModuleKinds.feature,
      );

  @override
  List<Contribution> contribute(ModuleContext context) {
    final tag = RouterRole.screenAnnotations((feature: id, screen: _screen));
    return [
      BrickContribution(
        bundleOf(name, {
          'lib/$_file': [
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
            screen: ScreenRef(_screen, import: ImportRef.app(_file)),
            destination: destination
                ? Destination(
                    label: name,
                    icon: Fragment(
                      'Icons.$name',
                      imports: const [
                        ImportRef(
                          'package:flutter/material.dart',
                          show: ['Icons'],
                        ),
                      ],
                    ),
                  )
                : null,
            startCandidate: destination,
          ),
        ]),
      ),
    ];
  }
}

/// A layout for the tests, whose `AppShell` shows the screen of the selected
/// destination and nothing else.
final class TestLayout extends SmfModule {
  /// Creates the module.
  const TestLayout();

  /// The id of the module.
  static const id = ModuleId('tabs');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A main navigation (test)',
        kind: ModuleKinds.layout,
        providers: [_TestLayoutProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundleOf('tabs', {
            LayoutRole.appShellFile: [
              "import 'package:flutter/widgets.dart';",
              '',
              "import 'destination.dart';",
              '',
              '/// The main navigation of the tests.',
              'class AppShell extends StatelessWidget {',
              '  /// Creates the main navigation.',
              '  const AppShell({',
              '    required this.destinations,',
              '    required this.currentIndex,',
              '    required this.onSelect,',
              '    required this.body,',
              '    super.key,',
              '  });',
              '',
              '  /// The destinations.',
              '  final List<Destination> destinations;',
              '',
              '  /// The index of the selected destination.',
              '  final int currentIndex;',
              '',
              '  /// Selects the destination at an index.',
              '  final ValueChanged<int> onSelect;',
              '',
              '  /// The screen of the selected destination.',
              '  final Widget body;',
              '',
              '  @override',
              '  Widget build(BuildContext context) => body;',
              '}',
              '',
            ].join('\n'),
          }),
        ),
      ];
}

/// The layout role, with any number of destinations.
final class _TestLayoutProvider extends LayoutProvider {
  const _TestLayoutProvider();
}
