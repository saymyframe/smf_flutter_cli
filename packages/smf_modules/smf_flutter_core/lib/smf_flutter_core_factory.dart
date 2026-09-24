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

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/src/module.dart';

/// Factory for creating Flutter core module instances based on state management choice.
class SmfFlutterCoreFactory implements IModuleContributorFactory {
  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    return switch (profile.stateManager) {
      StateManager.bloc => SmfCoreModule(),
      StateManager.riverpod => SmfCoreModuleRiverpod(),
    };
  }

  @override
  bool supports(ModuleProfile profile) {
    return switch (profile.stateManager) {
      StateManager.bloc => true,
      StateManager.riverpod => true,
    };
  }
}
