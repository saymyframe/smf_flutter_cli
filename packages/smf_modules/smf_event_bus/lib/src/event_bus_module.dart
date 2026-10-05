import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_event_bus/bundles/event_bus_bundle.dart';
import 'package:smf_event_bus/src/agents.dart';

/// The module that delivers the events of the app with the event_bus
/// package, and so provides the events role.
///
/// The template of the role generates the `CommunicationService` interface
/// and `AppEvent`, the base class of the events. This module adds
/// `event_bus` to the dependencies of the app and implements the service in
/// `lib/core/events/event_bus_communication_service.dart`, on an `EventBus`
/// that delivers an event to everyone listening to its type, or to a type
/// it extends or implements, after the code that fires it has completed.
///
/// The service is created on first use, without waiting, so the app starts
/// as it would without it. When the app has a DI container, the role
/// registers the service in it.
///
/// In the guide for coding agents, the module adds to the section of the
/// events which events a listener gets with event_bus, and when.
final class EventBusModule extends SmfModule {
  /// Creates the module.
  const EventBusModule();

  /// The id of the module.
  static const id = ModuleId('event_bus');

  static const _file = ImportRef.app(
    'core/events/event_bus_communication_service.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Event bus with event_bus',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(eventsRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(eventBusBundle),
        const PubspecContribution.hosted('event_bus', '^2.0.1'),
        eventsRole.data(
          const RoleImplementation(
            type: TypeRef('EventBusCommunicationService', import: _file),
            create: FactoryRef(
              'createEventBusCommunicationService',
              import: _file,
            ),
          ),
        ),
        AppEntryRole.agentSections.entry(
          eventsRole.description,
          AgentNote(agentNote),
        ),
      ];
}
