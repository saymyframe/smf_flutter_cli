/// The core of the lego model without any concrete role: modules, roles,
/// sockets, contributions and the seams of the pipeline.
///
/// The pipeline imports only this library, so it cannot depend on a
/// concrete role. Modules import `package:smf_contracts/lego.dart`, which
/// adds the built-in roles.
library;

export 'src/core/contributions.dart';
export 'src/core/environment.dart';
export 'src/core/file_index.dart';
export 'src/core/fragment.dart';
export 'src/core/issue.dart';
export 'src/core/merge.dart';
export 'src/core/module.dart';
export 'src/core/module_context.dart';
export 'src/core/module_id.dart';
export 'src/core/names.dart';
export 'src/core/origin.dart';
export 'src/core/preflight_check.dart';
export 'src/core/required_symbol.dart';
export 'src/core/role.dart';
export 'src/core/sockets.dart';
