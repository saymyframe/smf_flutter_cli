// The versions of the app as the screen "Update required" compares them: the
// version of the app, such as 1.4.0 of `version: 1.4.0+12` in its pubspec,
// against the lowest version that may run. The file needs nothing but Dart.

/// A number of a version: digits alone.
final RegExp _number = RegExp(r'^[0-9]+$');

/// The numbers of [version], such as `[1, 4, 0]` for `1.4.0`, or `null` when
/// it is no version: one to four whole numbers between dots, such as `2`,
/// `1.4` or `1.4.0.2`. A build number after `+`, as in `1.4.0+12`, does not
/// count, nor do spaces around the version. A pre-release, such as
/// `2.0.0-beta`, is no version here.
List<int>? versionNumbers(String version) {
  final name = version.trim().split('+').first.trim();
  final parts = name.split('.');
  if (parts.length > 4) return null;
  final numbers = <int>[];
  for (final part in parts) {
    final number = _number.hasMatch(part) ? int.tryParse(part) : null;
    if (number == null) return null;
    numbers.add(number);
  }
  return numbers;
}

/// Whether [version], the version of the app, is below [minimum], the lowest
/// version that may run.
///
/// The two compare number by number, and a missing number is 0: `1.2` equals
/// `1.2.0`, and `1.10.0` is above `1.9.2`. An empty minimum, or one of
/// spaces, is none. A version or a minimum that is no version (see
/// [versionNumbers]) is below nothing, so the app runs.
bool versionBelow(String version, String minimum) {
  final numbers = versionNumbers(version);
  final lowest = versionNumbers(minimum);
  if (numbers == null || lowest == null) return false;
  for (var index = 0; index < 4; index++) {
    final number = index < numbers.length ? numbers[index] : 0;
    final least = index < lowest.length ? lowest[index] : 0;
    if (number != least) return number < least;
  }
  return false;
}
