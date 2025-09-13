import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectedModulesProvider = FutureProvider<List<String>>((ref) async {
  return {{#modules}} {{{.}}} {{/modules}};
});


