import 'dart:io';

import 'package:path/path.dart';
import 'package:smf_contribution_engine/src/contribution.dart';

class PatchEngine {
  const PatchEngine(this.contributions, {required this.projectRoot});

  final List<Contribution> contributions;
  final String projectRoot;

  Future<void> applyAll() async {
    final byFile = <String, List<Contribution>>{};
    for (final c in contributions) {
      byFile.putIfAbsent(c.file, () => []).add(c);
    }

    for (final entry in byFile.entries) {
      final file = join(projectRoot, entry.key);
      final content = await File(file).readAsString();
      var result = content;
      for (final c in entry.value) {
        result = await c.apply(result);
      }

      await File(file).writeAsString(result);
    }
  }
}
