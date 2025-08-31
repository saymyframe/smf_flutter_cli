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

import 'package:mason/mason.dart' show Logger;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/file_writers/file_writer.dart';

/// Logs intended writes without touching the file system.
class DryRunWriteStrategy implements FileWriteStrategy {
  /// Creates a strategy that logs to the provided [logger].
  const DryRunWriteStrategy(this.logger);

  /// Logger used to print file paths and contents.
  final Logger logger;

  @override
  /// Prints the target path and file contents instead of writing to disk.
  Future<void> write(GeneratedFile file) async {
    logger
      ..write('Would write: ${file.path}\n')
      ..write(file.content);
  }
}
