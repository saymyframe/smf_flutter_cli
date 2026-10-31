import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_github_actions/smf_github_actions.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:yaml/yaml.dart';

/// A module for the tests that gives the env role two keys.
final class ShopModule extends SmfModule {
  /// Creates the module.
  const ShopModule();

  /// The id of the module.
  static const id = ModuleId('shop');

  /// The names of the keys of the module, in their order.
  static const keys = ['SHOP_APPLE_KEY', 'SHOP_TERMS_URL'];

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'The values of a shop (test)',
        kind: ModuleKinds.infrastructure,
        requires: {envRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        envRole.data(
          EnvKey(keys.first, description: 'The public key of the shop'),
        ),
        envRole.data(
          EnvKey(keys.last, description: 'The address of the terms'),
        ),
      ];
}

/// The modules of the tests: flutter_core, which creates the app, the module,
/// a provider of the env role, and a module with keys.
const List<SmfModule> testModules = [
  FlutterCoreModule(),
  DartDefineModule(),
  GithubActionsModule(),
  ShopModule(),
];

/// The app of the module without the env role.
const List<ModuleId> withoutEnv = [GithubActionsModule.id];

/// The app of the module with the env role, whose modules give it no key.
const List<ModuleId> withEnv = [GithubActionsModule.id, DartDefineModule.id];

/// The app of the module with the env role and the keys of [ShopModule].
const List<ModuleId> withKeys = [
  GithubActionsModule.id,
  DartDefineModule.id,
  ShopModule.id,
];

/// What the contract harness finds for the app of [modules], which has no
/// errors and is rendered.
Future<ContractResult> renderedApp(List<ModuleId> modules) async {
  final result = await ContractHarness(ModuleRegistry(testModules)).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The text of the workflow of the app of [result].
String workflowTextOf(ContractResult result) =>
    result.app!.files[GithubActionsModule.workflowFile]!.text;

/// What the role gives as the pipeline of the app of [result].
CiPipeline pipelineOf(ContractResult result) =>
    ciRole.pipelineIn(ciRole.hookInput(result.hook!));

/// [text], a workflow, as YAML reads it.
YamlMap parsedWorkflow(String text) => loadYaml(text) as YamlMap;
