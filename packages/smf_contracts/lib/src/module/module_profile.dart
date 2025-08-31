enum StateManager {
  bloc._('bloc'),
  riverpod._('riverpod');

  const StateManager._(this.stateManager);

  final String stateManager;
}

class ModuleProfile {
  const ModuleProfile({required this.stateManager});

  final StateManager stateManager;
}
