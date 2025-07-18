import 'dart:io';

import 'package:mustachex/mustachex.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/contributors/contributors.dart';

class CoreDiContributor extends DiContributor {
  const CoreDiContributor({
    required super.projectRoot,
    required this.coreGenerator,
    super.logger,
  });

  final DiCodeGenerator coreGenerator;

  @override
  Future<List<File?>> contribute(
    List<DiDependencyGroup> groups, {
    Map? mustacheVariables,
  }) async {
    if (groups.isEmpty) {
      logger?.info('Core di dependencies is empty.');
      return [];
    }

    final innerProcessor = MustachexProcessor(
      initialVariables: mustacheVariables,
    );

    final processedImports = await innerProcessor.process(_imports(groups));
    final processedDi = await innerProcessor.process(_registrations(groups));

    final processor = MustachexProcessor(
      initialVariables: {
        ...mustacheVariables ?? {},
        MustacheSlots.imports.slot: processedImports,
        MustacheSlots.di.slot: processedDi,
      },
    );

    final file = File(writeTo(groups.first));
    final processed = await processor.process(await file.readAsString());
    return [await file.writeAsString(processed)];
  }

  String _imports(List<DiDependencyGroup> groups) {
    return groups
        .map((d) => d.imports)
        .expand((e) => e)
        .map((i) => i.resolve())
        .join('\n');
  }

  String _registrations(List<DiDependencyGroup> groups) {
    final dependencies =
        groups.map((g) => g.diDependencies).expand((e) => e).toList()..sort(
          (a, b) => (a.order ?? double.maxFinite).compareTo(
            b.order ?? double.maxFinite,
          ),
        );

    final buff = StringBuffer();
    for (final dependency in dependencies) {
      buff.writeln(coreGenerator.generate(dependency));
    }

    logger?.detail('Generated bindins ${buff.toString()}');
    return buff.toString();
  }
}
