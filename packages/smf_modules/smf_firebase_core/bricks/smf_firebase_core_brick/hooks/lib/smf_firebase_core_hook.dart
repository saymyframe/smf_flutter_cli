import 'package:mason/mason.dart';
import 'package:smf_firebase_core_brick_hooks/installers/firebase_cli_installer.dart';
import 'package:smf_firebase_core_brick_hooks/installers/flutter_fire_installer.dart';
import 'package:smf_firebase_core_brick_hooks/installers/i_installer.dart';

class SmfFirebaseCoreHook {
  const SmfFirebaseCoreHook(this._logger, {required this.workingDirectory});

  final Logger _logger;
  final String workingDirectory;

  Future<bool> run() async {
    // Firebase CLI
    var result = await _runInstallation(FirebaseCliInstaller(_logger));
    if (!result) throw Exception('Installation failed for firebase cli');

    // FlutterFire CLI
    result = await _runInstallation(FlutterFireInstaller(_logger));
    if (!result) throw Exception('Installation failed for flutterfire cli');

    return true;
  }

  Future<bool> _runInstallation(Installer installer) async {
    final isInstalled = await installer.ensureInstalled();

    if (!isInstalled) {
      _logger.err("${installer.name} wasn't installed");
      return false;
    }

    final isConfigured = await installer.configure(
      workingDirectory: workingDirectory,
    );
    if (!isConfigured) {
      _logger.err('Configuration failed for ${installer.name}');
      return false;
    }

    return true;
  }
}
