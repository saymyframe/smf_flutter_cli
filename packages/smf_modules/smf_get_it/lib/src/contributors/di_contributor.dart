import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mustachex/mustachex.dart';
import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';

abstract base class DiContributor {
  const DiContributor({
    required this.projectRoot,
    required this.codeGenerator,
    this.logger,
  });

  final String projectRoot;
  final DiCodeGenerator codeGenerator;
  final Logger? logger;

  Future<List<GeneratedFile>> contribute(
    List<DiDependencyGroup> groups, {
    Map? mustacheVariables,
  });

  String writeTo(DiScope scope, {String? pathToDiTemplate}) {
    assert(
      scope != DiScope.module || pathToDiTemplate?.isNotEmpty == true,
      'pathToDiTemplate must be provided when scope is DiScope.module',
    );

    switch (scope) {
      case DiScope.core:
        return join(projectRoot, 'lib', 'core', 'di', 'core_di.dart');
      case DiScope.module:
        return join(projectRoot, pathToDiTemplate);
    }
  }

  String combineImports(List<DiDependencyGroup> groups) {
    final imports = groups
        .map((d) => d.imports)
        .expand((e) => e)
        .map((i) => i.resolve())
        .join('\n');

    logger?.detail('Generated imports $imports');
    return imports;
  }

  String combineRegistrations(List<DiDependencyGroup> groups) {
    final dependencies =
        groups.map((g) => g.diDependencies).expand((e) => e).toList()..sort(
          (a, b) => (a.order ?? double.maxFinite).compareTo(
            b.order ?? double.maxFinite,
          ),
        );

    final buff = StringBuffer();
    for (final dependency in dependencies) {
      buff.writeln(codeGenerator.generate(dependency));
    }

    logger?.detail('Generated bindins ${buff.toString()}');
    return buff.toString();
  }

  Future<GeneratedFile> processFile({
    required String imports,
    required String registrations,
    required File file,
    Map? mustacheVariables,
  }) async {
    final innerProcessor = MustachexProcessor(
      initialVariables: mustacheVariables,
    );

    final processedImports = await innerProcessor.process(imports);
    final processedDi = await innerProcessor.process(registrations);

    final processor = MustachexProcessor(
      initialVariables: {
        ...mustacheVariables ?? {},
        MustacheSlots.imports.slot: processedImports,
        MustacheSlots.di.slot: processedDi,
      },
    );

    final processed = await processor.process(await file.readAsString());
    return GeneratedFile(file.path, processed);
  }
}
