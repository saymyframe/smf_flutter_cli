import 'package:smf_gen_l10n/src/gen_l10n_module.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the localization: where the texts of the app are with gen-l10n
/// of Flutter, how to add a text and the texts of a new language, and which
/// files the tool writes itself. Its first line names the tool, as the note
/// of a provider that wraps a package names the package.
const agentNote = '''
With `gen-l10n` of Flutter:

- The texts of the app are in the ARB files of `${GenL10nModule.arbDirectory}`. `${GenL10nModule.templateArbFile}` has every text in English, and `${GenL10nModule.arbDirectory}/app_<code>.arb` the translations into another language. A text that such a file lacks reads in English there.
- To add a text, add it to `${GenL10nModule.templateArbFile}` under a name in lowerCamelCase, and its translations under the same name to the other files. Then run `flutter pub get`, which generates `context.l10n.<name>`.
- Do not edit `${GenL10nModule.arbDirectory}/app_localizations*.dart`: `gen-l10n` writes those files from the ARB files, as `l10n.yaml` says. After adding the ARB file of a new language, run `flutter gen-l10n`, because `flutter pub get` does not notice a new file.
- Write an apostrophe in a text once: `l10n.yaml` turns the escapes of `gen-l10n` off (`use-escaping: false`).
''';
