import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/resolver.dart';

/// An edge of the order of contributors: [before] comes before [after].
final class OrderEdge {
  /// Creates the edge.
  const OrderEdge(this.before, this.after, this.reason);

  /// The contributor that comes first, such as `firebase_core`.
  final String before;

  /// The contributor that comes after it, such as `role:analytics`.
  final String after;

  /// Why, as a phrase such as `firebase_analytics depends on
  /// firebase_core`.
  final String reason;

  @override
  String toString() => '$before → $after ($reason)';
}

/// The contributions of a socket, or the post-generation steps, in the
/// order they render or run.
final class ContributionOrder {
  /// Creates the order.
  const ContributionOrder({
    required this.contributions,
    required this.edges,
    this.cycle = const [],
  });

  /// The contributions in their final order.
  final List<Collected> contributions;

  /// The edges between the contributors, after mutual edges cancelled out.
  final List<OrderEdge> edges;

  /// The contributors on a cycle of edges, or empty if there is none. With
  /// a cycle, the contributors on it are ordered by name.
  final List<String> cycle;
}

/// The name of the contributor [origin] in an order: the module id, which
/// a module's variant shares, or `role:<id>` for a role template.
String contributorName(ContributionOrigin origin) => switch (origin) {
      ModuleOrigin(:final module) => module.value,
      RoleTemplateOrigin() || PipelineOrigin() => '$origin',
    };

/// Orders [contributions], all to one socket or all post-generation steps,
/// by the rules of [SocketContribution]:
/// 1. After the modules the contributor depends on, directly or not.
/// 2. After the providers of the roles the contributor requires or has in
///    the [Contribution.when] of one of these contributions.
/// 3. A role template after the providers of its role and the modules those
///    depend on, directly or not.
/// 4. Otherwise by the name of the contributor.
///
/// Only edges between the contributors of [contributions] count; edges both
/// ways cancel out. Each contributor's contributions keep their order.
ContributionOrder orderContributions(
  List<Collected> contributions,
  Resolution resolution,
) {
  final byContributor = <String, List<Collected>>{};
  final origins = <String, ContributionOrigin>{};
  for (final collected in contributions) {
    final name = contributorName(collected.origin);
    byContributor.putIfAbsent(name, () => []).add(collected);
    origins.putIfAbsent(name, () => collected.origin);
  }
  final names = byContributor.keys.toSet();

  final candidates = <(String, String), String>{};
  void edge(String before, String after, String reason) {
    if (before != after && names.contains(before)) {
      candidates.putIfAbsent((before, after), () => reason);
    }
  }

  for (final name in names) {
    final origin = origins[name]!;
    switch (origin) {
      case ModuleOrigin(:final module):
        for (final dependency in resolution.dependencyClosure(module)) {
          edge(dependency.value, name, '$name depends on $dependency');
        }
        final descriptor = resolution.module(module)?.descriptor;
        final requires = descriptor?.effectiveRequires ?? const <Role>{};
        final whenRoles = {
          for (final collected in byContributor[name]!)
            ...collected.contribution.when,
        };
        for (final role in {...requires, ...whenRoles}) {
          final verb = requires.contains(role) ? 'requires' : 'uses';
          for (final provider in resolution.providersOf(role)) {
            edge(provider.id.value, name, '$name $verb the ${role.id}');
          }
        }
      case RoleTemplateOrigin(:final role):
        for (final provider in resolution.providersOf(role)) {
          final reason = '$name comes after the providers of the ${role.id}';
          edge(provider.id.value, name, reason);
          for (final dependency in resolution.dependencyClosure(provider.id)) {
            edge(
              dependency.value,
              name,
              '$reason and the modules they depend on',
            );
          }
        }
        final whenRoles = {
          for (final collected in byContributor[name]!)
            ...collected.contribution.when,
        };
        for (final other in {...role.requires, ...whenRoles}) {
          final verb = role.requires.contains(other) ? 'requires' : 'uses';
          for (final provider in resolution.providersOf(other)) {
            edge(provider.id.value, name, '$name $verb the ${other.id}');
          }
        }
      case PipelineOrigin():
        break;
    }
  }

  final edges = [
    for (final MapEntry(key: (before, after), value: reason)
        in candidates.entries)
      if (!candidates.containsKey((after, before)))
        OrderEdge(before, after, reason),
  ];

  // Kahn's algorithm, taking the smallest name among the contributors
  // whose predecessors are all placed.
  final incoming = {for (final name in names) name: <String>{}};
  for (final edge in edges) {
    incoming[edge.after]!.add(edge.before);
  }
  final placed = <String>[];
  final remaining = names.toSet();
  while (remaining.isNotEmpty) {
    final ready = remaining
        .where((name) => incoming[name]!.every(placed.contains))
        .toList()
      ..sort();
    if (ready.isEmpty) break;
    placed.add(ready.first);
    remaining.remove(ready.first);
  }
  final cycle = remaining.toList()..sort();
  placed.addAll(cycle);

  return ContributionOrder(
    contributions: [
      for (final name in placed) ...byContributor[name]!,
    ],
    edges: edges,
    cycle: cycle,
  );
}
