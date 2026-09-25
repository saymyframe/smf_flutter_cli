import 'package:mason/mason.dart' show MasonBundle;
import 'package:meta/meta.dart';
import 'package:smf_contracts/lego_core.dart';

part 'contributions/brick_contribution.dart';
part 'contributions/codegen_request.dart';
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
/// - [PostGenStep]: a command to run in the generated app.
@immutable
sealed class Contribution {
  const Contribution({this.when = const {}});

  /// Roles that must all be present for the contribution to apply.
  ///
  /// A module lists roles here that it only uses (see
  /// [ModuleDescriptor.uses]), so that code referring to their symbols is
  /// generated only in apps that have them. Every role in [when] must be one
  /// of the contributor's roles.
  final Set<Role> when;
}
