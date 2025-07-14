import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/bundles/smf_flutter_core_bundle.dart';
import 'package:smf_sharable_bricks/smf_sharable_bricks.dart';

class SmfCoreModule implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(name: 'flutter_core', bundle: smfFlutterCoreBundle),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kFlutterCoreModule,
    description: 'Core Flutter application module module',
    dependsOn: {kCommunicationModule, kGetItModule},
    pubDependency: {'flutter_bloc: ^9.1.1', 'freezed_annotation: ^3.1.0'},
    pubDevDependency: {'build_runner: ^2.5.4', 'freezed: ^3.1.0'},
  );

  @override
  List<SharedFileContribution> get sharedFileContributions => [
    SharedFileContribution(
      bundle: smfCoreDiBrickBundle,
      slot: CoreDiSharedCodeSlots.imports,
      content: '''
      import 'package:{{app_name_sc}}/core/services/system/i_system_service.dart';
      import 'package:{{app_name_sc}}/core/services/system/system_service.dart';
      ''',
    ),
    SharedFileContribution(
      bundle: smfCoreDiBrickBundle,
      slot: CoreDiSharedCodeSlots.di,
      content: '''
      getIt.registerLazySingleton<ISystemService>(SystemService.new);
        ''',
    ),
  ];
}
