import 'package:flutter/widgets.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/app/failed_start.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await bootstrap();
  } on Object catch (error, stackTrace) {
    // The app shows why it could not start, in place of a splash screen
    // that would stay.
    showFailedStart(error, stackTrace);
    return;
  }
  runApp(
    {{{smf_app_entry__root_wrappers_open}}}const App(){{{smf_app_entry__root_wrappers_close}}},
  );
}
