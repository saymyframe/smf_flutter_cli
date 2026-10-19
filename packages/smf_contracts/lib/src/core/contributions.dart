import 'package:mason/mason.dart' show MasonBundle;
import 'package:meta/meta.dart';
import 'package:smf_contracts/core.dart';

part 'contributions/brick_contribution.dart';
part 'contributions/codegen_request.dart';
part 'contributions/manual_step.dart';
part 'contributions/post_gen_step.dart';
part 'contributions/preflight.dart';
part 'contributions/pubspec_contribution.dart';
part 'contributions/role_data.dart';
part 'contributions/socket_contribution.dart';

/// Something a module or a role template adds to the app.
///
/// Modules return contributions from [SmfModule.contribute] and its
/// [Variants], role templates from [RoleTemplate.contribute]. Contributions
/// are plain data: the pipeline collects them from every selected module
/// before it validates anything, and renders the app only after that.
///
/// The kinds of contributions are fixed, because the pipeline handles each
/// of them:
/// - [BrickContribution]: template files;
/// - [SocketContribution]: code or values for a socket;
/// - [RoleData]: data in the language of a role, such as routes;
/// - [PubspecContribution]: dependencies and `pubspec.yaml` settings;
/// - [CodegenRequest]: a request to run `build_runner`;
/// - [Preflight]: checks of the machine before generation;
/// - [PostGenStep]: a command to run in the generated app;
/// - [ManualStep]: a step of the setup that the developer of the app does
///   by hand.
@immutable
sealed class Contribution {
  const Contribution({this.when = const {}, this.whenChosen = const {}});

  /// Roles that must all be present for the contribution to apply.
  ///
  /// A module lists roles here that it only uses (see
  /// [ModuleDescriptor.uses]), so that code referring to their symbols is
  /// generated only in apps that have them. Every role in [when] must be one
  /// of the contributor's roles.
  final Set<Role> when;

  /// Conditions on what roles chose, which must all hold for the
  /// contribution to apply, besides [when]; see [ChoiceCondition].
  ///
  /// Only a [BrickContribution] and [RoleData] take them. The pipeline needs
  /// the other kinds before any role chooses: the pubspec, the checks of
  /// the machine, the steps after generation and the steps by hand when it
  /// validates the app, and the code for sockets when it orders their
  /// contributors.
  ///
  /// Validation treats a contribution with conditions as one that applies,
  /// and the app has it once the roles have chosen only if every condition
  /// holds. The pipeline reports, as errors:
  /// - a condition of a role that the contributor does not provide, require
  ///   or use, as for [when]; for the template of a role, the role itself
  ///   or a role that it requires or uses;
  /// - data of a role with a condition of the same role, which chooses
  ///   from its data;
  /// - conditions on the data of roles that form a cycle, such as data of
  ///   one role that depends on what a second role chose, while data of the
  ///   second depends on what the first chose: neither could choose first;
  /// - a tag of a socket in a brick with conditions: an app where they do
  ///   not hold leaves the brick out, and what the socket gets would be
  ///   lost with it.
  final Set<ChoiceCondition> whenChosen;
}
