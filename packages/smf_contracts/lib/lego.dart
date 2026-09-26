/// The lego model of SMF: everything a module needs, including the
/// built-in roles and module kinds.
///
/// See `package:smf_contracts/lego_core.dart` for the core without concrete
/// roles.
library;

export 'lego_core.dart';
export 'src/lego/module_kinds.dart';
export 'src/lego/refs.dart';
export 'src/lego/roles/app_entry.dart';
export 'src/lego/roles/di.dart';
export 'src/lego/roles/layout.dart';
export 'src/lego/roles/router.dart';
export 'src/lego/roles/services.dart';
export 'src/lego/roles/state_management.dart';
