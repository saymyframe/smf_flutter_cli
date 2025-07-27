import 'package:smf_contracts/src/routing/import/import.dart';

class RouteImport {
  const RouteImport.features(this.import) : anchor = RouteImportAnchor.features;

  const RouteImport.direct(this.import) : anchor = null;

  final RouteImportAnchor? anchor;
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
