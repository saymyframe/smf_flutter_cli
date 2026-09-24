import 'package:smf_contracts/smf_contracts.dart';

/// Directories of the generated app that an [Import] can be relative to.
enum ImportAnchor {
  /// `lib/core/services/`, for app-wide services and their interfaces.
  coreService._('lib/core/services/'),

  /// `lib/core/models/`, for shared models.
  coreModel._('lib/core/models/'),

  /// `lib/core/utils/`, for shared utilities.
  coreUtil._('lib/core/utils/'),

  /// `lib/core/repositories/`, for shared repositories.
  coreRepo._('lib/core/repositories/'),

  /// `lib/core/widgets/`, for shared widgets.
  coreWidgets._('lib/core/widgets/'),

  /// `lib/features/`, for feature code such as screens.
  features._('lib/features/');

  const ImportAnchor._(this.path);

  /// Path of the directory relative to the project root; it starts with
  /// `lib/` and ends with a slash.
  final String path;
}
