import 'package:smf_gen_l10n/src/gen_l10n_module.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the localization: where the texts of the app are with gen-l10n
/// of Flutter, how to add a text, the command that generates the code after
/// a change of the ARB files, and which files the tool writes itself. Its
/// first line names the tool, as the note of a provider that wraps a
/// package names the package.
///
/// It names `flutter gen-l10n` alone, which generates the code after every
/// change, a new file included. `flutter pub get` does so only for a file
/// that it read before, in the directory in which it last generated the
/// code: the stamp of its build names the files by their absolute paths.
const agentNote = '''
With `gen-l10n` of Flutter:

- The texts of the app are in the ARB files of `${GenL10nModule.arbDirectory}`. `${GenL10nModule.templateArbFile}` has every text in English, and `${GenL10nModule.arbDirectory}/app_<code>.arb` the translations into another language. A text that such a file lacks reads in English there.
- To add a text, add it to `${GenL10nModule.templateArbFile}` under a name in lowerCamelCase, and its translations under the same name to the other files.
- After every change of the ARB files, a new file included, run `flutter gen-l10n`, which generates `context.l10n.<name>`. Do not edit `${GenL10nModule.arbDirectory}/app_localizations*.dart`: `gen-l10n` writes those files from the ARB files, as `l10n.yaml` says.
- Write an apostrophe in a text once: `l10n.yaml` turns the escapes of `gen-l10n` off (`use-escaping: false`).
''';
