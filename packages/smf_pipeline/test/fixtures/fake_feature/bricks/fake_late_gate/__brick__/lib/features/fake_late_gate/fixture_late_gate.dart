import 'package:flutter/foundation.dart';

/// The late gate of the fixture: whether it is open, which a test sets. It
/// is open unless a test closes it, and the guard of the fixture allows
/// while it is open.
final ValueNotifier<bool> fixtureLateGate = ValueNotifier(true);

/// Whether the guard of the fixture allows: while its gate is open.
ValueListenable<bool> fixtureLateGateOpen() => fixtureLateGate;
