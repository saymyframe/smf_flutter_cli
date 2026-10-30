import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/env_role_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

part 'env/env_dsl.dart';
part 'env/env_rules.dart';
part 'env/env_run_configurations.dart';
part 'env/env_template.dart';

/// The env role; see [EnvRole].
const envRole = EnvRole._();

/// The role of the values that the developer of an app fills in once the
/// app is generated, such as the public key of a service: the modules name
/// them as keys, the developer writes them into [dotEnvFile], and code reads
/// them through [appEnv].
///
/// A module that requires or uses the role gives it an [EnvKey] for each
/// value that its code reads: a name in UPPER_SNAKE_CASE that starts with
/// the id of the module, such as `REVENUECAT_APPLE_KEY` of the module
/// `revenuecat`, and a description of one line. Only modules give keys: the
/// template of a role gives none and reads none. [keysIn] has the keys of an
/// app.
///
/// The role's template generates, whichever provider is selected:
/// - [dotEnvFile], with a comment line `# <description>` and a line `KEY=`
///   for each key, in the order of [keysIn]. The developer fills in the
///   values there: a line `KEY=value` gives the key its value, and a line
///   that starts with `#` is a comment. Every provider reads two forms of a
///   value alike: a plain value, without `#`, spaces or quotes, such as
///   `KEY=appl_123`, and any other value in double quotes, such as
///   `KEY="https://example.com/terms#refunds"`. After a plain value, `# …`
///   is a comment, so a link with an anchor needs the quotes. The comment at
///   the top of both files says so;
/// - [exampleFile], with the same keys and no values. It stays in git, while
///   [dotEnvFile] does not: the template keeps [dotEnvFile] out of git with
///   the `.gitignore` of the app ([AppEntryRole.gitignore]), so a clone of
///   the app copies [exampleFile] to [dotEnvFile] and fills it in;
/// - [vscodeLaunchFile] and [androidStudioRunFileOf], the run configurations
///   of VS Code and of Android Studio, one for each flavor of the app
///   ([AppEntryRole.flavors]), each with the flavor and then the arguments of
///   [toolArgumentsIn]. So a provider gives its arguments and knows neither
///   the flavors nor the IDEs. The configuration of the default flavor is the
///   template of the launches of VS Code that name no configuration, such as
///   a link above `main()`, a link above a test and the Testing view. An app
///   without the role has no run configurations, and such a launch builds the
///   default flavor through its pubspec.
///
/// [dotEnvFile] is not tied to a flavor: a command gives the app what the file
/// has when the command runs, whichever flavor it builds.
///
/// It also writes the section [readmeHeading] of the README of the app,
/// with what the two files are for and the keys of the app, each with its
/// description and its owner, and the note of the role in the guide for
/// coding agents. A provider tells in a section of its own how the values
/// get into the app.
///
/// A provider generates [readerFile] with [appEnv], the class `AppEnv`, whose
/// static getters return the values. How the values of [dotEnvFile] get there
/// is up to the provider, as long as they are there before any code of the app
/// runs, `main()` included, and as long as a command of the `flutter` tool that
/// builds, runs or tests the app gives `AppEnv` the values that [dotEnvFile]
/// has when the command runs (see [appEnv]). A provider that needs arguments
/// for the commands of the `flutter` tool that build, run or test the app, so
/// that the values reach `AppEnv`, gives them to the role as
/// [EnvToolArguments], and code that runs those commands, such as an IDE
/// configuration or a test tool, takes them from [toolArgumentsIn] without
/// knowing the provider.
///
/// Every value ends up in the app, where anyone who has the app can read
/// it. So no secret goes into [dotEnvFile], such as the secret key of a
/// server, a password or a private key: only values that may be public,
/// such as the public key of a service or the address of a page.
///
/// A module that uses the role reads a value through a variable of
/// [varsOf]: `AppEnv.<getter>` in an app with the role, and `null` in an
/// app without it, where no developer fills in anything. Code of a module
/// that is only in an app with the role, such as code of a module that
/// requires it, may also read `AppEnv.<getter>` itself, with [appEnv]
/// imported. Either way, the code of a module reads only its own keys and
/// those of the modules it depends on, which the rule `env.key_access`
/// checks.
final class EnvRole extends Role<EnvData> {
  const EnvRole._();

