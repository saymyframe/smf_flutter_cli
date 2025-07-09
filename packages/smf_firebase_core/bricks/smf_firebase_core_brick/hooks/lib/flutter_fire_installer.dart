import 'package:interact/interact.dart';
import 'package:mason/mason.dart';
import 'package:smf_firebase_core_brick_hooks/command_runner.dart';

class FlutterFireInstaller {
  FlutterFireInstaller(this._logger);

  final Logger _logger;

  Future<bool> checkInstallation() async {
    final progress = _logger.progress('🔄 Checking flutterfire_cli installed');
    try {
      await CommandRunner.run('flutterfire', ['--help'], logger: _logger);
      progress.complete('✅ flutterfire_cli installed');
      return true;
    } on Exception catch (_) {
      progress.complete('❌ flutterfire_cli isn\'t installed');
      return false;
    }
  }

  Future<bool> install() async {
    final progress = _logger.progress('🔄 Installing flutterfire_cli');
    try {
      await CommandRunner.run(
        'dart',
        ['pub', 'global', 'activate', 'flutterfire_cli'],
        logger: _logger,
      );
      progress.complete('✅ flutterfire_cli installed');
      return true;
    } on Exception catch (_) {
      progress.complete('❌ something went wrong');
      return false;
    }
  }

  Future<bool> promptForInstallation() async {
    return Confirm(
      prompt: "FlutterFire CLI isn't installed on your system. "
          "Do you want to install it now?",
      defaultValue: true,
    ).interact();
  }

  Future<bool> promptForConfirmation() async {
    return Confirm(
      prompt: 'Are you sure? All modules related to Firebase will be disabled',
      defaultValue: false,
    ).interact();
  }

  Future<bool> ensureInstalled() async {
    final isInstalled = await checkInstallation();

    if (!isInstalled) {
      final shouldInstall = await promptForInstallation();

      if (shouldInstall) {
        return await install();
      } else {
        final confirmed = await promptForConfirmation();
        if (confirmed) {
          return await install();
        }
      }
    }

    return isInstalled;
  }
}
