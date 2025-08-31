enum StateManager { bloc, riverpod }

class ModuleProfile {
  const ModuleProfile({required this.stateManager});

  final StateManager stateManager;
}
