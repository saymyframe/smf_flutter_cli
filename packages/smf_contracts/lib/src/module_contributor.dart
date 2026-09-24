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
import 'package:smf_contribution_engine/smf_contribution_engine.dart';

/// Interface for modules that contribute code to the generated project.
abstract interface class IModuleCodeContributor {
  /// List of Mason brick contributions provided by this module.
  List<BrickContribution> get brickContributions;

  /// List of shared file contributions that patch existing files.
  List<Contribution> get sharedFileContributions;

  /// Metadata describing this module's identity and dependencies.
  ModuleDescriptor get moduleDescriptor;

  /// Dependency injection configuration groups provided by this module.
  List<DiDependencyGroup> get di;

  /// Route definitions and navigation structure provided by this module.
  RouteGroup get routes;
}

/// Mixin providing empty implementations for all [IModuleCodeContributor] methods.
mixin EmptyModuleCodeContributor implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => const [];

  @override
  List<Contribution> get sharedFileContributions => const [];

  @override
  List<DiDependencyGroup> get di => const [];

  @override
  RouteGroup get routes => RouteGroup.empty();
}
