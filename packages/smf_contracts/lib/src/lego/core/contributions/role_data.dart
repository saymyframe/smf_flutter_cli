part of '../contributions.dart';

/// Data for a role in the role's own language, such as the routes of a
/// feature for the router role.
///
/// The type [D] is the data type of [role], and a role with no data has the
/// data type [NoDsl], so no data can be created for it. Hooks of the role
/// and its providers receive the data of all modules in the order the modules
/// were selected (see [RoleHookInput.data]).
///
/// Data applies only when [role] is present, in addition to [when]: a
/// module that only uses a role can contribute data to it unconditionally.
final class RoleData<D extends Object> extends Contribution {
  /// Creates the data [value] for [role].
  const RoleData(this.role, this.value, {super.when}) : origin = null;

  const RoleData._(
    this.role,
    this.value, {
    required this.origin,
    required super.when,
  });

  /// The role the data is for.
  final Role<D> role;

  /// The data.
  final D value;

  /// Who contributed the data.
  ///
  /// The pipeline sets it with [withOrigin] when it collects contributions,
  /// so every data a hook receives has one. It is `null` in data a module
  /// has just created.
  final ContributionOrigin? origin;

  /// Returns a copy of this data contributed by [origin].
  RoleData<D> withOrigin(ContributionOrigin origin) =>
      RoleData<D>._(role, value, origin: origin, when: when);
}
