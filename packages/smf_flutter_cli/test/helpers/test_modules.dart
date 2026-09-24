import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';

/// Configurable [IModuleCodeContributor] for generator tests.
class TestModule implements IModuleCodeContributor {
  TestModule(
    String name, {
    Set<String> dependsOn = const {},
    Set<String> pubDependency = const {},
    Set<String> pubDevDependency = const {},
    this.brickContributions = const [],
    this.sharedFileContributions = const [],
    this.di = const [],
    RouteGroup? routes,
  })  : moduleDescriptor = ModuleDescriptor(
          name: name,
          description: name,
          dependsOn: dependsOn,
          pubDependency: pubDependency,
          pubDevDependency: pubDevDependency,
        ),
        routes = routes ?? RouteGroup.empty();

  @override
  final ModuleDescriptor moduleDescriptor;

  @override
  final List<BrickContribution> brickContributions;

  @override
  final List<Contribution> sharedFileContributions;

  @override
  final List<DiDependencyGroup> di;

  @override
  final RouteGroup routes;

  @override
  String toString() => 'TestModule(${moduleDescriptor.name})';
}

/// [TestModule] that also acts as a DSL-aware generator: it records every
/// [DslContext] it receives and returns the files built by `onGenerate`.
class DslTestModule extends TestModule implements DslAwareCodeGenerator {
  DslTestModule(
    super.name, {
    super.di,
    super.routes,
    List<GeneratedFile> Function(DslContext context)? onGenerate,
  }) : _onGenerate = onGenerate ?? ((_) => const []);

  final List<GeneratedFile> Function(DslContext context) _onGenerate;
  final List<DslContext> receivedContexts = [];

  @override
  Future<List<GeneratedFile>> generateFromDsl(DslContext context) async {
    receivedContexts.add(context);
    return _onGenerate(context);
  }
}

/// Factory that creates a [TestModule] and records the profiles it saw.
class ProbeFactory implements IModuleContributorFactory {
  ProbeFactory(this.name);

  final String name;
  final List<ModuleProfile> profiles = [];

  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    profiles.add(profile);
    return TestModule(name);
  }

  @override
  bool supports(ModuleProfile profile) => true;
}

/// Shared-file contribution that appends [line] (plus a newline) to [file].
class AppendLineContribution extends Contribution {
  const AppendLineContribution({required super.file, required this.line});

  final String line;

  @override
  Future<String> apply(String original) async => '$original$line\n';
}

/// In-memory mason brick made of text [files] (path -> mustache template).
MasonBundle textBundle(String name, Map<String, String> files) {
  return MasonBundle(
    name: name,
    description: 'Test brick $name',
    version: '0.1.0',
    files: [
      for (final MapEntry(key: path, value: content) in files.entries)
        MasonBundledFile(path, base64.encode(utf8.encode(content)), 'text'),
    ],
  );
}

/// [BrickContribution] backed by [textBundle].
BrickContribution textBrick(
  String name,
  Map<String, String> files, {
  Map<String, dynamic>? vars,
  FileMergeStrategy mergeStrategy = FileMergeStrategy.overwrite,
}) {
  return BrickContribution(
    name: name,
    bundle: textBundle(name, files),
    vars: vars,
    mergeStrategy: mergeStrategy,
  );
}
