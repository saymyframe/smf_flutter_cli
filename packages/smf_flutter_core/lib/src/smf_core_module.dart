import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/bundles/smf_flutter_core_bundle.dart';

class SmfCoreModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
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
  List<DiDependencyGroup> get di => [
    DiDependencyGroup(
      diDependencies: [
        DiDependency(
          abstractType: 'ISystemService',
          implementation: 'SystemService()',
          bindingType: DiBindingType.singleton,
        ),
      ],
      scope: DiScope.core,
      imports: [
        DiImport.core(
          DiImportAnchor.coreService,
          'system/i_system_service.dart',
        ),
        DiImport.core(DiImportAnchor.coreService, 'system/system_service.dart'),
      ],
    ),
  ];
}
