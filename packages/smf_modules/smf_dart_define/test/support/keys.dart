import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';

/// A module for the tests with [keys], which it gives the env role, and one
/// file, [file], with a function `<name>Values()` that returns the value of
/// each key: through `AppEnv` in an app with the role, and `null` in an app
/// without it.
///
/// It requires the role, or only uses it unless [requiresEnv].
final class KeysModule extends SmfModule {
  /// Creates the module [name] with [keys].
  const KeysModule(this.name, this.keys, {this.requiresEnv = true});

  /// The id of the module, a single word.
  final String name;

  /// The keys of the module.
  final List<EnvKey> keys;

  /// Whether the module requires the env role, rather than uses it.
  final bool requiresEnv;

  /// The id of the module.
  ModuleId get id => ModuleId(name);

  /// The path of the file of the module.
  String get file => 'lib/core/$name/$name.dart';

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'The values of $name (test)',
        kind: ModuleKinds.infrastructure,
        requires: requiresEnv ? const {envRole} : const {},
        uses: requiresEnv ? const {} : const {envRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) {
    final vars = envRole.varsOf(id, keys);
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
                    '/// The values of the module.',
                    'List<String?> ${name}Values() => [',
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
      for (final key in keys) envRole.data(key),
    ];
  }
}
