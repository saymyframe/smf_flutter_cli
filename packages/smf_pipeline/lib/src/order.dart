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

  /// The modules and templates on a cycle of edges through contributors,
  /// including those that do not contribute, or empty if there is none.
  /// The contributors on a cycle are ordered by name among themselves.
  final List<String> cycle;
}

/// The name of the contributor [origin] in an order: the module id, which
/// a module's variant shares, or `role:<id>` for a role template.
String contributorName(ContributionOrigin origin) => switch (origin) {
      ModuleOrigin(:final module) => module.value,
      RoleTemplateOrigin() || PipelineOrigin() => '$origin',
    };

/// Orders [contributions], all to one socket or all post-generation steps,
/// by the rules of [SocketContribution]. The rules give edges between all
/// modules of the app and the templates of its roles:
/// 1. A module comes after the modules it depends on.
/// 2. A module comes after the providers of the roles it requires, or has in
///    the [Contribution.when] of one of these contributions, and after the
///    templates of these roles.
/// 3. A role template comes after the providers of its role, and after the
///    providers and templates of the roles its role requires or has in its
///    contributions' conditions.
///
/// Two contributors with edges both ways ignore both, unless one depends on
/// the other, which then comes after it. A contributor then
/// comes after every contributor it reaches through the edges, even through
/// modules that do not contribute to the socket, such as a module that
/// requires a role coming after the modules its provider depends on.
/// Otherwise contributors are ordered by name, and each contributor's
/// contributions keep their order. Contributors on a cycle of edges are
/// reported in [ContributionOrder.cycle] and ordered by name among
/// themselves.
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
  Set<Role> whenRolesOf(String name) => {
        for (final collected in byContributor[name] ?? const <Collected>[])
          ...collected.contribution.when,
      };

  // The edges of the whole app, before → after, with a reason each.
  final raw = <String, Map<String, String>>{};
  final dependencies = <(String, String)>{};
  void edge(String before, String after, String reason) {
    if (before != after) {
      raw.putIfAbsent(after, () => {}).putIfAbsent(before, () => reason);
    }
  }

  void roleEdges(String after, Iterable<Role> required, Set<Role> when) {
    for (final role in {...required, ...when}) {
      final verb = required.contains(role) ? 'requires' : 'uses';
      for (final provider in resolution.providersOf(role)) {
        edge(provider.id.value, after, '$after $verb the ${role.id}');
      }
      // The template of the role makes it ready, as by initAnalytics().
      final template = 'role:${role.id}';
      if (names.contains(template)) {
        edge(template, after, '$after $verb the ${role.id}');
      }
    }
  }

  for (final module in resolution.modules) {
    final name = module.id.value;
    for (final dependency in module.descriptor.dependsOn) {
      edge(dependency.value, name, '$name depends on $dependency');
      dependencies.add((dependency.value, name));
    }
    roleEdges(name, module.descriptor.effectiveRequires, whenRolesOf(name));
  }
  for (final name in names) {
    if (origins[name] case RoleTemplateOrigin(:final role)) {
      for (final provider in resolution.providersOf(role)) {
        edge(
          provider.id.value,
          name,
          '$name comes after the providers of the ${role.id}',
        );
      }
      roleEdges(name, role.requires, whenRolesOf(name));
    }
  }

  // Edges both ways cancel out, except that a module comes after a module
  // it depends on in any case.
  final mutual = [
    for (final MapEntry(key: after, value: befores) in raw.entries)
      for (final before in befores.keys)
        if (raw[before]?.containsKey(after) ?? false) (before, after),
  ];
  for (final (before, after) in mutual) {
    if (dependencies.contains((before, after)) &&
        !dependencies.contains((after, before))) {
      continue;
    }
    raw[after]!.remove(before);
  }

  final components = _components(raw);
  // The modules and templates on the cycles that reach the contributors,
  // including those that do not contribute to the socket.
  final cycle = {
    for (final name in names)
      if (components[name] case final component? when component.length > 1)
        ...component,
  }.toList()
    ..sort();

  // The edges between the contributors, through any path of the app.
  final edges = <OrderEdge>[];
  final predecessors = {for (final name in names) name: <String>{}};
  for (final after in names) {
    final reached = _reachedBackwards(after, raw);
    for (final MapEntry(key: before, value: path) in reached.entries) {
      final component = components[after];
      if (!names.contains(before) ||
          (component != null && component.contains(before))) {
        continue;
      }
      predecessors[after]!.add(before);
      final hops = [...path, after];
      edges.add(
        OrderEdge(
          before,
          after,
          [
            for (var i = 1; i < hops.length; i++) raw[hops[i]]![hops[i - 1]]!,
          ].join('; '),
        ),
      );
    }
  }

  // Kahn's algorithm, taking the smallest name among the contributors
  // whose predecessors are all placed.
  final placed = <String>[];
  final remaining = names.toSet();
  while (remaining.isNotEmpty) {
    final ready = remaining
        .where((name) => predecessors[name]!.every(placed.contains))
        .toList()
      ..sort();
    placed.add(ready.first);
    remaining.remove(ready.first);
  }

  return ContributionOrder(
    contributions: [
      for (final name in placed) ...byContributor[name]!,
    ],
    edges: edges..sort((a, b) => '$a'.compareTo('$b')),
    cycle: cycle,
  );
}

/// The contributors that come before [after] through the edges of [raw],
/// each with the path to it: the contributor itself first, then the
/// contributors on the way, ending with a direct predecessor of [after].
Map<String, List<String>> _reachedBackwards(
  String after,
  Map<String, Map<String, String>> raw,
) {
  final paths = <String, List<String>>{};
  final queue = <(String, List<String>)>[(after, const [])];
  while (queue.isNotEmpty) {
    final (current, path) = queue.removeAt(0);
    for (final before in raw[current]?.keys ?? const <String>[]) {
      if (before == after || paths.containsKey(before)) continue;
      final next = [before, ...path];
      paths[before] = next;
      queue.add((before, next));
    }
  }
  return paths;
}

/// The strongly connected components of the graph of [raw], by node: the
/// nodes that reach each other through the edges.
Map<String, Set<String>> _components(Map<String, Map<String, String>> raw) {
  final nodes = {
    ...raw.keys,
    for (final befores in raw.values) ...befores.keys,
  };
  final components = <String, Set<String>>{};
  for (final node in nodes) {
    if (components.containsKey(node)) continue;
    final before = _reachedBackwards(node, raw).keys.toSet();
    final after = {
      for (final other in nodes)
        if (other != node && _reachedBackwards(other, raw).containsKey(node))
          other,
    };
    final component = {node, ...before.intersection(after)};
    for (final member in component) {
      components[member] = component;
    }
  }
  return components;
}
