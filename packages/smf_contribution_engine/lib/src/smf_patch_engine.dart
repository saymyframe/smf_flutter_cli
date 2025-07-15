import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mustachex/mustachex.dart';
import 'package:path/path.dart';
import 'package:smf_contribution_engine/src/contribution.dart';

class PatchEngine {
  const PatchEngine(
    this.contributions, {
    required this.projectRoot,
    this.mustacheVariables,
    this.logger,
  });

  final List<Contribution> contributions;
  final String projectRoot;
  final Map? mustacheVariables;
  final Logger? logger;

  Future<void> applyAll() async {
    final byFile = <String, List<Contribution>>{};
    for (final c in contributions) {
      byFile.putIfAbsent(c.file, () => []).add(c);
    }

    final mustacheProcessor = MustachexProcessor(
      initialVariables: mustacheVariables,
    );

    for (final entry in byFile.entries) {
      final file = join(projectRoot, entry.key);

      final generateProgress = logger?.progress(
        '🔄 Generating shared content for ${entry.key}',
      );

      final content = await File(file).readAsString();
      var result = content;
      for (final c in entry.value) {
        result = await mustacheProcessor.process(await c.apply(result));
      }

      await File(file).writeAsString(result);

      generateProgress?.complete('✅ Generated shared content for ${entry.key}');
    }
  }
}
