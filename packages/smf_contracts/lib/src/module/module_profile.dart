// Copyright 2025 SayMyFrame. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// Available state management solutions for Flutter applications.
enum StateManager {
  /// BLoC (Business Logic Component) state management.
  bloc._('bloc'),
  
  /// Riverpod state management solution.
  riverpod._('riverpod');

  /// Creates a new [StateManager] with the given identifier.
  const StateManager._(this.stateManager);

  /// The string identifier for this state manager.
  final String stateManager;
}

/// Profile configuration defining the target platform and state management.
class ModuleProfile {
  /// Creates a new [ModuleProfile] with the specified [stateManager].
  const ModuleProfile({required this.stateManager});

  /// The state management solution to use for this profile.
  final StateManager stateManager;
}
