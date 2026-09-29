import 'badge.dart';

/// Creates the badge of the app.
Badge createBadge() => const _FixedBadge();

final class _FixedBadge implements Badge {
  const _FixedBadge();

  @override
  List<String> get labels => badgeLabels;
}
