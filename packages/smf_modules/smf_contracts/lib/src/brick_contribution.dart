import 'package:mason/mason.dart' show MasonBundle;
import 'package:smf_contracts/src/file_merge_strategy.dart';

class BrickContribution {
  BrickContribution({
    required this.name,
    required this.bundle,
    this.vars,
    this.mergeStrategy = FileMergeStrategy.overwrite,
  });

  final String name;
  final MasonBundle bundle;
  final Map<String, dynamic>? vars;
  final FileMergeStrategy mergeStrategy;
}
