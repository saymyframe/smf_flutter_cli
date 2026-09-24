import 'package:smf_contracts/smf_contracts.dart';

/// How a DI registration provides its instance.
enum DiBindingType {
  /// One instance shared by all lookups.
  singleton,

  /// A new instance for every lookup.
  factory,
}

/// One registration in the DI DSL: which type is registered and how its
/// instance is created.
///
/// Modules list these in a [DiDependencyGroup]. The DSL does not depend on a
/// DI library, so types and expressions are Dart source strings; the DI
/// module of the project turns each registration into a statement with its
/// [DiCodeGenerator].
class DiDependency {
  /// Creates a registration of [implementation] under [abstractType].
  const DiDependency({
    required this.abstractType,
    required this.implementation,
    required this.bindingType,
    this.order,
  });

  /// Type the instance is registered and looked up under, for example
  /// `'IAnalyticsService'`.
  final String abstractType;

  /// Dart expression that creates the instance, for example
  /// `'FirebaseAnalyticsService(FirebaseAnalytics.instance)'`.
  ///
  /// Add the imports it needs to [DiDependencyGroup.imports].
  final String implementation;

  /// Whether one shared instance or a new instance per lookup is provided.
  final DiBindingType bindingType;

  /// Position of this registration in the generated DI file.
  ///
  /// Registrations written to the same file are sorted by ascending order;
  /// those without one come after all ordered registrations.
  final int? order;
}
