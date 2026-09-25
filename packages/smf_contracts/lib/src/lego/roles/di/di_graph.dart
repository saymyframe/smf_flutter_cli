part of '../di.dart';

/// The registrations of an app as a graph of services and what they need,
/// which every DI provider renders the same way.
///
/// It answers what a provider must know beyond each registration:
/// - the order to register the services in ([ordered]): a singleton is
///   created while it is registered, so everything it needs comes first;
/// - which singletons must wait for services created asynchronously
///   ([dependsOnOf]), including those they reach through lazy singletons and
///   factories;
/// - whether `registerDependencies()` must wait for the container to be
///   ready ([needsAllReady]).
///
/// Obtain it with [DiRole.graphOf]. [issues] lists what makes the graph
/// unusable; the answers assume there are none.
final class DiGraph {
  /// Builds the graph of [data], the registrations of the app in the order
  /// the modules were selected.
  DiGraph(Iterable<RoleData<DiRegistration>> data)
      : registrations = List.unmodifiable(data) {
    for (final registration in registrations) {
      _byKey.putIfAbsent(registration.value.key, () => registration);
    }
  }

  /// The registrations, in the order the modules were selected.
  final List<RoleData<DiRegistration>> registrations;

  final Map<ServiceRef, RoleData<DiRegistration>> _byKey = {};
  final Map<ServiceRef, Set<ServiceRef>> _dependsOn = {};
  final Set<ServiceRef> _resolving = {};

  /// The registration of [service], or `null` if no module registers it.
  DiRegistration? registrationOf(ServiceRef service) => _byKey[service]?.value;

  /// The problems of the registrations: those of each one alone, services
  /// registered twice, services needed but not registered, cycles, and
  /// services a singleton waits for that are not created asynchronously.
  List<SmfIssue> get issues {
    final issues = <SmfIssue>[];
    for (final data in registrations) {
      final registration = data.value;
      final origin = data.origin;
      for (final problem in registration.problems()) {
        issues.add(SmfIssue(problem, origin: origin));
      }
      final first = _byKey[registration.key]!;
      if (!identical(first, data)) {
        issues.add(
          SmfIssue(
            '${registration.key} is registered twice, by ${first.origin} and '
            'by $origin.',
            hint: 'Give one of them an instance name.',
            origin: origin,
          ),
        );
        continue;
      }
      for (final service in [
        ...registration.create.deps,
        ...registration.dependsOn,
      ]) {
        if (!_byKey.containsKey(service)) {
          issues.add(
            SmfIssue(
              'The registration of ${registration.key} needs $service, which '
              'no module registers.',
              origin: origin,
            ),
          );
        }
      }
    }
    final cycles = _cycles();
    for (final cycle in cycles) {
      issues.add(
        SmfIssue(
          'The services ${cycle.join(' -> ')} need each other in a cycle.',
          origin: _byKey[cycle.first]!.origin,
        ),
      );
    }
    if (cycles.isNotEmpty) return issues;

    for (final data in registrations) {
      for (final service in data.value.dependsOn) {
        final target = _byKey[service];
        if (target != null && !isAwaitable(target.value)) {
          issues.add(
            SmfIssue(
              'The registration of ${data.value.key} waits for $service, '
              'which is not a singleton created asynchronously or after '
              'other services.',
              hint: 'Remove it from dependsOn: a service that is ready once '
                  'registered needs no waiting.',
              origin: data.origin,
            ),
          );
        }
      }
    }
    return issues;
  }

  /// The registrations in the order to register them: each after the
  /// services it takes or waits for, otherwise in the order of
  /// [registrations].
  ///
  /// A registration in a cycle comes after the others, in its original
  /// order.
  List<DiRegistration> get ordered {
    final result = <DiRegistration>[];
    final done = <ServiceRef>{};
    final visiting = <ServiceRef>{};

    void visit(DiRegistration registration) {
      final key = registration.key;
      if (done.contains(key) || !visiting.add(key)) return;
      for (final service in _edges(registration)) {
        final target = _byKey[service]?.value;
        if (target != null) visit(target);
      }
      visiting.remove(key);
      if (done.add(key)) result.add(registration);
    }

    for (final data in registrations) {
      if (identical(_byKey[data.value.key], data)) visit(data.value);
    }
    return List.unmodifiable(result);
  }

