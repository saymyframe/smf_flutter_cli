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

import 'package:mason/mason.dart' show MasonBundle;
import 'package:smf_contracts/src/file_merge_strategy.dart';

/// Represents a Mason brick template contribution from a module.
class BrickContribution {
  /// Creates a new [BrickContribution] with the specified properties.
  BrickContribution({
    required this.name,
    required this.bundle,
    this.vars,
    this.mergeStrategy = FileMergeStrategy.overwrite,
  });

  /// Human-readable name for this brick contribution.
  final String name;
  
  /// The Mason bundle containing the template files.
  final MasonBundle bundle;
  
  /// Optional variables to pass to the Mason template during generation.
  final Map<String, dynamic>? vars;
  
  /// Strategy for handling file conflicts during generation.
  final FileMergeStrategy mergeStrategy;
}
