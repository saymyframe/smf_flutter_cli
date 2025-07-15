import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';

class DiImport {
  const DiImport.core(this.anchor, this.import) : assert(anchor != null);

  const DiImport.direct(this.import) : anchor = null;

  final DiImportAnchor? anchor;
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
