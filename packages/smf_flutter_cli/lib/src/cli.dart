import 'dart:io' as io;

import 'package:smf_contracts/lego_core.dart';
import 'package:smf_flutter_cli/src/banner.dart';
import 'package:smf_flutter_cli/src/io/host.dart';
import 'package:smf_flutter_cli/src/io/interruption.dart';
import 'package:smf_flutter_cli/src/io/terminal.dart';
import 'package:smf_flutter_cli/src/modules.dart';
import 'package:smf_flutter_cli/version.dart';
import 'package:smf_pipeline/smf_pipeline.dart';

/// Runs the `smf` command line with [arguments] on this machine and returns
/// its exit code; see [SmfExitCodes].
///
/// [modules] are those `smf create` offers, [smfModules] by default.
/// [onCreated] gets every app that `smf create` generated, after the
/// community banner.
Future<int> runCli(
  List<String> arguments, {
  List<SmfModule> modules = smfModules,
  void Function(GeneratedApp app)? onCreated,
}) async {
  final interruption = Interruption(beforeQuit: restoreTerminal)..listen();
  IoHost? machine;
  try {
    return await runSmf(
      arguments,
      modules: modules,
      hostFor: ({required verbose}) =>
          (machine = IoHost(verbose: verbose, interruption: interruption)).host,
      version: packageVersion,
      usageLineLength: io.stdout.hasTerminal ? io.stdout.terminalColumns : 80,
      onCreated: (app) {
        machine?.logger.info(communityBanner);
        onCreated?.call(app);
      },
    );
  } finally {
    await interruption.close();
  }
}
