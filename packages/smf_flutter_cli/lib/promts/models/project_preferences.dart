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

/// Snapshot of user choices collected during scaffolding.
class ProjectPreferences {
  /// Creates a new [ProjectPreferences].
  const ProjectPreferences({
    required this.name,
    required this.packageName,
    required this.initialRoute,
    required this.selectedModules,
  });

  /// Human-readable project name.
  final String name;

  /// Reverse-domain package/organization name.
  final String packageName;

  /// Initial route path to show after app launch.
  final String? initialRoute;

  /// Selected modules to be included in the generated project.
  final List<IModuleCodeContributor> selectedModules;
}
