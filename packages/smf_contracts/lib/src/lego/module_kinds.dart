import 'package:smf_contracts/lego.dart';

/// The kinds of the built-in modules.
///
/// Each kind states the rules its modules follow as data; see [ModuleKind].
abstract final class ModuleKinds {
  /// The module that creates the app itself: `main()`, start-up, native
  /// projects and `pubspec.yaml`. It provides the [AppEntryRole].
  static const scaffold = ModuleKind(
    id: 'scaffold',
    label: 'App scaffold',
    mustProvide: {appEntryRole},
  );
}
