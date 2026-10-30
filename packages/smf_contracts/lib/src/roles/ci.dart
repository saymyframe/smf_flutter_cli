import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/ci_role_env_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

part 'ci/ci_pipeline.dart';
part 'ci/ci_rules.dart';
part 'ci/ci_template.dart';

/// The CI role; see [CiRole].
const ciRole = CiRole._();

/// The role of the continuous integration of the app: what runs on a server
/// once the developer pushes the app to a repository, and what builds the app
/// for an environment on request.
///
/// The role knows what runs and not where. An app has at most one provider,
/// since a repository lives on one host. [pipelineIn] gives the commands as
/// data, the same for every provider, and the provider writes them in the
/// format of its host, from its render hook. A file with such a format comes
/// from [RoleOutput.files], since its syntax may read like a tag of a brick.
/// The modules give the role nothing: what the app needs before a command
/// runs is in git or comes from `flutter pub get`.
///
/// A provider keeps to the following, which only its own tests and a real run
/// on its host can show:
/// - on each push, a job runs [CiPipeline.checks] in their order, in a fresh
///   copy of the repository, without any setup by the developer;
/// - on request, the developer chooses one of [CiBuild.environments], the
///   first by default. A job then runs [CiBuild.prepare] in their order, with
///   a variable of the process for each of [CiBuild.keys] that has the value
///   of that environment, runs [CiBuild.command] for the environment, and
///   keeps the file [CiBuild.artifact] of the environment;
/// - each command runs in a POSIX shell at the root of the repository, on a
///   machine with the Flutter SDK and a JDK, which the provider sets up;
/// - a value reaches a command only as a variable of the process, and never
///   as a part of the text of a script, so that no value runs as code.
///
/// The template of the role generates, in an app with the env role,
/// [writeEnvFile], the script that writes [EnvRole.dotEnvFile] for a build.
/// It also writes the section [readmeHeading] of the README of the app, and
/// the notes of the role in the guide for coding agents. A provider tells in a
/// section of its own how a developer starts a build on its host, and where
/// the values of an environment go.
///
/// The rule `ci.pipeline_rendered` checks that the files of the provider have
/// the commands. It reads text, so it sees what the files have and not what
/// they do; see [CiRole.structuralRules].
final class CiRole extends Role<NoDsl> {
  const CiRole._();

  /// The heading of the section of the README of the app in which the
  /// template tells what CI runs.
  static const readmeHeading = 'Continuous integration';

  /// The path of the script that writes [EnvRole.dotEnvFile] for a build, in
  /// an app with the env role.
  ///
  /// It reads the keys from [EnvRole.exampleFile] when it runs, and the
  /// value of each from the variable of the process of the same name.
  /// It stops and writes nothing when [EnvRole.dotEnvFile] has a value, so it
  /// never replaces what a developer filled in, and a job that runs it starts
  /// from a copy of the repository, which has no such file.
  static const writeEnvFile = 'tool/write_env.dart';

  @override
  String get id => 'ci';

  @override
  String get description => 'CI';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get uses => const {envRole};

  @override
  RoleTemplate<NoDsl> get template => const _CiTemplate();

  /// The rule `ci.pipeline_rendered`.
  ///
  /// It looks at the files of the provider other than Dart files, line by
  /// line, and leaves out each line that starts with `#` or `//`. So it does
  /// not know the format of a file, and a provider may have the commands in
  /// several files. It sees presence and not structure: a command in the wrong
  /// job, a job that never runs, or the value of one key given to the variable
  /// of another all pass it. Those are for the tests of the provider, which
  /// parse its format, and for a real run on its host.
  @override
  List<StructuralRule<NoDsl>> get structuralRules => const [
        StructuralRule(
          id: 'ci.pipeline_rendered',
          description: 'The files of the provider of the role, other than '
              'Dart files, have outside their comments each command of the '
              'checks and of the preparation of a build at the end of a line, '
              'the command of the build at the end of a line, with the name '
              'of an environment or something that stands for it, the file '
              'that the build keeps, and each environment and each key as a '
              'whole word.',
          check: _checkPipelineRendered,
        ),
      ];

  /// What CI of the app runs, for [input], the input of a hook of this role
  /// or of its provider.
  ///
  /// The arguments of [EnvRole.toolArgumentsIn] go on `flutter test` and on
  /// `flutter build` as they are. With the env role, the checks start from a
  /// copy of [EnvRole.exampleFile], so every value is empty there, and a
  /// build starts from [writeEnvFile].
  ///
  /// The format check names `lib` and `test`, which every app has, since
  /// `flutter pub get` may write Dart files of tools below `build/`, which
  /// are not formatted. `flutter analyze` takes no tool arguments.
  CiPipeline pipelineIn(RoleHookInput<Object> input) {
    final hasEnv = input.has(envRole);
    final arguments = envRole.toolArgumentsIn(input).join(' ');
    String withArguments(String command) =>
        arguments.isEmpty ? command : '$command $arguments';
    const packages = CiCommand._('Get the packages', 'flutter pub get');
    return CiPipeline._(
      checks: [
        if (hasEnv)
          const CiCommand._(
            'Copy ${EnvRole.exampleFile} to ${EnvRole.dotEnvFile}',
            'cp ${EnvRole.exampleFile} ${EnvRole.dotEnvFile}',
          ),
        packages,
        const CiCommand._(
          'Check the format',
          'dart format --output=none --set-exit-if-changed lib test',
        ),
        const CiCommand._('Analyze', 'flutter analyze'),
        CiCommand._('Test', withArguments('flutter test')),
      ],
      build: CiBuild._(
        environments: [for (final flavor in AppEntryRole.flavors) flavor.name],
        prepare: [
          if (hasEnv)
            const CiCommand._(
              'Write ${EnvRole.dotEnvFile} from the variables of the '
                  'environment',
              'dart $writeEnvFile',
            ),
          packages,
        ],
        keys: [for (final key in envRole.keysIn(input)) key.name],
        name: 'Build the Android app',
        command: CiPerEnvironment._(
          'flutter build apk --release --flavor ',
          arguments.isEmpty ? '' : ' $arguments',
        ),
        artifact: const CiPerEnvironment._(
          'build/app/outputs/flutter-apk/app-',
          '-release.apk',
        ),
      ),
    );
  }
}
