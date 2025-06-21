import 'package:mason/mason.dart' show MasonBundle;
import 'package:smf_flutter_core/src/file_merge_strategy.dart';

class BrickContribution {
  BrickContribution({
    required this.name,
    required this.bundle,
    required this.vars,
    this.mergeStrategy = FileMergeStrategy.overwrite,
  });

  final String name;
  final MasonBundle bundle;
  final Map<String, dynamic> vars;
  final FileMergeStrategy mergeStrategy;
}
