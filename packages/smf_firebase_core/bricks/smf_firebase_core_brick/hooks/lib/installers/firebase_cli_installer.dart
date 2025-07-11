import 'dart:io';

import 'package:mason/mason.dart';
import 'package:smf_firebase_core_brick_hooks/command_runner.dart';
import 'package:smf_firebase_core_brick_hooks/installers/i_installer.dart';
import 'package:smf_firebase_core_brick_hooks/prompts.dart';

class FirebaseCliInstaller implements Installer {
  const FirebaseCliInstaller(this._logger);

  final Logger _logger;

  @override
  String get name => 'Firebase CLI';

  @override
  Future<bool> checkInstallation() async {
    final progress = _logger.progress('🔄 Checking firebase cli installed');
    try {
      await CommandRunner.run('firebase', ['--help'], logger: _logger);
      progress.complete('✅ firebase cli installed');
      return true;
    } on Exception catch (_) {
      progress.fail("❌ firebase cli isn't installed");
      return false;
    }
  }

  @override
  Future<bool> install() async {
    final progress = _logger.progress('🔄 Installing firebase cli');
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        await CommandRunner.run(
          'bash',
          ['-c', 'curl -sL https://firebase.tools | bash'],
          logger: _logger,
        );
      } else if (Platform.isWindows) {
        await CommandRunner.run(
          'powershell',
          [
            '-Command',
            'Invoke-WebRequest -Uri https://firebase.tools -UseBasicParsing | Invoke-Expression'
          ],
          logger: _logger,
        );
      } else {
        throw Exception('❌ Unsupported platform: ${Platform.operatingSystem}');
      }

      progress.complete('✅ firebase cli installed');
      return true;
    } on Exception catch (_) {
      progress.fail('❌ something went wrong');
      return false;
    }
  }

  @override
  Future<bool> configure({required String workingDirectory}) async {
    try {
      await CommandRunner.start('firebase', ['login'], logger: _logger);
      return true;
    } on Exception catch (_) {
      return false;
    }
  }

  @override
  Future<bool> ensureInstalled() async {
    final isInstalled = await checkInstallation();

    if (!isInstalled) {
      final shouldInstall = await promptForInstallation(
        "Firebase CLI isn't installed on your system. "
        "Do you want to install it now?",
      );

      if (shouldInstall) {
        return await install();
      } else {
        final confirmed = await promptForConfirmation(
          'Are you sure? All modules related to Firebase will be disabled',
        );

        if (confirmed) {
          return await install();
        }
      }
    }

    return isInstalled;
  }
}
