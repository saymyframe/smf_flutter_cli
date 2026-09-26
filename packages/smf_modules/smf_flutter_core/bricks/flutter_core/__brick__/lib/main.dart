import 'package:flutter/widgets.dart';

import 'app.dart';
import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  runApp(
    {{{smf_app_entry__root_wrappers_open}}}const App(){{{smf_app_entry__root_wrappers_close}}},
  );
}
