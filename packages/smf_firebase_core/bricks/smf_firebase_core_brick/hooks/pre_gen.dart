import 'package:mason/mason.dart';
import 'package:smf_firebase_core_brick_hooks/flutter_fire_installer.dart';

void run(HookContext context) async {
  final logger = Logger();
  final installer = FlutterFireInstaller(logger);

  // Ensure FlutterFire CLI is installed
  await installer.ensureInstalled();

  // Disable logging before last installation checking
  logger.level = Level.quiet;
  // Update context variables
  context.vars = {
    'flutterfire_installed': await installer.checkInstallation(),
  };
}
