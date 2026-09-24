import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mustachex/mustachex.dart';
import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// Fills DI template files with the imports and registrations of
/// [DiDependencyGroup]s.
///
/// A template is a file of the generated project with `imports` and `di`
/// Mustache sections, such as `lib/core/di/core_di.dart`.
abstract base class DiContributor {
  /// Creates a contributor for the project at [projectRoot] that writes
  /// registrations with [codeGenerator].
  const DiContributor({
    required this.projectRoot,
    required this.codeGenerator,
    this.logger,
  });

  /// The root directory of the generated project.
  final String projectRoot;

  /// Turns each [DiDependency] into a line of registration code.
  final DiCodeGenerator codeGenerator;

  /// Logs the generated imports and registrations, when given.
  final Logger? logger;

  /// Renders the DI files for [groups], with [mustacheVariables] for the
  /// placeholders in their imports, registrations and templates.
  ///
  /// The files are returned, not written.
  Future<List<GeneratedFile>> contribute(
    List<DiDependencyGroup> groups, {
    Map? mustacheVariables,
  });

  /// The path of the template that [scope] registrations go to, under
  /// [projectRoot]: `lib/core/di/core_di.dart` for [DiScope.core], and
  /// [pathToDiTemplate], which is required then, for [DiScope.module].
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

  /// The resolved imports of all [groups], one per line, in declaration
  /// order. An import that several groups declare is repeated.
  String combineImports(List<DiDependencyGroup> groups) {
    final imports = groups
        .map((d) => d.imports)
        .expand((e) => e)
        .map((i) => i.resolve())
        .join('\n');

    logger?.detail('Generated imports $imports');
    return imports;
  }

  /// The registrations of all dependencies in [groups], one per line, sorted
  /// by [DiDependency.order] with the dependencies that have none last.
  String combineRegistrations(List<DiDependencyGroup> groups) {
    final dependencies =
        groups.map((g) => g.diDependencies).expand((e) => e).toList()
          ..sort(
            (a, b) => (a.order ?? double.maxFinite).compareTo(
              b.order ?? double.maxFinite,
            ),
          );

    final buff = StringBuffer();
    for (final dependency in dependencies) {
      buff.writeln(codeGenerator.generate(dependency));
    }

    logger?.detail('Generated bindins $buff');
    return buff.toString();
  }

  /// Renders the template [file] with [imports] and [registrations] in its
  /// `imports` and `di` sections.
  ///
  /// [mustacheVariables] fill the placeholders in all three. Throws a
  /// [FileSystemException] when [file] doesn't exist.
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
