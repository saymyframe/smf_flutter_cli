import 'package:interact/interact.dart';

Future<bool> promptForInstallation(String prompt) async {
  return Confirm(
    prompt: prompt,
    defaultValue: true,
  ).interact();
}

Future<bool> promptForConfirmation(String prompt) async {
  return Confirm(
    prompt: prompt,
    defaultValue: false,
  ).interact();
}
