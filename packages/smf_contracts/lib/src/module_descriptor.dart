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

/// Metadata and dependency information for a module.
class ModuleDescriptor {
  /// Creates a new [ModuleDescriptor] with the specified properties.
  const ModuleDescriptor({
    required this.name,
    required this.description,
    this.dependsOn = const {},
    this.pubDependency = const {},
    this.pubDevDependency = const {},
  });

  /// Unique identifier for this module.
  final String name;
  
  /// Human-readable description of this module's purpose.
  final String description;
  
  /// Set of module names that this module depends on.
  final Set<String> dependsOn;
  
  /// Set of pub.dev dependencies required by this module.
  final Set<String> pubDependency;
  
  /// Set of pub.dev dev dependencies required by this module.
  final Set<String> pubDevDependency;
}
