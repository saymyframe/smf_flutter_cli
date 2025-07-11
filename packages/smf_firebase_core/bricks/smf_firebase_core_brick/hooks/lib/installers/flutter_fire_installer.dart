import 'package:mason/mason.dart';
import 'package:smf_firebase_core_brick_hooks/command_runner.dart';
import 'package:smf_firebase_core_brick_hooks/installers/i_installer.dart';
import 'package:smf_firebase_core_brick_hooks/prompts.dart';

class FlutterFireInstaller implements Installer {
  const FlutterFireInstaller(this._logger);

  final Logger _logger;

  @override
  String get name => 'FlutterFire CLI';

  @override
  Future<bool> checkInstallation() async {
    final progress = _logger.progress('🔄 Checking flutterfire_cli installed');
    try {
      await CommandRunner.run('flutterfire', ['--help'], logger: _logger);
      progress.complete('✅ flutterfire_cli installed');
      return true;
    } on Exception catch (_) {
      progress.fail('❌ flutterfire_cli isn\'t installed');
      return false;
    }
  }

  @override
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
      progress.fail('❌ something went wrong');
      return false;
    }
  }

  @override
  Future<bool> ensureInstalled() async {
    final isInstalled = await checkInstallation();

    if (!isInstalled) {
      final shouldInstall = await promptForInstallation(
        "FlutterFire CLI isn't installed on your system. "
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

  @override
  Future<bool> configure({
    required String workingDirectory,
  }) async {
    final process = await CommandRunner.start(
      'flutterfire',
      ['configure'],
      logger: _logger,
      workingDirectory: workingDirectory,
      runInShell: true,
    );

    return false;

    // final exitCode = await process.exitCode;
    // return exitCode == 0;
  }
}
