import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_event_bus/bundles/smf_event_bus_brick_bundle.dart';

class SmfEventBusModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
        BrickContribution(
            name: 'smf event bus', bundle: smfEventBusBrickBundle),
      ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
        name: kCommunicationModule,
        description: 'Communication between modules build on top of event bus',
        pubDependency: {'event_bus: ^2.0.1', 'equatable: ^2.0.7'},
      );

  @override
  List<DiDependencyGroup> get di => [
        DiDependencyGroup(
          diDependencies: [
            DiDependency(
              abstractType: 'ICommunicationService',
              implementation: 'EventBusService(EventBus())',
              bindingType: DiBindingType.singleton,
            ),
          ],
          scope: DiScope.core,
          imports: [
            Import.core(
              ImportAnchor.coreService,
              'communication/event_bus/event_bus_service.dart',
            ),
            Import.core(
              ImportAnchor.coreService,
              'communication/i_communication_service.dart',
            ),
            Import.direct("import 'package:event_bus/event_bus.dart';"),
          ],
        ),
      ];
}
