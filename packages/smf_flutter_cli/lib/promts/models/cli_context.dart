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

import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';

/// Strictness modes for module generation and validation.
enum StrictMode { 
  /// Fail fast when encountering an error.
  strict, 
  
  /// Continue generation, skipping unsupported modules with warnings.
  lenient 
}

/// Execution context passed across generators and hooks.
class CliContext {
  /// Creates a new [CliContext].
  const CliContext({
    required this.name,
    required this.selectedModules,
    required this.outputDirectory,
    required this.logger,
    required this.strictMode,
    required this.moduleResolver,
    this.packageName,
    this.initialRoute,
  });

  /// Human-readable project name.
  final String name;

  /// Modules selected by the user for inclusion.
  final List<IModuleCodeContributor> selectedModules;

  /// Absolute path where files will be generated.
  final String outputDirectory;

  /// Optional organization/package name used in identifiers.
  final String? packageName;

  /// Optional initial route for the application.
  final String? initialRoute;

  /// Logger for interactive feedback and diagnostics.
  final Logger logger;

  /// Strictness mode for generation behavior (errors vs warnings).
  final StrictMode strictMode;

  /// Resolver for handling module dependencies and ordering.
  final ModuleDependencyResolver moduleResolver;
}
