/// The generation pipeline of the SMF CLI.
///
/// It depends only on the core of the lego model,
/// `package:smf_contracts/lego_core.dart`: the modules and roles come from a
/// [ModuleRegistry], and the machine from an [SmfHost]. The stages
/// themselves are internal; [CreatePipeline] runs them.
library;

import 'package:smf_pipeline/src/host.dart';
import 'package:smf_pipeline/src/pipeline.dart';
import 'package:smf_pipeline/src/registry.dart';

export 'src/environment.dart'
    show FlutterSdk, PipelineEnvironment, ResolvedTool;
export 'src/errors.dart' show GenerationFailedException, RegistryException;
export 'src/host.dart';
export 'src/pipeline.dart'
    show CreatePipeline, CreatePlanning, GeneratedApp, GenerationPlan, LeftOut;
export 'src/postgen.dart' show SkippedStep;
export 'src/registry.dart' show ModuleRegistry;
export 'src/request.dart' show CreateOptions, CreateRequest, OnConflict;
