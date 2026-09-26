import 'package:smf_contracts/lego_core.dart';

/// The state management role; see [StateManagementRole].
const stateManagementRole = StateManagementRole._();

/// The role of the library that holds the state of screens, such as BLoC or
/// Riverpod.
///
/// It has no data, sockets or generated interface: the screens of a feature
/// use the library directly. A feature supports several libraries through
/// [Variants] of this role, keyed by the id of the provider module, and the
/// provider adds what the library needs to the app, such as Riverpod's
/// `ProviderScope` around the root widget.
final class StateManagementRole extends Role<NoDsl> {
  const StateManagementRole._();

  @override
  String get id => 'state_management';

  @override
  String get description => 'State management';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;
}
