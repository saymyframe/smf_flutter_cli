import 'package:path/path.dart';
import 'package:smf_contracts/src/routing/import/import.dart';

class RouteImport {
  const RouteImport.features(this.anchor, this.import) : assert(anchor != null);

  const RouteImport.direct(this.import) : anchor = null;

  final RouteImportAnchor? anchor;
  final String import;

  String resolve() {
    if (anchor != null) {
      return join(
        anchor!.path.replaceFirst('lib', "import 'package:{{app_name_sc}}"),
        import,
      );
    }

    return import.replaceFirst('lib', "import 'package:{{app_name_sc}}");
  }
}
