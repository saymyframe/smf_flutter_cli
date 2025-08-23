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
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_flutter_cli/generators/generator.dart';

/// Applies cross-cutting contributions to existing project files.
class SharableGenerator extends Generator {
  /// Creates a [SharableGenerator].
  const SharableGenerator();

  @override
  Future<void> generate(
    List<IModuleCodeContributor> modules,
    Logger logger,
    Map<String, dynamic> coreVars,
    String generateTo,
  ) async {
    final contributions =
        modules.map((m) => m.sharedFileContributions).expand((e) => e).toList();

    return PatchEngine(
      contributions,
      projectRoot: generateTo,
      mustacheVariables: coreVars,
      logger: logger,
    ).applyAll();
  }
}
