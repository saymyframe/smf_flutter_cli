import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_bloc/flutter_bloc.dart' show Cubit;

/// A cubit whose state is the value of a [ValueListenable], from its creation
/// until it is closed (fixture).
abstract base class FixtureListenableCubit<T> extends Cubit<T> {
  /// Creates the cubit of [listenable], with its value.
  FixtureListenableCubit(this._listenable) : super(_listenable.value) {
    _listenable.addListener(_follow);
  }

  final ValueListenable<T> _listenable;

  void _follow() => emit(_listenable.value);

  @override
  Future<void> close() {
    _listenable.removeListener(_follow);
    return super.close();
  }
}