  /// The path of the file with the values of the app, which the developer
  /// fills in and which stays out of git.
  static const dotEnvFile = '.env';

  /// The path of the file with the keys of the app without their values,
  /// which stays in git and which a clone of the app copies to
  /// [dotEnvFile].
  static const exampleFile = '.env.example';

  /// The path of the provider's file with [appEnv].
  static const readerFile = 'lib/core/env/app_env.dart';

  /// The heading of the section of the README of the app in which the
  /// template tells what [dotEnvFile] and [exampleFile] are for and lists
  /// the keys of the app. The section of a provider on how the values get
  /// into the app can refer to it.
  static const readmeHeading = 'Values in .env';

  /// The path of the run configurations of VS Code, one for each flavor of
  /// the app, which the template writes.
  static const vscodeLaunchFile = '.vscode/launch.json';

  /// The path of the run configuration of Android Studio for [flavor], which
  /// the template writes. Android Studio shares what is in `.run/`, since the
  /// `.idea/` of a project belongs to one machine.
  static String androidStudioRunFileOf(AppFlavor flavor) =>
      '.run/${flavor.name}.run.xml';

  /// `AppEnv`, the class in [readerFile] through which code reads the
  /// values of [dotEnvFile], which every provider generates.
  ///
  /// It is an `abstract final class` that declares no constructor and, for
  /// each key of [keysIn], a static getter named [EnvKey.getter], the key
  /// in lowerCamelCase, which returns a `String?`:
  ///
  /// ```dart
  /// static String? get revenuecatAppleKey => ...;
  /// ```
  ///
  /// A getter returns the value that its key has in [dotEnvFile], or `null`
  /// when the value is empty or the file lacks the key, so `KEY=` counts as
  /// missing. It returns it at once, before any code of the app runs,
  /// `main()` included, so code reads a value anywhere without waiting for
  /// it, also code that runs without `main()`, such as a test: a provider
  /// that loads [dotEnvFile] as the app runs, which takes a `Future`, or
  /// that sets the values in `main()`, does not keep this contract. The app
  /// builds whichever keys [dotEnvFile] has and whatever their values are: a
  /// value that the developer has not filled in yet is `null`, not an error.
  /// Code handles `null`, and may tell the developer in a debug build which
  /// key is missing.
  ///
  /// `AppEnv` gets the values from the command that builds the app: a
  /// command of the `flutter` tool that builds, runs or tests the app, with
  /// the arguments of [toolArgumentsIn], gives `AppEnv` the values that
  /// [dotEnvFile] has when the command runs, and nothing else runs after
  /// [dotEnvFile] changes. So a provider whose values need code generation
  /// after an edit of [dotEnvFile] does not keep this contract either.
  ///
  /// The rule `env.keys_rendered` checks that `AppEnv` has the getter of
  /// every key; a test of the role in a running app shows that each returns
  /// its value. Import the class with [RequiredSymbol.importRef].
  static const appEnv = RequiredClass(_appEnv, path: readerFile);

  @override
  String get id => 'env';

  @override
  String get description => 'Values in .env';

  /// The role as messages name it, `env role`: its [description] titles a
  /// question and a section, but reads badly before the word role, as in
  /// the only provider of the values in .env role.
  @override
  String toString() => 'env role';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  RoleInterface get interface => const RoleInterface(
        files: [dotEnvFile, exampleFile],
        symbols: [appEnv],
      );

  @override
  RoleTemplate<EnvData> get template => const _EnvTemplate();

  @override
  List<ModuleRule<EnvData>> get moduleRules => const [
        ModuleRule(
          id: 'env.keys',
          description: 'The keys of a module have names in UPPER_SNAKE_CASE '
              'of two words or more that start with the id of the module in '
              'upper case and an underscore, never with FLUTTER_, each once '
              'and each with a getter of its own, and a description of one '
              'line of at most 100 characters without a backslash. A '
              'variable of a brick of the module that reads a value of the '
              'role reads a key of the module or of a module that it depends '
              'on. Only a provider of the role gives it tool arguments, at '
              'most once, each argument one line that is not empty.',
          check: _checkKeys,
        ),
      ];

