import 'package:smf_contribution_engine/src/contribution.dart';

class InsertImport extends Contribution {
  const InsertImport({required super.file, required this.import});

  final String import;

  @override
  Future<String> apply(String original) async {
    final importRegex = RegExp(r"^import .+?;", multiLine: true);
    final matches = importRegex.allMatches(original);
    if (matches.any(
      (m) => original.substring(m.start, m.end).contains(import),
    )) {
      return original;
    }

    final lastImport = matches.isNotEmpty ? matches.last.end : 0;
    return '${original.substring(0, lastImport)}\n'
        '$import${original.substring(lastImport)}';
  }
}
