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

  /// A module that sets up a service or a library without screens of its
  /// own, such as a router, a DI container or Firebase.
  ///
  /// It declares no routes, generates nothing in `lib/features/`, has no
  /// variants, and never resolves services itself: it receives them through
  /// the factories of its DI registrations.
  static const infrastructure = ModuleKind(
    id: 'infrastructure',
    label: 'Infrastructure',
    forbiddenData: {routerRole},
    forbiddenFileRoots: ['lib/features/'],
    allowsVariants: false,
  );

  /// A module with screens, such as the start screen: it requires a router,
  /// declares at least one route, and keeps its files in
  /// `lib/features/<id>/`.
  ///
  /// It may resolve services in its optional composition file,
  /// `lib/features/<id>/<id>_composition.dart`, which creates what its
  /// screens need, such as a Cubit; a feature that does requires the
  /// [DiRole].
  static const feature = ModuleKind(
    id: 'feature',
    label: 'Features',
    impliedRequires: {routerRole},
    fileRoots: ['lib/features/<id>/'],
    requiredData: {routerRole},
    compositionFile: 'lib/features/<id>/<id>_composition.dart',
  );

  /// A module that provides the main navigation of the app, such as bottom
  /// tabs. It provides the [LayoutRole], keeps its files in
  /// `lib/core/layout/` and declares no routes.
  static const layout = ModuleKind(
    id: 'layout',
    label: 'Layouts',
    mustProvide: {layoutRole},
    fileRoots: ['lib/core/layout/'],
    forbiddenData: {routerRole},
  );
}
