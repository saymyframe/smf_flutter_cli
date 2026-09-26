import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/lego.dart';

/// A feature for the tests with one route, `/<name>`, whose destination is
/// labelled with [name] in title case and shows the icon `Icons.<name>`, and
/// which can start the app if [startCandidate] is set.
final class TabFeature extends SmfModule {
  /// Creates the feature [name], which is the name of an icon of the
  /// material library too.
  const TabFeature(this.name, {this.startCandidate = false});

  /// The id of the feature, the name of its route and of its icon.
  final String name;

  /// Whether the app can start on the route of the feature.
  final bool startCandidate;

  /// The id of the module.
  ModuleId get id => ModuleId(name);

  /// The label of the destination, such as `Inbox`.
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  String get _screen => '${label}Screen';

  String get _file => 'features/$name/${name}_screen.dart';

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'The tab $name (test)',
        kind: ModuleKinds.feature,
      );

  @override
  List<Contribution> contribute(ModuleContext context) {
    final tag = RouterRole.screenAnnotations((feature: id, screen: _screen));
    return [
      BrickContribution(
        MasonBundle(
          name: name,
          description: name,
          version: '0.1.0',
          files: [
            MasonBundledFile(
              'lib/$_file',
              base64.encode(
                utf8.encode(
                  [
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
                ),
              ),
              'text',
            ),
          ],
        ),
      ),
      routerRole.data(
        RoutesData([
          Route(
            '/',
            name: name,
            screen: ScreenRef(_screen, import: ImportRef.app(_file)),
            destination: Destination(
              label: label,
              icon: Fragment(
                'Icons.$name',
                imports: const [
                  ImportRef('package:flutter/material.dart', show: ['Icons']),
                ],
              ),
            ),
            startCandidate: startCandidate,
          ),
        ]),
      ),
    ];
  }
}
