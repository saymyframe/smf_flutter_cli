import 'package:smf_contracts/lego_core.dart';

/// How a [KeyedSocket] or [ValueSocket] merges two values contributed for
/// the same key.
///
/// The set of policies is open: the owner of a socket can define its own,
/// such as the Info.plist policy that unites string arrays but keeps scalars
/// unique.
abstract base class MergePolicy<V extends Object> {
  /// Allows subclasses to have constant constructors.
  const MergePolicy();

  /// A short name of the policy for diagnostics, such as `max`.
  String get name;

  /// Merges [incoming] into [existing], the value merged from the earlier
  /// contributions for [key], and returns the result.
  ///
  /// Throws a [MergeConflict] if the two values cannot be merged.
  V merge(String key, V existing, V incoming);
}

/// Thrown by a [MergePolicy] when two values for a key cannot be merged.
final class MergeConflict implements Exception {
  /// Creates a conflict between [existing] and [incoming] for [key].
  const MergeConflict(this.key, this.existing, this.incoming, this.reason);

  /// The key both values were contributed for.
  final String key;

  /// The value merged from the earlier contributions.
  final Object existing;

  /// The value that could not be merged into [existing].
  final Object incoming;

  /// Why the values cannot be merged.
  final String reason;

  @override
  String toString() =>
      'MergeConflict: "$key" has conflicting values "$existing" and '
      '"$incoming": $reason';
}

/// Allows one value per key: equal values merge, different ones conflict.
final class ConflictPolicy<V extends Object> extends MergePolicy<V> {
  /// Creates the policy.
  const ConflictPolicy();

  @override
  String get name => 'conflict';

  @override
  V merge(String key, V existing, V incoming) {
    if (existing == incoming) return existing;
    throw MergeConflict(key, existing, incoming, 'only one value is allowed');
  }
}

/// Keeps the greater of two values, such as the higher of two minimum
/// versions.
///
/// Values that [compare] cannot order conflict. Equal values keep the earlier
/// one.
final class MaxPolicy extends MergePolicy<String> {
  /// Creates the policy; [compare] defaults to [compareLooseVersions].
  const MaxPolicy([this.compare = compareLooseVersions]);

  /// Orders two values; it throws a [FormatException] for values it cannot
  /// order.
  final Comparator<String> compare;

  @override
  String get name => 'max';

  @override
  String merge(String key, String existing, String incoming) {
    try {
      return compare(existing, incoming) >= 0 ? existing : incoming;
    } on FormatException catch (error) {
      throw MergeConflict(key, existing, incoming, error.message);
    }
  }
}

/// Unites lists of values, keeping the order of first appearance and
/// dropping duplicates.
final class UnionPolicy<E extends Object> extends MergePolicy<List<E>> {
  /// Creates the policy.
  const UnionPolicy();

  @override
  String get name => 'union';

  @override
  List<E> merge(String key, List<E> existing, List<E> incoming) {
    return [
      ...existing,
      for (final value in incoming)
        if (!existing.contains(value)) value,
    ];
  }
}

final RegExp _looseVersion = RegExp(r'^(\d+(?:\.\d+)*)(.*)$');

/// Compares versions such as `13.0`, `15`, `8.7.3` or `33.3.1-jre`, which
/// minimum platform versions and Gradle artifacts use.
///
/// Unlike semantic versioning it accepts any number of numeric components and
/// treats missing ones as zero, so `15` equals `15.0` and `15.0.0`. Text after
/// the numbers, such as `-jre`, must match: versions that differ only there
/// cannot be ordered.
///
/// Throws a [FormatException] if a version does not start with a number or
/// the two versions cannot be ordered.
int compareLooseVersions(String a, String b) {
  final (numbersA, suffixA) = _parseLooseVersion(a);
  final (numbersB, suffixB) = _parseLooseVersion(b);

  final length =
      numbersA.length > numbersB.length ? numbersA.length : numbersB.length;
  for (var i = 0; i < length; i++) {
    final componentA = i < numbersA.length ? numbersA[i] : 0;
    final componentB = i < numbersB.length ? numbersB[i] : 0;
    if (componentA != componentB) return componentA.compareTo(componentB);
  }

  if (suffixA == suffixB) return 0;
  throw FormatException(
    'The versions "$a" and "$b" differ only after their numbers and cannot '
    'be ordered.',
  );
}

(List<int>, String) _parseLooseVersion(String version) {
  final match = _looseVersion.firstMatch(version.trim());
  if (match == null) {
    throw FormatException('"$version" does not start with a version number.');
  }
  return (match.group(1)!.split('.').map(int.parse).toList(), match.group(2)!);
}
