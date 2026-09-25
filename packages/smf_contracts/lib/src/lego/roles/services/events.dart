part of '../services.dart';

/// The events role; see [EventsRole].
const eventsRole = EventsRole._();

/// The role of the channel through which parts of the app that do not know
/// each other exchange events, such as an event bus.
///
/// The role's template generates `lib/core/events/communication_service.dart`
/// with:
/// - `AppEvent`, the base class of every event;
/// - the `CommunicationService` interface: `fire(event)` sends an event to
///   everyone listening to its type through `on<T>()`;
/// - `CommunicationService createCommunicationService()`, which returns the
///   provider's implementation.
///
/// The provider contributes its implementation as a [RoleImplementation].
/// With a DI container, the service is registered as a lazy singleton.
final class EventsRole extends Role<RoleImplementation> {
  const EventsRole._();

  /// The path of the file with `CommunicationService`.
  static const file = 'lib/core/events/communication_service.dart';

  /// The implementation of the service, which the template renders from the
  /// provider's [RoleImplementation]; modules do not contribute to it.
  static const implementations = SocketRef<CodeSocket>.role(
    eventsRole,
    'implementations',
    CodeSocket(),
  );

  @override
  String get id => 'events';

  @override
  String get description => 'Events';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get uses => {diRole};

  @override
  List<SocketRef> get sockets => const [implementations];

  @override
  RoleInterface get interface => const RoleInterface(files: [file]);

  @override
  RoleTemplate<RoleImplementation> get template => const _EventsTemplate();

  @override
  List<ModuleRule<RoleImplementation>> get moduleRules =>
      const [_implementationsRule];

  @override
  List<StructuralRule<RoleImplementation>> get structuralRules => const [
        StructuralRule(
          id: 'events.factory_calls',
          description:
              'Only the DI container calls createCommunicationService().',
          check: _checkEventsFactory,
        ),
      ];
}

List<SmfIssue> _checkEventsFactory(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkFactoryCalls(input, 'createCommunicationService');

final class _EventsTemplate extends _ServiceTemplate {
  const _EventsTemplate();

  @override
  Role<RoleImplementation> get role => eventsRole;

  @override
  MasonBundle get bundle => eventsRoleBundle;

  @override
  String get file => EventsRole.file;

  @override
  String get service => 'CommunicationService';

  @override
  String get factory => 'createCommunicationService';

  @override
  String get initFunction => 'initEvents';

  @override
  String get variable => '_communicationService';

  @override
  SocketRef<CodeSocket> get implementations => EventsRole.implementations;
}
