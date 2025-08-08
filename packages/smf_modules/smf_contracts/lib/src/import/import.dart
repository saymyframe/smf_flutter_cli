import 'package:smf_contracts/smf_contracts.dart';

class Import {
  const Import.core(this.anchor, this.import) : assert(anchor != null);

  const Import.direct(this.import) : anchor = null;

  const Import.features(this.import) : anchor = ImportAnchor.features;

  final ImportAnchor? anchor;
  final String import;

  String resolve() {
    String addSemicolonIfMissing(String import) {
      return import.endsWith(';') ? import : '$import;';
    }

    final cleanedImport = import.replaceFirst('lib/', '');
    const package = "import 'package:{{app_name_sc}}";
    if (anchor != null) {
      final cleanedAnchor = anchor!.path.replaceFirst('lib/', '');
      return addSemicolonIfMissing("$package/$cleanedAnchor$cleanedImport'");
    }

    return addSemicolonIfMissing(import.trim());
  }
}
