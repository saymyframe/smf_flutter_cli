/// The core of the lego model without any concrete role: modules, roles,
/// sockets, contributions and the seams of the pipeline.
///
/// The pipeline imports only this library, so it cannot depend on a
/// concrete role. Modules import `package:smf_contracts/lego.dart`, which
/// adds the built-in roles.
///
/// While the model is being introduced, it lives next to the older API of
/// `package:smf_contracts/smf_contracts.dart`, which declares some of the
/// same names. A file imports one of the two, never both.
library;

export 'src/lego/core/contributions.dart';
export 'src/lego/core/environment.dart';
export 'src/lego/core/file_index.dart';
export 'src/lego/core/fragment.dart';
export 'src/lego/core/issue.dart';
export 'src/lego/core/merge.dart';
export 'src/lego/core/module.dart';
export 'src/lego/core/module_context.dart';
export 'src/lego/core/module_id.dart';
export 'src/lego/core/names.dart';
export 'src/lego/core/origin.dart';
export 'src/lego/core/preflight_check.dart';
export 'src/lego/core/required_symbol.dart';
export 'src/lego/core/role.dart';
export 'src/lego/core/sockets.dart';
