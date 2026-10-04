import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';

/// A module for the tests with [texts], which it gives the localization
/// role, and one file, [file], with a function `<name>Texts(context)` that
/// returns each text in the language of the context: through the role in
/// an app with it, and in English in an app without it.
final class TextsModule extends SmfModule {
  /// Creates the module [name] with [texts].
  const TextsModule(this.name, this.texts);

  /// The id of the module, a single word.
  final String name;

  /// The texts of the module.
  final List<LocalizedText> texts;

  /// The id of the module.
  ModuleId get id => ModuleId(name);

  /// The path of the file of the module.
  String get file => 'lib/core/$name/$name.dart';

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'The texts of $name (test)',
        kind: ModuleKinds.infrastructure,
        uses: const {localizationRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) {
    final data = TextsData(texts);
    final vars = localizationRole.varsOf(id, data);
    return [
      BrickContribution(
        MasonBundle(
          name: name,
          description: name,
          version: '0.1.0',
          files: [
            MasonBundledFile(
              file,
              base64.encode(
                utf8.encode(
                  [
                    "import 'package:flutter/widgets.dart';",
                    '',
                    '/// The texts of the module in the language of the app.',
                    'List<String> ${name}Texts(BuildContext context) => [',
                    for (final variable in vars.keys) '      {{{$variable}}},',
                    '    ];',
                    '',
                  ].join('\n'),
                ),
              ),
              'text',
            ),
          ],
        ),
        vars: vars,
      ),
      localizationRole.data(data),
    ];
  }
}
