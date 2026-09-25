/// The generation pipeline of the SMF CLI.
///
/// It depends only on the core of the lego model,
/// `package:smf_contracts/lego_core.dart`: the modules and roles come from a
/// `ModuleRegistry`, and the machine from an `SmfHost`.
library;

export 'src/choices.dart' show chooseRoles;
export 'src/collector.dart';
export 'src/environment.dart';
export 'src/errors.dart';
export 'src/explain.dart';
export 'src/host.dart';
export 'src/identity.dart';
export 'src/order.dart';
export 'src/pipeline.dart';
export 'src/preflight.dart';
export 'src/pubspec.dart';
export 'src/registry.dart';
export 'src/request.dart';
export 'src/resolver.dart';
export 'src/selection.dart';
export 'src/validation.dart';
