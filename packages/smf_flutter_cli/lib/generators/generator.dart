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

/// Base contract for all project generators within the CLI.
abstract class Generator {
  /// Const constructor for subclasses.
  const Generator();

  /// Generates files based on provided modules and context.
  Future<void> generate(
    List<IModuleCodeContributor> modules,
    Logger logger,
    Map<String, dynamic> coreVars,
    String generateTo,
  );

  /// Maps a high-level [FileMergeStrategy] to a mason [FileConflictResolution].
  FileConflictResolution mapMergeStrategy(FileMergeStrategy strategy) {
    switch (strategy) {
      case FileMergeStrategy.appendToFile:
        return FileConflictResolution.append;
      case FileMergeStrategy.injectByTag:
        return FileConflictResolution.prompt;
      case FileMergeStrategy.overwrite:
    }

    return FileConflictResolution.overwrite;
  }
}
