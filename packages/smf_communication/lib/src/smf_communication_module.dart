import 'package:smf_communication/bundles/smf_event_bus_brick_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_sharable_bricks/smf_sharable_bricks.dart';

class SmfCommunicationModule implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(name: 'smf event bus', bundle: smfEventBusBrickBundle),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: 'Event Bus',
    description: 'Communication between modules build on top of event bus',
    pubDependency: {'event_bus: ^2.0.1', 'equatable: ^2.0.7'},
  );

  @override
  List<SharedFileContribution> get sharedFileContributions => [
    SharedFileContribution(
      bundle: smfCoreDiBrickBundle,
      slot: CoreDiSharedCodeSlots.imports,
      content: '''
      import 'package:{{app_name_sc}}/core/services/communication/event_bus/event_bus_service.dart';
      import 'package:{{app_name_sc}}/core/services/communication/i_communication_service.dart';
      import 'package:event_bus/event_bus.dart';
      ''',
    ),
    SharedFileContribution(
      bundle: smfCoreDiBrickBundle,
      slot: CoreDiSharedCodeSlots.di,
      content: '''
      getIt.registerLazySingleton<ICommunicationService>(
        () => EventBusService(EventBus()),
      );
      ''',
    ),
  ];
}
