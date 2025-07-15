import 'package:{{app_name.snakeCase()}}/core/services/system/i_system_service.dart';

class SystemService implements ISystemService {
  @override
  List<String> getConnectedModules() {
    return {{#modules}} {{{.}}} {{/modules}};
  }
}
