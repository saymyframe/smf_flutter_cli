import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/resolver.dart';

/// A contribution with who made it and whether it applies in the app.
final class Collected {
  /// Creates the collected [contribution] of [origin].
  const Collected(this.contribution, this.origin, {required this.applies});

  /// The contribution; a [RoleData] or [SocketContribution] carries
  /// [origin] too.
  final Contribution contribution;

  /// Who contributed it.
  final ContributionOrigin origin;

  /// Whether it applies: every role in its [Contribution.when] is present
  /// and, for [RoleData] and for a [SocketContribution] to a socket of a
  /// role, that role is.
  final bool applies;
}

/// Stage 4 of the pipeline: the contributions of every module, of the
/// variants that apply, and of the templates of the present roles.
final class Collection {
  /// Creates the collection.
  const Collection(this.all, {this.issues = const []});

  /// All contributions, in the order of the modules, then of the role
  /// templates in the order of the present roles; each module's variant
  /// comes after the module's own contributions.
  final List<Collected> all;

  /// A problem for every module or template that failed to contribute.
  final List<SmfIssue> issues;

  /// The contributions that apply in the app.
  Iterable<Collected> get applying => all.where((c) => c.applies);

  /// The contributions of type [T] that apply.
  Iterable<Collected> applyingOf<T extends Contribution>() =>
      applying.where((c) => c.contribution is T);

  /// The data of all roles that applies, in the order of the modules.
  List<RoleData<Object>> get roleData => [
        for (final collected in applying)
          if (collected.contribution case final RoleData<Object> data) data,
      ];

  /// The contributions of the module [id], its variant's included.
  List<Collected> ofModule(ModuleId id) => [
        for (final collected in all)
          if (collected.origin case ModuleOrigin(:final module)
              when module == id)
            collected,
      ];
}

/// Stage 4 of the pipeline: collects the contributions of the modules in
/// [resolution] and of the templates of its present roles for the app
/// described by [context].
///
/// Each [RoleData] and [SocketContribution] gets its origin. Contributions
/// that do not apply are kept, so that validation can check them too.
///
/// Like data, code for a socket of a role applies only when the role is
/// present: without the role, no template has the socket's tag.
///
/// A module or template that fails to contribute gets an issue with its
/// origin instead, so lenient mode can leave the module out.
Collection collect(Resolution resolution, ModuleContext context) {
  final present = resolution.presentRoles;
  final all = <Collected>[];
  final issues = <SmfIssue>[];

  void addAll(
    ContributionOrigin origin,
    List<Contribution> Function() contribute,
  ) {
    final List<Contribution> contributions;
    try {
      contributions = contribute();
    } on Object catch (error) {
      issues.add(
        SmfIssue('$origin failed to contribute: $error', origin: origin),
      );
      return;
    }
    for (final contribution in contributions) {
      final role = switch (contribution) {
        RoleData(:final role) => role,
        SocketContribution(:final socket) => socket.role,
        _ => null,
      };
      final applies = contribution.when.every(present.contains) &&
          (role == null || present.contains(role));
      all.add(
        Collected(
          switch (contribution) {
            final RoleData<Object> data => data.withOrigin(origin),
            final SocketContribution socket => socket.withOrigin(origin),
            _ => contribution,
          },
          origin,
          applies: applies,
        ),
      );
    }
  }

  for (final module in resolution.modules) {
    addAll(module.origin, () => module.module.contribute(context));
    final variant = module.variant;
    final variants = module.descriptor.variants;
    if (variant != null && variants != null) {
      final contribute = variants.byProvider[variant];
      if (contribute != null) {
        addAll(
          ModuleOrigin(module.id, variant: variant),
          () => contribute(context),
        );
      }
    }
  }
  for (final role in present) {
    final template = role.template;
    if (template != null) {
      addAll(RoleTemplateOrigin(role), () => template.contribute(context));
    }
  }
  return Collection(List.unmodifiable(all), issues: List.unmodifiable(issues));
}