  /// The services that [registration] must wait for before it is created:
  /// its [DiRegistration.dependsOn] and the asynchronous services it reaches
  /// through its [FactoryRef.deps].
  ///
  /// Only a [DiLifetime.singleton] waits: it is created while it is
  /// registered, so a service it needs, or one that a lazy singleton or
  /// factory it needs takes, may not be ready yet. Lazy singletons and
  /// factories are created on first use, after `registerDependencies()`.
  Set<ServiceRef> dependsOnOf(DiRegistration registration) {
    if (registration.lifetime != DiLifetime.singleton) return const {};
    final key = registration.key;
    final known = _dependsOn[key];
    if (known != null) return known;
    if (!_resolving.add(key)) return const {};
    final result = {
      ...registration.dependsOn,
      ..._awaitableThrough(registration.create.deps, {key}),
    };
    _resolving.remove(key);
    return _dependsOn[key] = Set.unmodifiable(result);
  }

  /// Whether other services can wait for [registration]: a singleton that is
  /// created asynchronously or after other services.
  bool isAwaitable(DiRegistration registration) =>
      registration.lifetime == DiLifetime.singleton &&
      (registration.isAsync || dependsOnOf(registration).isNotEmpty);

  /// Whether `registerDependencies()` must wait for the container to be
  /// ready, because some service is awaitable.
  bool get needsAllReady =>
      registrations.any((data) => isAwaitable(data.value));

  /// The capabilities the container needs for [registration], including
  /// waiting for the services of [dependsOnOf].
  Set<DiCapability> capabilitiesOf(DiRegistration registration) => {
        if (registration.params.isNotEmpty) DiCapability.factoryWithParams,
        if (registration.isAsync) DiCapability.asyncInit,
        if (dependsOnOf(registration).isNotEmpty) DiCapability.dependsOn,
        if (registration.dispose != null) DiCapability.dispose,
        if (registration.instanceName != null ||
            [...registration.create.deps, ...registration.dependsOn]
                .any((service) => service.instanceName != null))
          DiCapability.instanceName,
      };

  Iterable<ServiceRef> _edges(DiRegistration registration) =>
      [...registration.create.deps, ...registration.dependsOn];

  /// The awaitable services among [services] and, through the lazy
  /// singletons and factories among them, among the services those take.
  Set<ServiceRef> _awaitableThrough(
    Iterable<ServiceRef> services,
    Set<ServiceRef> seen,
  ) {
    final result = <ServiceRef>{};
    for (final service in services) {
      if (!seen.add(service)) continue;
      final target = _byKey[service]?.value;
      if (target == null) continue;
      if (isAwaitable(target)) {
        result.add(service);
      } else if (target.lifetime != DiLifetime.singleton) {
        result.addAll(_awaitableThrough(target.create.deps, seen));
      }
    }
    return result;
  }

  /// The cycles of the graph, each as the services in it with the first one
  /// repeated at the end.
  List<List<ServiceRef>> _cycles() {
    final cycles = <List<ServiceRef>>[];
    final done = <ServiceRef>{};
    final path = <ServiceRef>[];

    void visit(ServiceRef key) {
      if (done.contains(key)) return;
      final at = path.indexOf(key);
      if (at != -1) {
        cycles.add([...path.sublist(at), key]);
        return;
      }
      final registration = _byKey[key]?.value;
      if (registration == null) return;
      path.add(key);
      _edges(registration).forEach(visit);
      path.removeLast();
      done.add(key);
    }

    _byKey.keys.forEach(visit);
    return cycles;
  }
}
