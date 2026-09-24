import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_event_bus/bundles/smf_event_bus_brick_bundle.dart';

/// Adds an `ICommunicationService` built on the event_bus package, through
/// which features exchange events without importing each other, and
/// registers it as a core singleton.
class SmfEventBusModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
        BrickContribution(
          name: 'smf event bus',
          bundle: smfEventBusBrickBundle,
        ),
      ];

  @override
  ModuleDescriptor get moduleDescriptor => const ModuleDescriptor(
        name: kCommunicationModule,
        description: 'Communication between modules build on top of event bus',
        pubDependency: {'event_bus: ^2.0.1', 'equatable: ^2.0.7'},
      );

  @override
  List<DiDependencyGroup> get di => [
        DiDependencyGroup(
          diDependencies: [
            const DiDependency(
              abstractType: 'ICommunicationService',
              implementation: 'EventBusService(EventBus())',
              bindingType: DiBindingType.singleton,
            ),
          ],
          scope: DiScope.core,
          imports: [
            const Import.core(
              ImportAnchor.coreService,
              'communication/event_bus/event_bus_service.dart',
            ),
            const Import.core(
              ImportAnchor.coreService,
              'communication/i_communication_service.dart',
            ),
            const Import.direct("import 'package:event_bus/event_bus.dart';"),
          ],
        ),
      ];
}
