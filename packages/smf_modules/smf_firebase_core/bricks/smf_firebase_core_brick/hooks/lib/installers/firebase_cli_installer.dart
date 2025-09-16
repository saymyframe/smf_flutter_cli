import 'dart:convert';
import 'dart:io';

import 'package:mason/mason.dart';
import 'package:smf_firebase_core_brick_hooks/command_runner.dart';
import 'package:smf_firebase_core_brick_hooks/generated/hook_assets.dart'
    as assets;
import 'package:smf_firebase_core_brick_hooks/installers/i_installer.dart';
import 'package:smf_firebase_core_brick_hooks/prompts.dart';

class FirebaseCliInstaller implements Installer {
  const FirebaseCliInstaller(this._logger);

  final Logger _logger;

  @override
  String get name => 'Firebase CLI';

  @override
  Future<bool> checkInstallation([Progress? p]) async {
    final progress = p ?? _logger.progress('Checking firebase cli installed');
    try {
      await CommandRunner.run('firebase', ['--help'], logger: _logger);
      progress.complete('firebase cli installed');
      return true;
    } on Exception catch (e, s) {
      progress.fail("firebase cli isn't installed");

      _logger
        ..delayed(e.toString())
        ..delayed('\n')
        ..delayed(s.toString());
      return false;
    }
  }

  @override
  Future<bool> install() async {
    final progress = _logger.progress('🔄 Installing firebase cli');

    try {
      // Primary install via embedded scripts with realtime output
      if (Platform.isMacOS) {
        final file = await _writeTempAsset('install_firebase_macos.sh');
        await CommandRunner.run('bash', [file.path], logger: _logger);
      } else if (Platform.isLinux) {
        final file = await _writeTempAsset('install_firebase_linux.sh');
        await CommandRunner.run('bash', [file.path], logger: _logger);
      } else if (Platform.isWindows) {
        final file = await _writeTempAsset('install_firebase_windows.ps1');
        await CommandRunner.run(
          'powershell',
          [
            '-ExecutionPolicy',
            'Bypass',
            '-NoLogo',
            '-NonInteractive',
            '-File',
            file.path,
          ],
          logger: _logger,
        );
      } else {
        throw Exception('❌ Unsupported platform: ${Platform.operatingSystem}');
      }

      // Verify installation
      return checkInstallation(progress);
    } catch (e, s) {
      // Fallback only for macOS/Linux
      if (!(Platform.isMacOS || Platform.isLinux)) {
        progress.fail('installation failed');
        _logger.delayed(e.toString());
        _logger.delayed('\n');
        _logger.delayed(s.toString());

        return false;
      }

      return _fallBackInstall(progress);
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

  Future<File> _writeTempAsset(String key) async {
    final b64 = assets.hookAssetsB64[key];
    if (b64 == null) {
      throw StateError('Hook asset not found: $key');
    }
    final bytes = base64.decode(b64);
    final tmp = File('${Directory.systemTemp.path}/$key')
      ..createSync(recursive: true);
    await tmp.writeAsBytes(bytes, flush: true);
    return tmp;
  }

  Future<bool> _fallBackInstall(Progress progress) async {
    final ok = await promptForConfirmation(
      'Primary install failed. Try fallback (curl -sL https://firebase.tools | bash)?',
    );

    if (!ok) {
      progress.fail('installation cancelled');
      return false;
    }

    try {
      await CommandRunner.start(
        'bash',
        ['-lc', 'curl -sL https://firebase.tools | bash'],
        logger: _logger,
      );

      return checkInstallation(progress);
    } catch (e, s) {
      progress.fail('fallback installation failed');

      _logger.delayed(e.toString());
      _logger.delayed('\n');
      _logger.delayed(s.toString());
      return false;
    }
  }
}
