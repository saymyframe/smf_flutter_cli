/// The generation pipeline of the SMF CLI.
///
/// It depends only on the core of the lego model,
/// `package:smf_contracts/lego_core.dart`: the modules and roles come from a
/// [ModuleRegistry], and the machine from an [SmfHost]. [runSmf] runs the
/// command line, and [CreatePipeline] the `create` command itself; the
/// stages are internal.
library;

import 'package:smf_pipeline/src/cli.dart';
import 'package:smf_pipeline/src/host.dart';
import 'package:smf_pipeline/src/pipeline.dart';
import 'package:smf_pipeline/src/registry.dart';

export 'src/cli.dart' show SmfExitCodes, SmfHostFactory, runSmf;
export 'src/errors.dart' show GenerationFailedException, RegistryException;
export 'src/host.dart';
export 'src/pipeline.dart' show CreatePipeline, GeneratedApp, LeftOut;
export 'src/postgen.dart' show SkippedStep;
export 'src/registry.dart' show ModuleRegistry;
export 'src/request.dart' show CreateOptions, CreateRequest, OnConflict;