  @override
  List<StructuralRule<EnvData>> get structuralRules => const [
        StructuralRule(
          id: 'env.keys_rendered',
          description: 'The AppEnv of the provider of the role declares a '
              'static getter for every key of the app.',
          check: _checkKeysRendered,
        ),
        StructuralRule(
          id: 'env.key_access',
          description: 'The files of a module with the role among its roles '
              'read from AppEnv only the getters of its own keys and of the '
              'keys of the modules it depends on, and the files of the '
              'template of a role, and of the pipeline, read none. The rule '
              'sees what a file reads from AppEnv, with or without the '
              'prefix of an import, and no value that it reads through '
              'another expression.',
          check: _checkKeyAccess,
        ),
      ];

  /// The keys of the app in [input], the input of a hook of this role, of
  /// its provider, or of a role that requires or uses this role: those of
  /// the modules, in the order the modules were selected. The keys of one
  /// module keep its order. The template of a role gives no key, which the
  /// template of this role reports.
  ///
  /// The files of the template list the keys in this order, and a provider
  /// declares the getter of each in [appEnv].
  List<AppEnvKey> keysIn(RoleHookInput<Object> input) => [
        for (final data in dataIn(input))
          if (data.value case final EnvKey key)
            // Every data that a hook gets has an origin.
            AppEnvKey._(_ownerOf(data.origin!), key),
      ];

  /// The arguments that the provider of the role in [input], the input of
  /// a hook of this role, of its provider, or of a role that requires or
  /// uses this role, needs on every command of the `flutter` tool that
  /// builds, runs or tests the app, so that the values of [dotEnvFile]
  /// reach [appEnv]; empty for a provider that needs none.
  ///
  /// The role says nothing of what they mean. Code that runs such a
  /// command for the app, such as a test tool or the run configuration of
  /// an IDE, passes them as they are, in their order, after the name of
  /// the command: `flutter test <arguments>`. Such a command gives `AppEnv`
  /// the values that [dotEnvFile] has when it runs, and nothing else runs
  /// after [dotEnvFile] changes: the next command has the new values.
  List<String> toolArgumentsIn(RoleHookInput<Object> input) => [
        for (final data in dataIn(input))
          if (data.value case EnvToolArguments(:final arguments)) ...arguments,
      ];

  /// The variables that read the values of the [keys] of [module] in a
  /// brick of the module: for each key, `env_<key>` with the key in lower
  /// snake_case, such as `env_revenuecat_apple_key` for
  /// `REVENUECAT_APPLE_KEY`.
  ///
  /// Each is a [RoleVar] of this role: `AppEnv.<getter>`, with the import of
  /// [readerFile], in an app with the role, and `null` in an app without
  /// it. So a template reads `{{{env_revenuecat_apple_key}}}` where its
  /// code takes a `String?`, outside mustache sections and not inside a
  /// `const` expression, since a getter is no constant. The module lists
  /// this role among its roles and gives it the same [keys] as data. A
  /// module that reads a key of a module that it depends on makes the
  /// variable with the id of that module: the rule `env.keys` reports a
  /// variable that reads a key that neither the module nor a module that it
  /// depends on gives the role.
  ///
  /// Throws an [ArgumentError] with the problems of [keys], if they have
  /// any, as the rule `env.keys` reports them, so that the module fails to
  /// contribute in every app, with or without this role.
  Map<String, RoleVar> varsOf(ModuleId module, List<EnvKey> keys) {
    final problems = _keyProblems(keys, module.value);
    if (problems.isNotEmpty) throw ArgumentError(problems.join(' '));
    return {
      for (final key in keys)
        key._variable: RoleVar(
          this,
          present: _read(key.getter),
          absent: 'null',
        ),
    };
  }
}

/// The name of the class of [EnvRole.appEnv].
const _appEnv = 'AppEnv';

/// The code that reads the value of the key whose getter is [getter].
Fragment _read(String getter) =>
    Fragment('$_appEnv.$getter', imports: [EnvRole.appEnv.importRef]);
