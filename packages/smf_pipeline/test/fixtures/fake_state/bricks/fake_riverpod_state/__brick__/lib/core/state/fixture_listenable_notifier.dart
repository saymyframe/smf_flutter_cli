import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Notifier;

/// A notifier whose state is the value of a [ValueListenable], from the first
/// read of its provider until the `ProviderScope` disposes of it (fixture).
final class FixtureListenableNotifier<T> extends Notifier<T> {
  /// Creates the notifier of the listenable that [listenable] returns.
  FixtureListenableNotifier(this._listenable);

  final ValueListenable<T> Function() _listenable;

  @override
  T build() {
    final listenable = _listenable();
    void follow() => state = listenable.value;
    listenable.addListener(follow);
    ref.onDispose(() => listenable.removeListener(follow));
    return listenable.value;
  }
}
