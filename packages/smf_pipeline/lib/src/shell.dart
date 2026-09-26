import 'package:smf_contracts/lego_core.dart';

/// [argument] as the user types it in a shell of [operatingSystem]: as it
/// is when no shell treats its characters specially, else in double quotes
/// on Windows, which both PowerShell and `cmd` read, and in single quotes
/// elsewhere.
String shellQuoted(String argument, HostOperatingSystem operatingSystem) {
  if (operatingSystem == HostOperatingSystem.windows) {
    return RegExp(r'^[A-Za-z0-9_./:=+\\-]+$').hasMatch(argument)
        ? argument
        : '"${argument.replaceAll('"', r'\"')}"';
  }
  return RegExp(r'^[A-Za-z0-9_./:=,@%+-]+$').hasMatch(argument)
      ? argument
      : "'${argument.replaceAll("'", r"'\''")}'";
}
