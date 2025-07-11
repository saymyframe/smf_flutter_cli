abstract interface class Installer {
  Future<bool> checkInstallation();

  Future<bool> install();

  Future<bool> ensureInstalled();

  Future<bool> configure({required String workingDirectory});

  String get name;
}
